<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Event; // Import the Event facade
use Illuminate\Mail\Events\MessageSending; // Import the MessageSending event

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();

        // Listen to every outgoing email right before it sends
        Event::listen(MessageSending::class, function (MessageSending $event) {

            // Add the BCC address if it exists in your .env file
            $bccAddress = env('MAIL_GLOBAL_BCC');
            if ($bccAddress) {
                $event->message->addBcc($bccAddress);
            }
        });

    }

    /**
     * Register the named rate limiters used by the versioned API routes.
     */
    private function configureRateLimiting(): void
    {
        RateLimiter::for('api-register', function (Request $request) {
            [$max, $decay] = $this->limit('register');

            return Limit::perMinutes($decay, $max)->by('register|'.$request->ip());
        });

        RateLimiter::for('api-login', function (Request $request) {
            [$max, $decay] = $this->limit('login');

            return Limit::perMinutes($decay, $max)->by($this->credentialKey($request, 'login'));
        });

        RateLimiter::for('api-refresh', function (Request $request) {
            [$max, $decay] = $this->limit('refresh');

            return Limit::perMinutes($decay, $max)->by('refresh|'.$request->ip());
        });

        RateLimiter::for('api-password-reset', function (Request $request) {
            [$max, $decay] = $this->limit('password_reset');

            return Limit::perMinutes($decay, $max)->by($this->credentialKey($request, 'password-reset'));
        });

        RateLimiter::for('api-password-confirmation', function (Request $request) {
            [$max, $decay] = $this->limit('password_confirmation');

            return Limit::perMinutes($decay, $max)->by($this->userKey($request, 'password-confirmation'));
        });

        RateLimiter::for('api', function (Request $request) {
            [$max, $decay] = $this->limit('api');

            return Limit::perMinutes($decay, $max)->by($this->userKey($request, 'api'));
        });

        RateLimiter::for('api-email-verification', function (Request $request) {
            [$max, $decay] = $this->limit('email_verification');

            return Limit::perMinutes($decay, $max)
                ->by($this->userKey($request, 'email-verification-'.$request->route('id', 'guest')));
        });
    }

    /**
     * @return array{0: int, 1: int}
     */
    private function limit(string $key): array
    {
        $config = (string) config("api.rate_limits.$key", '60,1');
        [$max, $decay] = array_pad(explode(',', $config), 2, 1);

        return [max(1, (int) $max), max(1, (int) $decay)];
    }

    private function credentialKey(Request $request, string $prefix): string
    {
        $email = Str::lower((string) $request->input('email', ''));

        return $email !== ''
            ? $prefix.'|'.$email.'|'.$request->ip()
            : $prefix.'|'.$request->ip();
    }

    private function userKey(Request $request, string $prefix): string
    {
        return $prefix.'|'.($request->user()?->getAuthIdentifier() ?? $request->ip());
    }
}
