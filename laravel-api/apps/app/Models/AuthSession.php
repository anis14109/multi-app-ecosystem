<?php

namespace App\Models;

use App\Models\Concerns\UsesUlid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Sanctum\PersonalAccessToken;

class AuthSession extends Model
{
    use UsesUlid;

    protected $fillable = [
        'user_id',
        'name',
        'ip_address',
        'user_agent',
        'last_used_at',
        'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'last_used_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function refreshTokens(): HasMany
    {
        return $this->hasMany(RefreshToken::class);
    }

    public function accessTokens(): HasMany
    {
        return $this->hasMany(config('sanctum.personal_access_token_model', PersonalAccessToken::class), 'session_id');
    }

    public function isActive(): bool
    {
        return $this->revoked_at === null;
    }

    public function revoke(): void
    {
        $this->setAttribute('revoked_at', now());
        $this->save();
    }

    public function touchLastUsed(): void
    {
        $this->setAttribute('last_used_at', now());
        $this->save();
    }
}
