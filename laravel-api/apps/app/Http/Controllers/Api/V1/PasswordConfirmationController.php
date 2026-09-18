<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\User\ConfirmPasswordRequest;
use App\Services\Api\V1\PasswordConfirmationService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;

class PasswordConfirmationController extends Controller
{
    public function __construct(private readonly PasswordConfirmationService $passwords) {}

    public function confirm(ConfirmPasswordRequest $request): JsonResponse
    {
        if (! $this->passwords->confirm($request->user(), $request->validated('password'))) {
            throw ApiException::validation(
                ['password' => ['The password is incorrect.']],
                'The password is incorrect.',
            );
        }

        return ApiResponse::success(null, 'Password confirmed.');
    }
}
