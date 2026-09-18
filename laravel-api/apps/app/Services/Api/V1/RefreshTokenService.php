<?php

namespace App\Services\Api\V1;

use App\Exceptions\ApiException;
use App\Models\AuthSession;
use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Owns the long-lived refresh-token lifecycle: issuance, rotation, reuse
 * detection and revocation. Refresh secrets are only ever returned to the
 * client once; the database stores a SHA-256 hash.
 */
class RefreshTokenService
{
    /**
     * Issue a brand new refresh token (start of a token family or a rotation).
     *
     * @return array{token: RefreshToken, plain: string}
     */
    public function issue(
        User $user,
        AuthSession $session,
        ?string $familyId = null,
        ?string $ipAddress = null,
        ?string $userAgent = null,
    ): array {
        $plain = Str::random(80);

        $token = RefreshToken::create([
            'user_id' => $user->id,
            'auth_session_id' => $session->id,
            'hash' => hash('sha256', $plain),
            'family_id' => $familyId ?? (string) Str::ulid(),
            'expires_at' => now()->addMinutes((int) config('api.tokens.refresh_token_ttl')),
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
        ]);

        return ['token' => $token, 'plain' => $plain];
    }

    /**
     * Rotate a refresh token. Detects reuse and revokes the whole token family
     * when a token that has already been exchanged is presented again.
     *
     * Side effects that must survive the failure (family revocation) are
     * committed inside the transaction and the matching exception is thrown
     * afterwards, so the rollback cannot undo the security response.
     *
     * @return array{user: User, session: AuthSession, token: RefreshToken, plain: string}
     */
    public function rotate(string $plain, ?string $ipAddress = null, ?string $userAgent = null): array
    {
        $outcome = DB::transaction(function () use ($plain, $ipAddress, $userAgent): array {
            $token = RefreshToken::query()
                ->where('hash', hash('sha256', $plain))
                ->lockForUpdate()
                ->first();

            if (! $token) {
                Log::channel('stack')->warning('api.security.refresh_invalid', [
                    'ip' => $ipAddress,
                ]);

                throw ApiException::invalidToken('The refresh token is invalid.');
            }

            $token->loadMissing(['user', 'authSession']);

            if ($token->isRevoked() || ! $token->authSession?->isActive()) {
                throw ApiException::invalidToken('The refresh token has been revoked.');
            }

            if ($token->replaced_by_id !== null) {
                $this->handleReuse($token);

                return ['status' => 'reused'];
            }

            if ($token->isExpired()) {
                $this->revokeToken($token);

                return ['status' => 'expired'];
            }

            $issued = $this->issue(
                $token->user,
                $token->authSession,
                $token->family_id,
                $ipAddress,
                $userAgent,
            );

            $token->forceFill([
                'replaced_by_id' => $issued['token']->id,
                'last_used_at' => now(),
            ])->save();

            $token->authSession->touchLastUsed();

            return [
                'status' => 'rotated',
                'user' => $token->user,
                'session' => $token->authSession,
                'token' => $issued['token'],
                'plain' => $issued['plain'],
            ];
        });

        if ($outcome['status'] === 'reused') {
            throw ApiException::tokenReused();
        }

        if ($outcome['status'] === 'expired') {
            throw ApiException::tokenExpired('The refresh token has expired.');
        }

        unset($outcome['status']);

        return $outcome;
    }

    /**
     * Revoke a single refresh token.
     */
    public function revokeToken(RefreshToken $token): void
    {
        if (! $token->isRevoked()) {
            $token->revoke();
        }
    }

    /**
     * Revoke every refresh token belonging to a session and delete the
     * session's access tokens so nothing survives the revocation.
     */
    public function revokeSession(AuthSession $session): void
    {
        DB::transaction(function () use ($session): void {
            RefreshToken::query()
                ->where('auth_session_id', $session->id)
                ->whereNull('revoked_at')
                ->update(['revoked_at' => now()]);

            $session->accessTokens()->delete();

            if ($session->isActive()) {
                $session->revoke();
            }
        });
    }

    /**
     * Revoke all sessions for a user, optionally keeping the current one.
     */
    public function revokeAllForUser(User $user, ?string $exceptSessionId = null): void
    {
        $sessions = AuthSession::query()
            ->where('user_id', $user->id)
            ->when($exceptSessionId, fn ($query) => $query->whereKeyNot($exceptSessionId))
            ->get();

        foreach ($sessions as $session) {
            $this->revokeSession($session);
        }
    }

    /**
     * A used refresh token was presented again: assume theft and burn the
     * entire family down, including the session that owned it.
     */
    private function handleReuse(RefreshToken $token): void
    {
        Log::channel('stack')->critical('api.security.refresh_reuse_detected', [
            'user_id' => $token->user_id,
            'session_id' => $token->auth_session_id,
            'family_id' => $token->family_id,
            'token_id' => $token->id,
            'ip' => $token->ip_address,
        ]);

        if (config('api.tokens.refresh_token_reuse_policy') === 'revoke_family') {
            RefreshToken::query()
                ->where('family_id', $token->family_id)
                ->whereNull('revoked_at')
                ->update(['revoked_at' => now()]);

            if ($token->authSession) {
                $this->revokeSession($token->authSession);
            }
        }
    }
}
