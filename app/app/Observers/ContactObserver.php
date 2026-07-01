<?php
namespace App\Observers;
class ContactObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('contact');
    }
}
