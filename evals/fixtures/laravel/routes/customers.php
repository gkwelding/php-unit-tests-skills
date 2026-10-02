<?php

use App\Http\Controllers\CustomerController;
use Illuminate\Support\Facades\Route;

Route::post('/customers', [CustomerController::class, 'store'])->middleware('auth');
