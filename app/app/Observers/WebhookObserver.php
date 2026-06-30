<?php

namespace App\Observers;

use App\Models\Webhook;
use Spatie\WebhookServer\WebhookCall;
use Illuminate\Database\Eloquent\Model;

class WebhookObserver
{
    protected string $module;

    public function __construct(string $module)
    {
        $this->module = $module;
    }

    public function created(Model $model): void
    {
        $this->dispatch("{$this->module}.created", $model);
    }

    public function updated(Model $model): void
    {
        $this->dispatch("{$this->module}.updated", $model);
    }

    public function deleted(Model $model): void
    {
        $this->dispatch("{$this->module}.deleted", $model);
    }

    protected function dispatch(string $event, Model $model): void
    {
        $webhooks = Webhook::where('is_active', true)
            ->whereJsonContains('events', $event)
            ->get();

        foreach ($webhooks as $webhook) {
            WebhookCall::create()
                ->url($webhook->url)
                ->payload([
                    'event'      => $event,
                    'model'      => class_basename($model),
                    'id'         => $model->getKey(),
                    'data'       => $model->toArray(),
                    'timestamp'  => now()->toISOString(),
                ])
                ->useSecret($webhook->secret)
                ->maximumTries($webhook->tries)
                ->timeoutInSeconds($webhook->timeout_in_seconds)
                ->dispatch();
        }
    }
}
