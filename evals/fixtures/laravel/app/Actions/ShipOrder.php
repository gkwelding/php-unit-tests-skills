<?php

namespace App\Actions;

use App\Events\OrderWasShipped;
use App\Jobs\SendReviewRequest;
use App\Mail\OrderShipped;
use App\Models\Order;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use LogicException;

final class ShipOrder
{
    /**
     * Books the shipment with the carrier, records the tracking number, emails the
     * customer and schedules a review request: 3 days after express, 7 after standard.
     */
    public function handle(Order $order): void
    {
        if ($order->shipped_at !== null) {
            throw new LogicException("Order {$order->reference} has already shipped");
        }

        $response = Http::post('https://api.carrier.test/v1/shipments', [
            'reference' => $order->reference,
            'weight_grams' => $order->weight_grams,
            'service' => $order->express ? 'next-day' : 'standard',
        ]);
        $response->throw();

        $order->update([
            'shipped_at' => now(),
            'tracking_number' => $response->json('tracking_number'),
        ]);

        Mail::to($order->customer_email)->send(new OrderShipped($order));
        OrderWasShipped::dispatch($order);
        SendReviewRequest::dispatch($order)->delay(now()->addDays($order->express ? 3 : 7));
    }
}
