<?php

namespace App\Services\Api\V1;

use App\Exceptions\ApiException;
use App\Models\AuthSession;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Orchestrates authentication: registration, credential login, the
 * access/refresh token pair, rotation and session revocation. Access tokens
 * are short lived Sanctum tokens; refresh tokens are rotated by
 * RefreshTokenService.
 */
class AuthService
{
    public function __construct(private readonly RefreshTokenService $refreshTokens) {}

    /**
     * @param  array{name: string, email: string, password: string}  $data
     */
    public function register(array $data): User
    {
        $user = DB::transaction(fn (): User => User::create([
            'name' => $data['name'],
            'email' => Str::lower($data['email']),
            'password' => $data['password'],
        ]));

        if (config('api.email_verification.enabled')) {
            $user->sendEmailVerificationNotification();
        }

        return $user;
    }

    public function validateCredentials(string $email, string $password, ?string $ip = null): ?User
    {
        $user = User::query()->where('email', Str::lower($email))->first();

        if (! $user || ! Hash::check($password, $user->password)) {
            Log::channel('stack')->warning('api.security.login_failed', [
                'email' => Str::lower($email),
                'ip' => $ip,
            ]);

            return null;
        }

        return $user;
    }

    public function requiresTwoFactor(User $user): bool
    {
        return (bool) ($user->two_factor_secret && $user->two_factor_confirmed_at);
    }

    /**
     * @return array{two_factor_required: bool, user: User, two_factor_token?: string}
     */
    public function login(string $email, string $password, string $deviceName, Request $request): array
    {
        $user = $this->validateCredentials($email, $password, $request->ip());

        if (! $user) {
            throw ApiException::invalidCredentials();
        }

        if ($this->requiresTwoFactor($user)) {
            return [
                'two_factor_required' => true,
                'two_factor_token' => $this->createTwoFactorChallenge($user),
                'user' => $user,
            ];
        }

        return ['two_factor_required' => false] + $this->authenticate($user, $deviceName, $request);
    }

    /**
     * Establish a session and issue a fresh token pair.
     *
     * @return array{user: User, session: AuthSession, access_token: string, token_type: string, access_expires_at: string, refresh_token: string, refresh_expires_at: string}
     */
    public function authenticate(User $user, string $deviceName, Request $request): array
    {
        $session = $this->createSession($user, $deviceName, $request);

        return ['user' => $user] + $this->issueTokenPair($user, $session, $request);
    }

    public function createTwoFactorChallenge(User $user): string
    {
        return $user->createToken(
            (string) config('api.tokens.two_factor_challenge_name'),
            [(string) config('api.tokens.two_factor_challenge_ability')],
            now()->addMinutes((int) config('api.tokens.two_factor_challenge_ttl')),
        )->plainTextToken;
    }

    public function createSession(User $user, string $deviceName, Request $request): AuthSession
    {
        return AuthSession::create([
            'user_id' => $user->id,
            'name' => $deviceName !== '' ? $deviceName : 'Unknown device',
            'ip_address' => $request->ip(),
            'user_agent' => Str::limit((string) $request->userAgent(), 1000, ''),
            'last_used_at' => now(),
        ]);
    }

    /**
     * @return array{access_token: string, token_type: string, access_expires_at: string, refresh_token: string, refresh_expires_at: string, session: AuthSession}
     */
    public function issueTokenPair(User $user, AuthSession $session, Request $request): array
    {
        $access = $this->issueAccessToken($user, $session);

        $refresh = $this->refreshTokens->issue(
            $user,
            $session,
            null,
            $request->ip(),
            $request->userAgent(),
        );

        return [
            'access_token' => $access['plain'],
            'token_type' => 'Bearer',
            'access_expires_at' => $access['expires_at']->toISOString(),
            'refresh_token' => $refresh['plain'],
            'refresh_expires_at' => $refresh['token']->expires_at->toISOString(),
            'session' => $session,
        ];
    }

    /**
     * @return array{plain: string, expires_at: Carbon}
     */
    public function issueAccessToken(User $user, AuthSession $session): array
    {
        $created = $user->createToken(
            (string) config('api.tokens.access_token_name'),
            [(string) config('api.tokens.access_token_ability')],
            now()->addMinutes((int) config('api.tokens.access_token_ttl')),
        );

        $created->accessToken->forceFill(['session_id' => $session->id])->save();

        return ['plain' => $created->plainTextToken, 'expires_at' => $created->accessToken->expires_at];
    }

    /**
     * Exchange a valid refresh token for a new access + refresh pair.
     *
     * @return array{user: User, session: AuthSession, access_token: string, token_type: string, access_expires_at: string, refresh_token: string, refresh_expires_at: string}
     */
    public function refresh(string $plainRefresh, Request $request): array
    {
        $rotated = $this->refreshTokens->rotate($plainRefresh, $request->ip(), $request->userAgent());
        $access = $this->issueAccessToken($rotated['user'], $rotated['session']);

        return [
            'user' => $rotated['user'],
            'session' => $rotated['session'],
            'access_token' => $access['plain'],
            'token_type' => 'Bearer',
            'access_expires_at' => $access['expires_at']->toISOString(),
            'refresh_token' => $rotated['plain'],
            'refresh_expires_at' => $rotated['token']->expires_at->toISOString(),
        ];
    }

    /**
     * Revoke the session that issued the current access token.
     */
    public function logout(Request $request): void
    {
        $session = $this->currentSession($request);

        $request->user()?->currentAccessToken()?->delete();

        if ($session) {
            $this->refreshTokens->revokeSession($session);
        }
    }

    /**
     * Revoke every session and refresh token for the user.
     */
    public function logoutAll(User $user): void
    {
        $this->refreshTokens->revokeAllForUser($user);
    }

    public function currentSession(Request $request): ?AuthSession
    {
        $token = $request->user()?->currentAccessToken();

        if (! $token instanceof PersonalAccessToken || ! $token->session_id) {
            return null;
        }

        return AuthSession::query()->find($token->session_id);
    }

    /**
     * A stable identifier for the calling client, used to persist sync
     * cursors. Prefers the auth session, falling back to the access token id
     * for tokens that were not created through a login session.
     */
    public function clientKey(Request $request): string
    {
        $token = $request->user()?->currentAccessToken();

        if ($token instanceof PersonalAccessToken) {
            return $token->session_id
                ? (string) $token->session_id
                : 'token:'.$token->getKey();
        }

        return 'anonymous';
    }
}
