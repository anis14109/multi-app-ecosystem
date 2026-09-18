<?php

namespace App\Services\Api\V1;

use App\Exceptions\ApiException;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

/**
 * Password reset through Laravel's password broker. A successful reset revokes
 * every existing session so a stolen refresh token cannot survive a recovery.
 */
class PasswordResetService
{
    public function __construct(private readonly RefreshTokenService $refreshTokens) {}

    /**
     * @return string the password broker status constant
     */
    public function sendResetLink(string $email): string
    {
        return Password::sendResetLink(['email' => Str::lower($email)]);
    }

    /**
     * @param  array{email: string, password: string, password_confirmation: string, token: string}  $data
     */
    public function reset(array $data): void
    {
        $status = Password::reset($data, function (User $user, string $password): void {
            DB::transaction(function () use ($user, $password): void {
                $user->forceFill([
                    'password' => $password,
                    'remember_token' => Str::random(60),
                ])->save();

                if (config('api.security.revoke_sessions_on_password_reset')) {
                    $this->refreshTokens->revokeAllForUser($user);
                }
            });
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ApiException::validation(
                ['token' => [__($status)]],
                'Invalid or expired reset token.',
            );
        }
    }
}
