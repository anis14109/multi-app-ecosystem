<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Password\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\Password\ResetPasswordRequest;
use App\Services\Api\V1\PasswordResetService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class PasswordResetController extends Controller
{
    public function __construct(private readonly PasswordResetService $passwords) {}

    /**
     * Always returns the same response to avoid leaking which emails exist.
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $this->passwords->sendResetLink($request->validated('email'));

        return ApiResponse::success(
            null,
            'If the email exists, a password reset link has been sent.',
        );
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $this->passwords->reset($request->validated());

        return ApiResponse::success(null, 'Password has been reset.');
    }
}
