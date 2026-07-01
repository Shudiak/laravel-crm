<div>
    {{-- Header --}}
    <x-mary-header title="Webhooks" subtitle="Manage incoming and outgoing webhook integrations" separator>
        <x-slot:actions>
            <x-mary-input placeholder="Search..." wire:model.live.debounce="search" icon="o-magnifying-glass" clearable />
            <x-mary-button label="Add Webhook" icon="o-plus" wire:click="openCreate" class="btn-primary" />
        </x-slot:actions>
    </x-mary-header>

    {{-- Incoming Endpoints --}}
    <x-mary-card title="Incoming Endpoints" subtitle="Use these URLs to send data into the CRM from external sources" class="mb-6">
        <div class="space-y-3">
            <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                <div>
                    <div class="font-semibold text-sm">Create Lead</div>
                    <div class="text-xs text-base-content/60 mt-1">POST — Accepts: name, first_name, last_name, email, phone, message, title</div>
                </div>
                <div class="flex items-center gap-2">
                    <code class="text-xs bg-base-300 px-3 py-1 rounded font-mono">
                        {{ url('/webhook/incoming') }}
                    </code>
                    <x-mary-button
                        icon="o-clipboard"
                        class="btn-ghost btn-sm"
                        tooltip="Copy URL"
                        x-data
                        @click="navigator.clipboard.writeText('{{ url('/webhook/incoming') }}'); $dispatch('mary-toast', {type: 'success', message: 'URL copied!'})"
                    />
                </div>
            </div>
        </div>

        <div class="mt-4">
            <x-mary-alert title="Example payload" icon="o-code-bracket" class="alert-info">
                <x-slot:description>
                    <pre class="text-xs mt-1">{{ json_encode([
                        'first_name' => 'Juan',
                        'last_name'  => 'Pérez',
                        'email'      => 'juan@example.com',
                        'phone'      => '+573001234567',
                        'message'    => 'Interesado en el producto',
                        'title'      => 'Juan Pérez - Web Form',
                    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                </x-slot:description>
            </x-mary-alert>
        </div>
    </x-mary-card>

    {{-- Outgoing Webhooks --}}
    <x-mary-card title="Outgoing Webhooks" subtitle="Notify external systems when events occur in the CRM">
        @php
            $headers = [
                ['key' => 'name',      'label' => 'Name'],
                ['key' => 'url',       'label' => 'URL'],
                ['key' => 'events',    'label' => 'Events'],
                ['key' => 'is_active', 'label' => 'Active'],
                ['key' => 'actions',   'label' => ''],
            ];
        @endphp

        <x-mary-table :headers="$headers" :rows="$webhooks" striped>
            @scope('cell_name', $webhook)
                <div>
                    <div class="font-semibold">{{ $webhook->name }}</div>
                    @if($webhook->description)
                        <div class="text-xs text-base-content/60">{{ $webhook->description }}</div>
                    @endif
                </div>
            @endscope

            @scope('cell_url', $webhook)
                <span class="text-xs font-mono truncate max-w-xs block">{{ $webhook->url }}</span>
            @endscope

            @scope('cell_events', $webhook)
                <div class="flex flex-wrap gap-1">
                    @foreach($webhook->events as $event)
                        <x-mary-badge :value="$event" class="badge-ghost badge-sm" />
                    @endforeach
                </div>
            @endscope

            @scope('cell_is_active', $webhook)
                <x-mary-toggle wire:click="toggleActive({{ $webhook->id }})" :checked="$webhook->is_active" />
            @endscope

            @scope('actions', $webhook)
                <div class="flex gap-2">
                    <x-mary-button icon="o-pencil" wire:click="openEdit({{ $webhook->id }})" class="btn-ghost btn-sm" tooltip="Edit" />
                    <x-mary-button icon="o-trash" wire:click="delete({{ $webhook->id }})" wire:confirm="Are you sure?" class="btn-ghost btn-sm text-error" tooltip="Delete" />
                </div>
            @endscope
        </x-mary-table>

        {{ $webhooks->links() }}
    </x-mary-card>

    {{-- Modal --}}
    <x-mary-modal wire:model="showModal" title="{{ $editMode ? 'Edit Webhook' : 'New Webhook' }}" separator>
        <div class="space-y-4">
            <x-mary-input label="Name" wire:model="name" placeholder="My webhook" />
            <x-mary-input label="URL" wire:model="url" placeholder="https://example.com/webhook" />
            <x-mary-textarea label="Description" wire:model="description" placeholder="Optional description" rows="2" />

            <div>
                <label class="label"><span class="label-text font-semibold">Events</span></label>
                @foreach($availableEvents as $module => $events)
                    <div class="mb-3">
                        <div class="text-sm font-medium text-base-content/70 mb-1">{{ $module }}</div>
                        <div class="flex flex-wrap gap-2">
                            @foreach($events as $event)
                                <label class="flex items-center gap-1 cursor-pointer">
                                    <input type="checkbox" wire:model="selectedEvents" value="{{ $event }}" class="checkbox checkbox-sm checkbox-primary" />
                                    <span class="text-sm">{{ $event }}</span>
                                </label>
                            @endforeach
                        </div>
                    </div>
                @endforeach
                @error('selectedEvents') <span class="text-error text-xs">{{ $message }}</span> @enderror
            </div>

            <div class="grid grid-cols-2 gap-4">
                <x-mary-input label="Max Retries" wire:model="tries" type="number" min="1" max="10" />
                <x-mary-input label="Timeout (seconds)" wire:model="timeout_in_seconds" type="number" min="5" max="60" />
            </div>

            <x-mary-toggle label="Active" wire:model="is_active" />
        </div>

        <x-slot:actions>
            <x-mary-button label="Cancel" wire:click="$set('showModal', false)" />
            <x-mary-button label="Save" wire:click="save" class="btn-primary" />
        </x-slot:actions>
    </x-mary-modal>
</div>
