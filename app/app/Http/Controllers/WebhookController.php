<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class WebhookController extends Controller
{
    public function index()
    {
        return view('webhooks.index');
    }
}
