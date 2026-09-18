<?php

return [

    /*
    |--------------------------------------------------------------------------
    | API Version
    |--------------------------------------------------------------------------
    |
    | The current public API version. All versioned endpoints live under the
    | `/api/{version}/...` prefix (e.g. `/api/v1/auth/login`).
    |
    */

    'version' => env('API_VERSION', 'v1'),

    /*
    |--------------------------------------------------------------------------
    | Token & Session Lifecycle
    |--------------------------------------------------------------------------
    |
    | These values control the lifetime of the short-lived access tokens and
    | the long-lived rotating refresh tokens. All values are in minutes.
    |
    | - access_token_ttl: how long a single access token is valid. Keep short.
    | - refresh_token_ttl: how long a refresh token may live before it must be
    |   re-issued. Rotation extends the lifetime of the token family.
    | - two_factor_challenge_ttl: how long the temporary two-factor challenge
    |   token issued during a login remains usable.
    |
    */

    'tokens' => [
        'access_token_ttl' => env('ACCESS_TOKEN_TTL', 15),
        'refresh_token_ttl' => env('REFRESH_TOKEN_TTL', 20160),
        'refresh_token_reuse_policy' => env('REFRESH_TOKEN_REUSE_POLICY', 'revoke_family'),
        'two_factor_challenge_ttl' => env('TWO_FACTOR_CHALLENGE_TTL', 5),

        'access_token_name' => 'access-token',
        'access_token_ability' => 'access-token',
        'two_factor_challenge_name' => 'two-factor-challenge',
        'two_factor_challenge_ability' => 'two-factor-challenge',
    ],

    /*
    |--------------------------------------------------------------------------
    | Offline-First Synchronization
    |--------------------------------------------------------------------------
    |
    | - pull_batch_size: maximum number of change-log entries returned per pull.
    | - push_batch_size / max_operations_per_push: maximum operations accepted
    |   in a single push request.
    | - cursor_policy: how server revision cursors are maintained.
    | - change_log_retention_days: number of days to keep change-log entries
    |   before pruning, but only entries every client has acknowledged. 0 means
    |   keep forever. Pruned automatically by the `sync:prune-change-log`
    |   command, scheduled in routes/console.php.
    | - idempotency_retention_days: number of days to keep completed idempotency
    |   records. Must exceed the longest client retry window so a late retry is
    |   still replayed instead of executing twice. 0 means keep forever.
    |
    */

    'sync' => [
        'pull_batch_size' => env('SYNC_PULL_BATCH_SIZE', 200),
        'push_batch_size' => env('SYNC_PUSH_BATCH_SIZE', 100),
        'max_operations_per_push' => env('SYNC_MAX_OPERATIONS_PER_PUSH', 200),
        'cursor_policy' => env('SYNC_CURSOR_POLICY', 'monotonic_revisions'),
        'change_log_retention_days' => env('SYNC_CHANGE_LOG_RETENTION_DAYS', 30),
        'idempotency_retention_days' => env('SYNC_IDEMPOTENCY_RETENTION_DAYS', 30),
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate Limits
    |--------------------------------------------------------------------------
    |
    | Cedar-shaped `count,minutes` values consumed by the named rate limiters
    | registered in AppServiceProvider.
    |
    */

    'rate_limits' => [
        'register' => env('RATE_LIMIT_REGISTER', '5,15'),
        'login' => env('RATE_LIMIT_LOGIN', '10,1'),
        'refresh' => env('RATE_LIMIT_REFRESH', '60,1'),
        'password_reset' => env('RATE_LIMIT_PASSWORD_RESET', '5,15'),
        'password_confirmation' => env('RATE_LIMIT_PASSWORD_CONFIRMATION', '10,1'),
        'two_factor' => env('RATE_LIMIT_TWO_FACTOR', '10,1'),
        'api' => env('RATE_LIMIT_API', '240,1'),
        'sync' => env('RATE_LIMIT_SYNC', '120,1'),
        'email_verification' => env('RATE_LIMIT_EMAIL_VERIFICATION', '3,1'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Security Policies
    |--------------------------------------------------------------------------
    |
    | - revoke_sessions_on_password_change: revoke every session except the
    |   current one when the user changes their password.
    | - revoke_sessions_on_password_reset: revoke every session when a password
    |   is reset through the forgot-password flow.
    |
    */

    'security' => [
        'revoke_sessions_on_password_change' => env('REVOKE_SESSIONS_ON_PASSWORD_CHANGE', true),
        'revoke_sessions_on_password_reset' => env('REVOKE_SESSIONS_ON_PASSWORD_RESET', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Email Verification
    |--------------------------------------------------------------------------
    |
    | Email verification is delivered as a signed API URL so it never depends on
    | a Blade page. The link points at `GET /api/v1/auth/email/verify/{id}/{hash}`
    | and returns JSON. Set `redirect_url` to a frontend deep link to redirect
    | users there instead once verified.
    |
    | - enabled: whether registration sends a verification notification and the
    |   verification endpoints are active.
    | - enforce: when true, authenticated API routes (except the verification
    |   and session endpoints) require a verified email. Off by default so the
    |   existing behaviour of current clients is preserved.
    | - expire_minutes: lifetime of the signed verification link.
    |
    */

    'email_verification' => [
        'enabled' => env('EMAIL_VERIFICATION_ENABLED', true),
        'enforce' => env('EMAIL_VERIFICATION_ENFORCE', false),
        'expire_minutes' => env('EMAIL_VERIFICATION_EXPIRE_MINUTES', 60),
        'redirect_url' => env('EMAIL_VERIFICATION_REDIRECT_URL'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Pagination
    |--------------------------------------------------------------------------
    |
    | Default and maximum page / cursor sizes for list endpoints.
    |
    */

    'pagination' => [
        'default_per_page' => env('API_DEFAULT_PER_PAGE', 20),
        'max_per_page' => env('API_MAX_PER_PAGE', 100),
    ],

];
