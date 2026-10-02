<?php

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Mapping\ClassMetadata;

final class CreateOrderDto
{
    public function __construct(
        public readonly int $quantity,
        public readonly string $productId = '',
        public readonly ?string $giftMessage = null,
    ) {
    }

    public static function loadValidatorMetadata(ClassMetadata $metadata): void
    {
        $metadata->addPropertyConstraints('productId', [new Assert\NotBlank(), new Assert\Length(max: 20)]);
        $metadata->addPropertyConstraint('quantity', new Assert\Range(min: 1, max: 99));
        $metadata->addPropertyConstraint('giftMessage', new Assert\Length(max: 140));
    }
}
