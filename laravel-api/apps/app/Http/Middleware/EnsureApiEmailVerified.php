<?php

namespace App\Http\Middleware;

use App\Support\ApiResponse;
use App\Support\Enums\ApiErrorCode;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Rejects authenticated but unverified users with the standard error
 * envelope. Used only when `api.email_verification.enforce` is enabled.
 */
class EnsureApiEmailVerified
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! config('api.email_verification.enforce')) {
            return $next($request);
        }

        $user = $request->user();

        if ($user !== null && ! $user->hasVerifiedEmail()) {
            return ApiResponse::error(
                'Your email address is not verified.',
                ApiErrorCode::EmailNotVerified,
                403,
            );
        }

        return $next($request);
    }
}
