<?php
namespace App\Observers;
class OrganizationObserver extends WebhookObserver
{
    public function __construct()
    {
        parent::__construct('organization');
    }
}
