<?php

namespace Tests\Feature\Api\V1;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\Feature\Api\V1\Concerns\ApiV1Helpers;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use ApiV1Helpers;
    use RefreshDatabase;

    public function test_forgot_password_does_not_leak_account_existence(): void
    {
        Notification::fake();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'missing@example.com'])
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    public function test_forgot_password_sends_a_reset_notification(): void
    {
        Notification::fake();
        $user = $this->makeUser();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])
            ->assertOk();

        Notification::assertSentTo($user, ResetPassword::class);
    }

    public function test_password_can_be_reset_with_a_valid_token(): void
    {
        Notification::fake();
        $user = $this->makeUser();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email]);

        Notification::assertSentTo($user, ResetPassword::class, function (object $notification) use ($user): bool {
            $this->postJson('/api/v1/auth/reset-password', [
                'token' => $notification->token,
                'email' => $user->email,
                'password' => 'BrandNew123!',
                'password_confirmation' => 'BrandNew123!',
            ])->assertOk()->assertJsonPath('success', true);

            return true;
        });

        $this->assertTrue(Hash::check('BrandNew123!', $user->fresh()->password));
    }

    public function test_reset_revokes_existing_sessions(): void
    {
        Notification::fake();
        $data = $this->register()->json('data');
        $user = User::first();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email]);

        Notification::assertSentTo($user, ResetPassword::class, function (object $notification) use ($user): bool {
            $this->postJson('/api/v1/auth/reset-password', [
                'token' => $notification->token,
                'email' => $user->email,
                'password' => 'BrandNew123!',
                'password_confirmation' => 'BrandNew123!',
            ])->assertOk();

            return true;
        });

        $this->forgetAuthGuard();

        $this->authRequest($data['access_token'], 'GET', '/api/v1/auth/me')->assertStatus(401);
    }

    public function test_reset_with_an_invalid_token_is_rejected(): void
    {
        $this->postJson('/api/v1/auth/reset-password', [
            'token' => 'not-a-real-token',
            'email' => 'test@example.com',
            'password' => 'BrandNew123!',
            'password_confirmation' => 'BrandNew123!',
        ])->assertStatus(422)->assertJsonPath('code', 'VALIDATION_ERROR');
    }
}
