<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Str;
use Illuminate\Translation\PotentiallyTranslatedString;

/**
 * Accepts either a UUID (v1-v8) or a ULID so offline clients may generate
 * their own identifiers using either format.
 */
class UuidOrUlid implements ValidationRule
{
    /**
     * @param  Closure(string, ?string=): PotentiallyTranslatedString  $fail
     */
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value) || (! Str::isUuid($value) && ! Str::isUlid($value))) {
            $fail('The :attribute must be a valid UUID or ULID.');
        }
    }
}
