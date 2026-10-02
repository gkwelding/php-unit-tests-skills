<?php

namespace App\Services;

use App\Enums\CustomerTier;
use InvalidArgumentException;

final class DiscountCalculator
{
    /**
     * Discount in pence for an order subtotal in pence. Capped at £50.
     */
    public function discountFor(int $subtotal, CustomerTier $tier, ?string $coupon = null): int
    {
        if ($subtotal < 0) {
            throw new InvalidArgumentException('Subtotal must not be negative');
        }

        $percent = match ($tier) {
            CustomerTier::Standard => $subtotal >= 10000 ? 5 : 0,
            CustomerTier::Gold => $subtotal >= 5000 ? 10 : 5,
            CustomerTier::Staff => 30,
        };

        if ($coupon === 'WELCOME10' && $tier !== CustomerTier::Staff) {
            $percent += 10;
        }

        return min(intdiv($subtotal * $percent, 100), 5000);
    }
}
