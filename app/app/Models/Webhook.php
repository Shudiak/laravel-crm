<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Webhook extends Model
{
    protected $fillable = [
        'name',
        'url',
        'secret',
        'events',
        'is_active',
        'tries',
        'timeout_in_seconds',
        'description',
    ];

    protected $casts = [
        'events'    => 'array',
        'is_active' => 'boolean',
    ];

    // Genera un secret seguro automáticamente al crear
    protected static function booted(): void
    {
        static::creating(function (Webhook $webhook) {
            if (empty($webhook->secret)) {
                $webhook->secret = Str::random(32);
            }
        });
    }

    // Eventos disponibles por módulo
    public static function availableEvents(): array
    {
        return [
            'Leads'         => ['lead.created', 'lead.updated', 'lead.deleted'],
            'Contacts'      => ['contact.created', 'contact.updated', 'contact.deleted'],
            'Organizations' => ['organization.created', 'organization.updated', 'organization.deleted'],
            'Deals'         => ['deal.created', 'deal.updated', 'deal.deleted', 'deal.won', 'deal.lost'],
            'Quotes'        => ['quote.created', 'quote.updated', 'quote.sent'],
            'Orders'        => ['order.created', 'order.updated', 'order.completed'],
            'Invoices'      => ['invoice.created', 'invoice.updated', 'invoice.paid'],
            'Tasks'         => ['task.created', 'task.updated', 'task.completed'],
        ];
    }
}
