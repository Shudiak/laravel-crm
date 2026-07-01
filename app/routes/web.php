<?php

use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});

require __DIR__.'/auth.php';

// Webhooks
Route::middleware(['auth'])->prefix('crm')->group(function () {
    Route::get('/webhooks', [App\Http\Controllers\WebhookController::class, 'index'])
        ->name('crm.webhooks.index');
});

// Incoming webhook — público, sin autenticación
Route::post('/webhook/incoming', [App\Http\Controllers\IncomingWebhookController::class, 'receive'])
    ->name('webhook.incoming');
