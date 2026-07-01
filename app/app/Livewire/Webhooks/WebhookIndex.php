<?php

namespace App\Livewire\Webhooks;

use App\Models\Webhook;
use Livewire\Component;
use Livewire\WithPagination;
use Mary\Traits\Toast;

class WebhookIndex extends Component
{
    use WithPagination, Toast;

    public bool $showModal = false;
    public bool $editMode = false;

    public ?int $webhookId = null;
    public string $name = '';
    public string $url = '';
    public string $description = '';
    public array $selectedEvents = [];
    public bool $is_active = true;
    public int $tries = 3;
    public int $timeout_in_seconds = 10;

    public string $search = '';

    protected function rules(): array
    {
        return [
            'name'               => 'required|string|max:255',
            'url'                => 'required|url|max:500',
            'description'        => 'nullable|string|max:500',
            'selectedEvents'     => 'required|array|min:1',
            'is_active'          => 'boolean',
            'tries'              => 'integer|min:1|max:10',
            'timeout_in_seconds' => 'integer|min:5|max:60',
        ];
    }

    public function openCreate(): void
    {
        $this->reset(['webhookId', 'name', 'url', 'description', 'selectedEvents', 'tries', 'timeout_in_seconds']);
        $this->is_active = true;
        $this->tries = 3;
        $this->timeout_in_seconds = 10;
        $this->editMode = false;
        $this->showModal = true;
    }

    public function openEdit(int $id): void
    {
        $webhook = Webhook::findOrFail($id);
        $this->webhookId           = $webhook->id;
        $this->name                = $webhook->name;
        $this->url                 = $webhook->url;
        $this->description         = $webhook->description ?? '';
        $this->selectedEvents      = $webhook->events;
        $this->is_active           = $webhook->is_active;
        $this->tries               = $webhook->tries;
        $this->timeout_in_seconds  = $webhook->timeout_in_seconds;
        $this->editMode = true;
        $this->showModal = true;
    }

    public function save(): void
    {
        $this->validate();

        $data = [
            'name'               => $this->name,
            'url'                => $this->url,
            'description'        => $this->description,
            'events'             => $this->selectedEvents,
            'is_active'          => $this->is_active,
            'tries'              => $this->tries,
            'timeout_in_seconds' => $this->timeout_in_seconds,
        ];

        if ($this->editMode) {
            Webhook::findOrFail($this->webhookId)->update($data);
            $this->success('Webhook updated successfully.');
        } else {
            Webhook::create($data);
            $this->success('Webhook created successfully.');
        }

        $this->showModal = false;
        $this->reset(['webhookId', 'name', 'url', 'description', 'selectedEvents']);
    }

    public function toggleActive(int $id): void
    {
        $webhook = Webhook::findOrFail($id);
        $webhook->update(['is_active' => ! $webhook->is_active]);
        $this->success($webhook->is_active ? 'Webhook enabled.' : 'Webhook disabled.');
    }

    public function delete(int $id): void
    {
        Webhook::findOrFail($id)->delete();
        $this->success('Webhook deleted.');
    }

    public function render()
    {
        $webhooks = Webhook::query()
            ->when($this->search, fn($q) => $q->where('name', 'like', "%{$this->search}%")
                ->orWhere('url', 'like', "%{$this->search}%"))
            ->latest()
            ->paginate(10);

        return view('livewire.webhooks.webhook-index', [
            'webhooks'       => $webhooks,
            'availableEvents' => Webhook::availableEvents(),
        ]);
    }
}
