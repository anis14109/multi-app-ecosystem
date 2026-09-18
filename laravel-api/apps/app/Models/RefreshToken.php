<?php

namespace App\Models;

use App\Models\Concerns\UsesUlid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RefreshToken extends Model
{
    use UsesUlid;

    protected $fillable = [
        'user_id',
        'auth_session_id',
        'hash',
        'family_id',
        'expires_at',
        'last_used_at',
        'revoked_at',
        'replaced_by_id',
        'ip_address',
        'user_agent',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'last_used_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function authSession(): BelongsTo
    {
        return $this->belongsTo(AuthSession::class);
    }

    public function isUsable(): bool
    {
        return $this->revoked_at === null
            && $this->replaced_by_id === null
            && $this->expires_at?->isFuture();
    }

    public function isRevoked(): bool
    {
        return $this->revoked_at !== null;
    }

    public function isExpired(): bool
    {
        return $this->expires_at?->isPast() ?? false;
    }

    public function revoke(): void
    {
        $this->setAttribute('revoked_at', now());
        $this->save();
    }

    public function hashSecret(string $secret): string
    {
        return hash('sha256', $secret);
    }
}
