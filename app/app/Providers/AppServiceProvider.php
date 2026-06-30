<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use VentureDrake\LaravelCrm\Models\Lead;
use VentureDrake\LaravelCrm\Models\Contact;
use VentureDrake\LaravelCrm\Models\Organization;
use VentureDrake\LaravelCrm\Models\Deal;
use VentureDrake\LaravelCrm\Models\Quote;
use VentureDrake\LaravelCrm\Models\Order;
use VentureDrake\LaravelCrm\Models\Invoice;
use VentureDrake\LaravelCrm\Models\Task;
use App\Observers\LeadObserver;
use App\Observers\ContactObserver;
use App\Observers\OrganizationObserver;
use App\Observers\DealObserver;
use App\Observers\QuoteObserver;
use App\Observers\OrderObserver;
use App\Observers\InvoiceObserver;
use App\Observers\TaskObserver;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Lead::observe(LeadObserver::class);
        Contact::observe(ContactObserver::class);
        Organization::observe(OrganizationObserver::class);
        Deal::observe(DealObserver::class);
        Quote::observe(QuoteObserver::class);
        Order::observe(OrderObserver::class);
        Invoice::observe(InvoiceObserver::class);
        Task::observe(TaskObserver::class);
    }
}
