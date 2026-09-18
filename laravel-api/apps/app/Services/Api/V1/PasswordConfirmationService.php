<?php

namespace App\Services\Api\V1;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;

/**
 * Stateless password confirmation for API clients. The confirmation window is
 * stored in the cache keyed by user id rather than in a browser session.
 */
class PasswordConfirmationService
{
    public function confirm(User $user, string $password): bool
    {
        if (! Hash::check($password, $user->password)) {
            return false;
        }

        Cache::put($this->cacheKey($user), now()->timestamp, $this->timeout());

        return true;
    }

    public function isConfirmed(User $user): bool
    {
        $confirmedAt = Cache::get($this->cacheKey($user));

        if (! $confirmedAt) {
            return false;
        }

        return now()->timestamp - (int) $confirmedAt <= $this->timeout();
    }

    public function cacheKey(User $user): string
    {
        return 'password_confirmation_'.$user->id;
    }

    public function timeout(): int
    {
        return (int) config('auth.password_timeout', 10800);
    }
}
