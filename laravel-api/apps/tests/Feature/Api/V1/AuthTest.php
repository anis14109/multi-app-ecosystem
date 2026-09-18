<?php

namespace Tests\Feature\Api\V1;

use App\Models\AuthSession;
use App\Models\RefreshToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\Feature\Api\V1\Concerns\ApiV1Helpers;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use ApiV1Helpers;
    use RefreshDatabase;

    public function test_user_can_register_and_receives_a_token_pair(): void
    {
        $response = $this->register();

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.user.email', 'test@example.com')
            ->assertJsonPath('data.token_type', 'Bearer')
            ->assertJsonStructure([
                'data' => [
                    'access_token',
                    'refresh_token',
                    'access_expires_at',
                    'refresh_expires_at',
                    'session' => ['id', 'name', 'current'],
                ],
            ]);

        $this->assertDatabaseHas('users', ['email' => 'test@example.com']);
        $this->assertSame(1, AuthSession::query()->count());
        $this->assertSame(1, RefreshToken::query()->count());
        $this->assertSame(1, PersonalAccessToken::query()->count());
    }

    public function test_register_validation_is_returned_as_an_envelope(): void
    {
        $response = $this->postJson('/api/v1/auth/register', []);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('code', 'VALIDATION_ERROR')
            ->assertJsonValidationErrors(['name', 'email', 'password']);
    }

    public function test_register_rejects_a_duplicate_email(): void
    {
        $this->makeUser(['email' => 'dupe@example.com']);

        $this->register(['email' => 'dupe@example.com'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    public function test_user_can_login_with_valid_credentials(): void
    {
        $this->makeUser();

        $this->login()
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token']]);
    }

    public function test_login_with_invalid_credentials_returns_a_stable_error_code(): void
    {
        $this->makeUser();

        $this->login(password: 'WrongPassword1!')
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('code', 'INVALID_CREDENTIALS');
    }

    public function test_unauthenticated_requests_receive_the_envelope(): void
    {
        $this->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    public function test_me_returns_the_authenticated_user(): void
    {
        $data = $this->register()->json('data');

        $this->authRequest($data['access_token'], 'GET', '/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'test@example.com');
    }

    public function test_refresh_rotates_the_token_pair(): void
    {
        $data = $this->register()->json('data');

        $refreshed = $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $data['refresh_token'],
        ]);

        $refreshed->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token']]);

        $this->assertNotSame($data['refresh_token'], $refreshed->json('data.refresh_token'));
        $this->assertNotSame($data['access_token'], $refreshed->json('data.access_token'));
    }

    public function test_reusing_a_rotated_refresh_token_revokes_the_family(): void
    {
        $data = $this->register()->json('data');

        $rotated = $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $data['refresh_token'],
        ])->json('data');

        $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $data['refresh_token']])
            ->assertStatus(401)
            ->assertJsonPath('code', 'TOKEN_REUSED');

        $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $rotated['refresh_token']])
            ->assertStatus(401)
            ->assertJsonPath('code', 'INVALID_TOKEN');
    }

    public function test_an_invalid_refresh_token_is_rejected(): void
    {
        $this->postJson('/api/v1/auth/refresh', ['refresh_token' => 'not-a-real-token'])
            ->assertStatus(401)
            ->assertJsonPath('code', 'INVALID_TOKEN');
    }

    public function test_logout_revokes_the_current_token_and_session(): void
    {
        $data = $this->register()->json('data');
        $token = $data['access_token'];

        $this->authRequest($token, 'POST', '/api/v1/auth/logout')->assertOk();

        $this->forgetAuthGuard();

        $this->authRequest($token, 'GET', '/api/v1/auth/me')->assertStatus(401);
        $this->assertNotNull(AuthSession::query()->first()->revoked_at);
    }

    public function test_logout_all_revokes_every_session(): void
    {
        $first = $this->register()->json('data');
        $second = $this->login()->json('data');

        $this->authRequest($first['access_token'], 'POST', '/api/v1/auth/logout-all')->assertOk();

        $this->forgetAuthGuard();

        $this->authRequest($first['access_token'], 'GET', '/api/v1/auth/me')->assertStatus(401);
        $this->authRequest($second['access_token'], 'GET', '/api/v1/auth/me')->assertStatus(401);
    }

    public function test_login_is_rate_limited(): void
    {
        $this->makeUser();

        for ($attempt = 0; $attempt < 10; $attempt++) {
            $this->login(password: 'WrongPassword1!')->assertStatus(401);
        }

        $this->login(password: 'WrongPassword1!')
            ->assertStatus(429)
            ->assertJsonPath('code', 'TOO_MANY_REQUESTS');
    }
}
