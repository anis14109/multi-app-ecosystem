<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\EmailVerificationController;
use App\Http\Controllers\Api\V1\PasswordConfirmationController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Version 1 Routes
|--------------------------------------------------------------------------
| Stable, envelope-based REST API for Flutter, Vue.js and Python clients.
| Breaking changes are introduced as /api/v2 while v1 remains supported.
*/

Route::prefix('v1')->name('api.v1.')->group(function (): void {

    /*
    |----------------------------------------------------------------------
    | Public Routes (Unauthenticated)
    |----------------------------------------------------------------------
    */

    Route::middleware('throttle:api-register')
        ->post('/auth/register', [AuthController::class, 'register'])
        ->name('auth.register');

    Route::middleware('throttle:api-login')
        ->post('/auth/login', [AuthController::class, 'login'])
        ->name('auth.login');

    Route::middleware('throttle:api-refresh')
        ->post('/auth/refresh', [AuthController::class, 'refresh'])
        ->name('auth.refresh');

    Route::middleware('throttle:api-password-reset')->group(function (): void {
        Route::post('/auth/forgot-password', [PasswordResetController::class, 'forgotPassword'])
            ->name('password.email');
        Route::post('/auth/reset-password', [PasswordResetController::class, 'resetPassword'])
            ->name('password.update');
    });

    Route::middleware(['signed', 'throttle:api-email-verification'])
        ->get('/auth/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])
        ->name('auth.email.verify');

    /*
    |----------------------------------------------------------------------
    | Authenticated Routes
    |----------------------------------------------------------------------
    */

    Route::middleware(['auth:sanctum', 'throttle:api'])->group(function (): void {

        // Authentication (always available, even when verification is enforced)
        Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');
        Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('auth.logout-all');
        Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');

        // Email verification resend (available before the address is verified)
        Route::middleware('throttle:api-email-verification')
            ->post('/auth/email/verification-notification', [EmailVerificationController::class, 'send'])
            ->name('auth.email.send');

        // Everything below requires a verified email when enforcement is on
        // (`api.email_verification.enforce`); the middleware decides at runtime.
        Route::middleware('api-verified')->group(function (): void {

            // Password Confirmation
            Route::middleware('throttle:api-password-confirmation')
                ->post('/user/confirm-password', [PasswordConfirmationController::class, 'confirm'])
                ->name('user.confirm-password');
        });
    });
});
