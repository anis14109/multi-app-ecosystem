<?php

namespace App\Http\Requests\Api\V1\Concerns;

use Illuminate\Validation\Rules\Password;

trait PasswordValidationRules
{
    /**
     * The password rules shared by every API password endpoint.
     *
     * @return array<int, mixed>
     */
    protected function passwordRules(bool $confirmed = true): array
    {
        $rules = ['required', 'string', Password::default()];

        if ($confirmed) {
            $rules[] = 'confirmed';
        }

        return $rules;
    }
}
