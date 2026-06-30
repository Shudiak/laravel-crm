<?php
namespace App\Observers;
class TaskObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('task');
    }
}
