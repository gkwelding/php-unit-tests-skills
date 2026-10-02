<?php

namespace App\Controller;

use App\Dto\CreateOrderDto;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Attribute\MapRequestPayload;
use Symfony\Component\Routing\Attribute\Route;

final class OrderController extends AbstractController
{
    #[Route('/api/orders', methods: ['POST'])]
    public function create(#[MapRequestPayload] CreateOrderDto $order): JsonResponse
    {
        return $this->json([
            'productId' => strtoupper($order->productId),
            'quantity' => $order->quantity,
            'isGift' => $order->giftMessage !== null && $order->giftMessage !== '',
        ], 201);
    }
}
