<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\URL;

/**
 * Email verification notification for API clients. Unlike Laravel's default
 * notification it links to a signed API endpoint, so verification never
 * depends on a Blade page.
 */
class VerifyEmailApi extends Notification
{
    use Queueable;

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Verify your email address')
            ->greeting('Hello '.$notifiable->name.',')
            ->line('Please confirm your email address to finish setting up your account.')
            ->action('Verify email address', $this->verificationUrl($notifiable))
            ->line('This link expires in '.$this->expiresInMinutes().' minutes.')
            ->line('If you did not create an account, no further action is required.');
    }

    protected function verificationUrl(object $notifiable): string
    {
        return URL::temporarySignedRoute(
            'api.v1.auth.email.verify',
            Carbon::now()->addMinutes($this->expiresInMinutes()),
            [
                'id' => $notifiable->getKey(),
                'hash' => sha1($notifiable->getEmailForVerification()),
            ],
        );
    }

    private function expiresInMinutes(): int
    {
        return (int) config('api.email_verification.expire_minutes', 60);
    }
}
