<?php

namespace App\Exceptions;

use App\Support\Enums\ApiErrorCode;
use RuntimeException;

/**
 * A domain exception that maps directly onto the public API error envelope.
 * The renderer in bootstrap/app.php turns this into a JSON response.
 */
class ApiException extends RuntimeException
{
    /**
     * @param  array<string, mixed>  $errors
     * @param  array<string, mixed>  $context
     */
    public function __construct(
        public readonly ApiErrorCode $errorCode,
        string $message,
        public readonly int $status = 400,
        public readonly array $errors = [],
        public readonly array $context = [],
    ) {
        parent::__construct($message);
    }

    public static function unauthenticated(string $message = 'Unauthenticated.'): self
    {
        return new self(ApiErrorCode::Unauthenticated, $message, 401);
    }

    public static function invalidCredentials(string $message = 'The provided credentials are incorrect.'): self
    {
        return new self(ApiErrorCode::InvalidCredentials, $message, 401);
    }

    public static function invalidToken(string $message = 'The token is invalid.'): self
    {
        return new self(ApiErrorCode::InvalidToken, $message, 401);
    }

    public static function tokenExpired(string $message = 'The token has expired.'): self
    {
        return new self(ApiErrorCode::TokenExpired, $message, 401);
    }

    public static function tokenReused(string $message = 'Token reuse detected. The session has been revoked.'): self
    {
        return new self(ApiErrorCode::TokenReused, $message, 401);
    }

    public static function passwordConfirmationRequired(string $message = 'Password confirmation required.'): self
    {
        return new self(ApiErrorCode::PasswordConfirmationRequired, $message, 403);
    }

    public static function forbidden(string $message = 'This action is unauthorized.'): self
    {
        return new self(ApiErrorCode::Forbidden, $message, 403);
    }

    public static function notFound(string $message = 'Resource not found.'): self
    {
        return new self(ApiErrorCode::NotFound, $message, 404);
    }

    /**
     * @param  array<string, array<int, string>>  $errors
     */
    public static function validation(array $errors, string $message = 'Validation failed.'): self
    {
        return new self(ApiErrorCode::ValidationError, $message, 422, $errors);
    }

    public static function operationFailed(string $message = 'The operation could not be completed.', int $status = 400): self
    {
        return new self(ApiErrorCode::OperationFailed, $message, $status);
    }

    /**
     * @param  array<string, mixed>  $context
     */
    public static function idempotencyConflict(array $context = []): self
    {
        return new self(
            ApiErrorCode::IdempotencyConflict,
            'This operation id was already used with a different request payload.',
            409,
            [],
            $context,
        );
    }

    /**
     * @param  array<string, mixed>  $context
     */
    public static function idempotencyInProgress(array $context = []): self
    {
        return new self(
            ApiErrorCode::IdempotencyInProgress,
            'An operation with this operation id is still being processed. Retry shortly.',
            409,
            [],
            $context,
        );
    }
}
