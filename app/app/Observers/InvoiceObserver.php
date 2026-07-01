<?php
namespace App\Observers;
class InvoiceObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('invoice');
    }
}
