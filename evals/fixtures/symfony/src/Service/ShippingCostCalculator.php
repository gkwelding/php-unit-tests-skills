<?php

namespace App\Service;

final class ShippingCostCalculator
{
    /**
     * Shipping cost in pence.
     */
    public function costFor(int $weightGrams, string $countryCode, bool $express = false): int
    {
        if ($weightGrams <= 0) {
            throw new \InvalidArgumentException('Weight must be positive');
        }

        $cost = match (true) {
            $weightGrams <= 1000 => 399,
            $weightGrams <= 5000 => 699,
            default => 999 + intdiv($weightGrams - 5000, 1000) * 100,
        };

        if ($countryCode !== 'GB') {
            $cost *= 2;
        }

        if ($express) {
            $cost += 500;
        }

        return $cost;
    }
}
