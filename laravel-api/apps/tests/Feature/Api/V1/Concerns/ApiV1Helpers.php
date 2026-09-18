<?php

namespace Tests\Feature\Api\V1\Concerns;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

trait ApiV1Helpers
{
    protected function makeUser(array $attributes = []): User
    {
        return User::factory()->create(array_merge([
            'email' => 'test@example.com',
            'password' => Hash::make('Password123!'),
        ], $attributes));
    }

    protected function register(array $overrides = []): TestResponse
    {
        return $this->postJson('/api/v1/auth/register', array_merge([
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'device_name' => 'phpunit',
        ], $overrides));
    }

    protected function login(string $email = 'test@example.com', string $password = 'Password123!'): TestResponse
    {
        return $this->postJson('/api/v1/auth/login', [
            'email' => $email,
            'password' => $password,
            'device_name' => 'phpunit',
        ]);
    }

    protected function authRequest(string $token, string $method, string $uri, array $data = []): TestResponse
    {
        return $this->withHeader('Authorization', 'Bearer '.$token)->json($method, $uri, $data);
    }

    /**
     * Simulate a brand new request. Within a single test the container (and
     * therefore the resolved auth guard) is reused between HTTP calls, which
     * memoizes the authenticated user; real requests never share that state.
     */
    protected function forgetAuthGuard(): void
    {
        $this->app['auth']->forgetGuards();
    }
}
