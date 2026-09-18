<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

trait UsesUlid
{
    /**
     * Boot the trait: generate a ULID primary key before creating.
     */
    protected static function bootUsesUlid(): void
    {
        static::creating(function ($model): void {
            if (empty($model->{$model->getKeyName()})) {
                $model->{$model->getKeyName()} = (string) Str::ulid();
            }
        });
    }

    /**
     * Get the value indicating whether the IDs are incrementing.
     */
    public function getIncrementing(): bool
    {
        return false;
    }

    /**
     * Get the auto-incrementing key type.
     */
    public function getKeyType(): string
    {
        return 'string';
    }
}
