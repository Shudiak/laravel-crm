<?php
namespace App\Observers;
class DealObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('deal');
    }
}
