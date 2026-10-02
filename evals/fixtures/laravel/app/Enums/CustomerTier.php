<?php

namespace App\Enums;

enum CustomerTier: string
{
    case Standard = 'standard';
    case Gold = 'gold';
    case Staff = 'staff';
}
