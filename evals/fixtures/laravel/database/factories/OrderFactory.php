<?php

namespace Database\Factories;

use App\Models\Order;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    public function definition(): array
    {
        return [
            'customer_email' => fake()->safeEmail(),
            'weight_grams' => fake()->numberBetween(100, 20000),
            'express' => fake()->boolean(),
        ];
    }
}
