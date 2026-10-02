<?php

declare(strict_types=1);

namespace App\Service;

use Psr\Clock\ClockInterface;

final class ShippingCostCalculator
{
    private const FREE_SHIPPING_FROM = 5000;

    public function __construct(private readonly ClockInterface $clock)
    {
    }

    /**
     * Shipping cost in pence.
     *
     * Weight band price (over 5 kg: £9.99 plus £1 per started kilo), times a zone multiplier
     * (GB 1, IE 2, elsewhere 3).
     * GB orders of £50 or more ship free; express is extra and costs more for orders
     * placed from 14:00 UK time. Country codes are case-insensitive and may be padded.
     */
    public function costFor(int $weightGrams, string $countryCode, int $orderTotal, bool $express = false): int
    {
        if ($weightGrams <= 0) {
            throw new \InvalidArgumentException('Weight must be positive');
        }

        $country = strtoupper(trim($countryCode));
        if ($country === '') {
            throw new \InvalidArgumentException('Country code is required');
        }

        $cost = match (true) {
            $weightGrams <= 1000 => 399,
            $weightGrams <= 5000 => 699,
            default => 999 + 100 * (int) ceil(($weightGrams - 5000) / 1000),
        };

        $cost *= match ($country) {
            'GB' => 1,
            'IE' => 2,
            default => 3,
        };

        if ($country === 'GB' && $orderTotal >= self::FREE_SHIPPING_FROM) {
            $cost = 0;
        }

        if ($express) {
            $cost += $this->expressFee();
        }

        return $cost;
    }

    private function expressFee(): int
    {
        $ukTime = $this->clock->now()->setTimezone(new \DateTimeZone('Europe/London'))->format('H:i');

        return $ukTime < '14:00' ? 500 : 800;
    }
}
