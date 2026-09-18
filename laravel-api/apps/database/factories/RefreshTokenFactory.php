<?php

namespace Database\Factories;

use App\Models\AuthSession;
use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<RefreshToken>
 */
class RefreshTokenFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'auth_session_id' => AuthSession::factory(),
            'hash' => hash('sha256', Str::random(64)),
            'family_id' => (string) Str::ulid(),
            'expires_at' => now()->addMinutes(config('api.tokens.refresh_token_ttl', 20160)),
        ];
    }

    /**
     * Mark the token as expired.
     */
    public function expired(): static
    {
        return $this->state(fn (array $attributes) => [
            'expires_at' => now()->subMinute(),
        ]);
    }

    /**
     * Mark the token as revoked.
     */
    public function revoked(): static
    {
        return $this->state(fn (array $attributes) => [
            'revoked_at' => now(),
        ]);
    }

    /**
     * Mark the token as already rotated (used).
     */
    public function used(string $replacementId): static
    {
        return $this->state(fn (array $attributes) => [
            'replaced_by_id' => $replacementId,
        ]);
    }
}
