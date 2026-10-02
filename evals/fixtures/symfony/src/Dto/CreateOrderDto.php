<?php

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateOrderDto
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Length(max: 20)]
        public readonly string $productId = '',

        #[Assert\Range(min: 1, max: 99)]
        public readonly int $quantity = 0,

        #[Assert\Length(max: 140)]
        public readonly ?string $giftMessage = null,
    ) {
    }
}
