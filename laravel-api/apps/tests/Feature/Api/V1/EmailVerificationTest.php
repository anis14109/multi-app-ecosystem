<?php

namespace Tests\Feature\Api\V1;

use App\Models\User;
use App\Notifications\VerifyEmailApi;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\URL;
use Tests\Feature\Api\V1\Concerns\ApiV1Helpers;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use ApiV1Helpers;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['api.email_verification.enabled' => true]);
    }

    private function signedUrl(User $user, ?string $hash = null): string
    {
        return URL::temporarySignedRoute(
            'api.v1.auth.email.verify',
            now()->addMinutes(60),
            ['id' => $user->id, 'hash' => $hash ?? sha1($user->email)],
        );
    }

    public function test_registration_sends_a_verification_notification(): void
    {
        Notification::fake();

        $this->register()->assertCreated();

        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        $this->assertNull($user->email_verified_at);
        Notification::assertSentTo($user, VerifyEmailApi::class);
    }

    public function test_a_signed_link_verifies_the_email(): void
    {
        Notification::fake();

        $this->register();
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        $this->getJson($this->signedUrl($user))
            ->assertOk()
            ->assertJsonPath('data.verified', true);

        $this->assertTrue($user->fresh()->hasVerifiedEmail());
    }

    public function test_verification_is_idempotent(): void
    {
        Notification::fake();

        $this->register();
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();
        $url = $this->signedUrl($user);

        $this->getJson($url)->assertOk();
        $verifiedAt = $user->fresh()->email_verified_at;

        $this->getJson($url)->assertOk();

        $this->assertEquals($verifiedAt, $user->fresh()->email_verified_at);
    }

    public function test_a_link_with_the_wrong_hash_is_rejected(): void
    {
        Notification::fake();

        $this->register();
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        $this->getJson($this->signedUrl($user, sha1('someone-else@example.com')))
            ->assertStatus(403);

        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_an_unsigned_link_is_rejected(): void
    {
        Notification::fake();

        $this->register();
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        $this->getJson('/api/v1/auth/email/verify/'.$user->id.'/'.sha1($user->email))
            ->assertStatus(403);

        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_a_redirect_url_is_used_when_configured(): void
    {
        Notification::fake();
        config(['api.email_verification.redirect_url' => 'https://app.example.com/verified']);

        $this->register();
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        $this->get($this->signedUrl($user))
            ->assertRedirect('https://app.example.com/verified?verified=1');

        $this->assertTrue($user->fresh()->hasVerifiedEmail());
    }

    public function test_a_user_can_request_a_new_verification_link(): void
    {
        Notification::fake();

        $token = $this->register()->json('data.access_token');
        $user = User::query()->where('email', 'test@example.com')->firstOrFail();

        Notification::fake();

        $this->authRequest($token, 'POST', '/api/v1/auth/email/verification-notification')
            ->assertOk()
            ->assertJsonPath('data.verified', false);

        Notification::assertSentTo($user, VerifyEmailApi::class);
    }

    public function test_resending_does_not_notify_an_already_verified_user(): void
    {
        Notification::fake();

        $this->makeUser(['email' => 'test@example.com', 'email_verified_at' => now()]);
        $token = $this->login()->json('data.access_token');

        Notification::fake();

        $this->authRequest($token, 'POST', '/api/v1/auth/email/verification-notification')
            ->assertOk()
            ->assertJsonPath('data.verified', true);

        Notification::assertNothingSent();
    }

    public function test_enforcement_blocks_unverified_users_but_not_verification_endpoints(): void
    {
        Notification::fake();
        config(['api.email_verification.enforce' => true]);

        $token = $this->register()->json('data.access_token');

        $this->authRequest($token, 'POST', '/api/v1/user/confirm-password', ['password' => 'Password123!'])
            ->assertStatus(403)
            ->assertJsonPath('code', 'EMAIL_NOT_VERIFIED');

        $this->authRequest($token, 'GET', '/api/v1/auth/me')->assertOk();

        $user = User::query()->where('email', 'test@example.com')->firstOrFail();
        $this->getJson($this->signedUrl($user))->assertOk();

        $this->forgetAuthGuard();

        $this->authRequest($token, 'POST', '/api/v1/user/confirm-password', ['password' => 'Password123!'])
            ->assertOk();
    }

    public function test_enforcement_is_off_by_default(): void
    {
        Notification::fake();

        $token = $this->register()->json('data.access_token');

        $this->authRequest($token, 'POST', '/api/v1/user/confirm-password', ['password' => 'Password123!'])
            ->assertOk();
    }
}
