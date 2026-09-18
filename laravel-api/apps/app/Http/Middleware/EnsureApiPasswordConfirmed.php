<?php

namespace App\Http\Middleware;

use App\Services\Api\V1\PasswordConfirmationService;
use App\Support\ApiResponse;
use App\Support\Enums\ApiErrorCode;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Versioned-API password confirmation guard. Confirmation state is shared
 * with the legacy middleware through the same cache key, so a client may
 * confirm through either endpoint.
 */
class EnsureApiPasswordConfirmed
{
    public function __construct(private readonly PasswordConfirmationService $passwords) {}

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user) {
            return ApiResponse::unauthenticated();
        }

        if (! $this->passwords->isConfirmed($user)) {
            return ApiResponse::error(
                'Password confirmation required.',
                ApiErrorCode::PasswordConfirmationRequired,
                423,
            );
        }

        return $next($request);
    }
}
