<?php
namespace App\Observers;
class QuoteObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('quote');
    }
}
