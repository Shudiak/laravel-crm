<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('webhooks', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('url');
            $table->string('secret')->nullable();
            $table->json('events');           // ['lead.created', 'deal.updated', ...]
            $table->boolean('is_active')->default(true);
            $table->integer('tries')->default(3);
            $table->integer('timeout_in_seconds')->default(10);
            $table->string('description')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('webhooks');
    }
};
