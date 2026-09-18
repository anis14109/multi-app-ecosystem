<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\ApiResponse;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Frontend-independent email verification. The signed link delivered by
 * VerifyEmailApi points here; the response is JSON, or a redirect to the
 * configured frontend URL when one is set.
 */
class EmailVerificationController extends Controller
{
    public function verify(Request $request, string $id, string $hash): JsonResponse|RedirectResponse
    {
        $user = User::query()->findOrFail($id);

        if (! hash_equals(sha1($user->getEmailForVerification()), $hash)) {
            return ApiResponse::forbidden('This email verification link is invalid.');
        }

        if (! $user->hasVerifiedEmail()) {
            if ($user->markEmailAsVerified()) {
                event(new Verified($user));
            }
        }

        if ($redirect = config('api.email_verification.redirect_url')) {
            $separator = str_contains((string) $redirect, '?') ? '&' : '?';

            return redirect()->away($redirect.$separator.'verified=1');
        }

        return ApiResponse::success([
            'verified' => true,
            'email_verified_at' => $user->email_verified_at?->toISOString(),
        ], 'Email address verified.');
    }

    /**
     * Resend the verification notification. Always returns the same response
     * for verified and unverified accounts to avoid leaking account state.
     */
    public function send(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->hasVerifiedEmail()) {
            $user->sendEmailVerificationNotification();
        }

        return ApiResponse::success(
            ['verified' => $user->hasVerifiedEmail()],
            'If your email address is not verified, a new verification link has been sent.',
        );
    }
}
