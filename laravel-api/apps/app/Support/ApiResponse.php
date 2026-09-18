<?php

namespace App\Support;

use App\Support\Enums\ApiErrorCode;
use Illuminate\Http\JsonResponse;

/**
 * Builds the single, consistent JSON envelope returned by every versioned
 * API endpoint.
 *
 * Success:
 *   { "success": true, "message": "...", "data": {...} }
 *
 * Error:
 *   { "success": false, "message": "...", "code": "VALIDATION_ERROR", "errors": {...} }
 */
final class ApiResponse
{
    /**
     * @param  array<string, mixed>  $errors
     */
    public static function success(
        mixed $data = null,
        string $message = 'Operation successful.',
        int $status = 200,
    ): JsonResponse {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
        ], $status);
    }

    public static function created(mixed $data = null, string $message = 'Resource created.'): JsonResponse
    {
        return self::success($data, $message, 201);
    }

    /**
     * @param  array<string, mixed>  $errors
     */
    public static function error(
        string $message,
        ApiErrorCode $code,
        int $status,
        array $errors = [],
        mixed $data = null,
    ): JsonResponse {
        $payload = [
            'success' => false,
            'message' => $message,
            'code' => $code->value,
        ];

        if ($errors !== []) {
            $payload['errors'] = $errors;
        }

        if ($data !== null) {
            $payload['data'] = $data;
        }

        return response()->json($payload, $status);
    }

    /**
     * @param  array<string, mixed>  $errors
     */
    public static function validation(array $errors, string $message = 'Validation failed.'): JsonResponse
    {
        return self::error($message, ApiErrorCode::ValidationError, 422, $errors);
    }

    public static function unauthenticated(string $message = 'Unauthenticated.'): JsonResponse
    {
        return self::error($message, ApiErrorCode::Unauthenticated, 401);
    }

    public static function forbidden(string $message = 'This action is unauthorized.'): JsonResponse
    {
        return self::error($message, ApiErrorCode::Forbidden, 403);
    }

    public static function notFound(string $message = 'Resource not found.'): JsonResponse
    {
        return self::error($message, ApiErrorCode::NotFound, 404);
    }

    public static function tooManyRequests(string $message = 'Too many requests. Please slow down.'): JsonResponse
    {
        return self::error($message, ApiErrorCode::TooManyRequests, 429);
    }
}
