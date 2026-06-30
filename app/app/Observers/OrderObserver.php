<?php
namespace App\Observers;
class OrderObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('order');
    }
}
