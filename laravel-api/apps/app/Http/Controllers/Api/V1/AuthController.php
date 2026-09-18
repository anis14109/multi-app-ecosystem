<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\LoginRequest;
use App\Http\Requests\Api\V1\Auth\RefreshTokenRequest;
use App\Http\Requests\Api\V1\Auth\RegisterRequest;
use App\Http\Resources\Api\V1\SessionResource;
use App\Http\Resources\Api\V1\UserResource;
use App\Services\Api\V1\AuthService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $user = $this->auth->register($request->validated());

        $result = $this->auth->authenticate(
            $user,
            $request->validated('device_name') ?? 'API client',
            $request,
        );

        return ApiResponse::created($this->tokenPayload($result), 'Registration successful.');
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $result = $this->auth->login(
            $request->validated('email'),
            $request->validated('password'),
            $request->validated('device_name') ?? 'API client',
            $request,
        );

        if ($result['two_factor_required']) {
            return ApiResponse::success([
                'two_factor_required' => true,
                'two_factor_token' => $result['two_factor_token'],
                'user' => new UserResource($result['user']),
            ], 'Two-factor authentication is required.');
        }

        return ApiResponse::success($this->tokenPayload($result), 'Login successful.');
    }

    public function refresh(RefreshTokenRequest $request): JsonResponse
    {
        $result = $this->auth->refresh($request->validated('refresh_token'), $request);

        return ApiResponse::success($this->tokenPayload($result), 'Token refreshed.');
    }

    public function me(Request $request): JsonResponse
    {
        return ApiResponse::success(new UserResource($request->user()), 'Authenticated user.');
    }

    public function logout(Request $request): JsonResponse
    {
        $this->auth->logout($request);

        return ApiResponse::success(null, 'Logged out.');
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $this->auth->logoutAll($request->user());

        return ApiResponse::success(null, 'All sessions logged out.');
    }

    /**
     * @param  array<string, mixed>  $result
     * @return array<string, mixed>
     */
    private function tokenPayload(array $result): array
    {
        return [
            'user' => new UserResource($result['user']),
            'access_token' => $result['access_token'],
            'token_type' => $result['token_type'],
            'access_expires_at' => $result['access_expires_at'],
            'refresh_token' => $result['refresh_token'],
            'refresh_expires_at' => $result['refresh_expires_at'],
            'session' => new SessionResource($result['session'], true),
        ];
    }
}
