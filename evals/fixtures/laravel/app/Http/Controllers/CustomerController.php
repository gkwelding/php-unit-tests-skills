<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCustomerRequest;
use Illuminate\Http\JsonResponse;

final class CustomerController extends Controller
{
    public function store(StoreCustomerRequest $request): JsonResponse
    {
        $data = $request->validated();

        return response()->json([
            'name' => $data['name'],
            'email' => strtolower($data['email']),
            'newsletter' => $request->boolean('newsletter'),
        ], 201);
    }
}
