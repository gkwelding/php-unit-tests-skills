<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\CustomerTier;
use DateTimeImmutable;
use Illuminate\Support\Carbon;
use InvalidArgumentException;

final class DiscountCalculator
{
    /**
     * Discount in pence for an order subtotal in pence.
     *
     * Tier rate, plus an optional coupon, rounded half up and capped per tier
     * (Staff £100, everyone else £50). Coupon codes are case-insensitive and
     * may be padded; a blank coupon counts as none.
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

        $percent += $this->couponPercent($coupon, $tier);

        $discount = (int) round($subtotal * $percent / 100);
        $cap = $tier === CustomerTier::Staff ? 10000 : 5000;

        return min($discount, $cap);
    }

    private function couponPercent(?string $coupon, CustomerTier $tier): int
    {
        if ($coupon === null || trim($coupon) === '') {
            return 0;
        }

        return match (strtoupper(trim($coupon))) {
            'WELCOME10' => $tier === CustomerTier::Staff ? 0 : 10,
            'SUMMER' => $this->summerIsOn() ? 15 : 0,
            default => throw new InvalidArgumentException("Unknown coupon: {$coupon}"),
        };
    }

    /**
     * SUMMER runs from the start of 1 June to the end of 31 August 2026, inclusive.
     */
    private function summerIsOn(): bool
    {
        $now = Carbon::now();

        return $now >= new DateTimeImmutable('2026-06-01 00:00:00')
            && $now < new DateTimeImmutable('2026-09-01 00:00:00');
    }
}
