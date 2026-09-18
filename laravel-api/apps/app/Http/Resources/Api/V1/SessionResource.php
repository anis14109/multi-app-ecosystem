<?php

namespace App\Http\Resources\Api\V1;

use App\Models\AuthSession;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin AuthSession
 */
class SessionResource extends JsonResource
{
    public function __construct($resource, private readonly bool $isCurrent = false)
    {
        parent::__construct($resource);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'ip_address' => $this->ip_address,
            'user_agent' => $this->user_agent,
            'current' => $this->isCurrent,
            'last_used_at' => $this->last_used_at?->toISOString(),
            'revoked_at' => $this->revoked_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
