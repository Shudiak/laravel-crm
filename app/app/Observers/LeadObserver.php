<?php
namespace App\Observers;
class LeadObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('lead');
    }
}
