<?php

namespace App\Models;

use Database\Factories\OrderFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Order extends Model
{
    /** @use HasFactory<OrderFactory> */
    use HasFactory;

    protected $fillable = ['reference', 'customer_email', 'weight_grams', 'express', 'shipped_at', 'tracking_number'];

    protected function casts(): array
    {
        return [
            'express' => 'boolean',
            'shipped_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Order $order): void {
            $order->reference ??= 'ORD-'.Str::upper(Str::random(8));
        });
    }
}
