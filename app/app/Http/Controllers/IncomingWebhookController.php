<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use VentureDrake\LaravelCrm\Models\Lead;
use VentureDrake\LaravelCrm\Models\Person;
use VentureDrake\LaravelCrm\Models\LeadSource;
use VentureDrake\LaravelCrm\Models\LeadStatus;
use VentureDrake\LaravelCrm\Models\Pipeline;
use Illuminate\Support\Str;

class IncomingWebhookController extends Controller
{
    public function receive(Request $request)
    {
        $data = $request->all();

        $person = null;
        if (!empty($data['name']) || !empty($data['email'])) {
            $person = Person::create([
                'external_id'     => Str::uuid(),
                'first_name'      => $data['first_name'] ?? ($data['name'] ?? 'Unknown'),
                'last_name'       => $data['last_name'] ?? '',
                'user_owner_id'   => 1,
                'user_created_id' => 1,
            ]);

            if (!empty($data['email'])) {
                $person->emails()->create([
                    'external_id' => Str::uuid(),
                    'address'     => $data['email'],
                    'primary'     => 1,
                ]);
            }

            if (!empty($data['phone'])) {
                $person->phones()->create([
                    'external_id'     => Str::uuid(),
                    'number'          => $data['phone'],
                    'primary'         => 1,
                    'user_created_id' => 1,
                ]);
            }
        }

        $pipeline = Pipeline::first();
        $status   = LeadStatus::first();
        $source   = LeadSource::first();

        $lead = Lead::create([
            'external_id'       => Str::uuid(),
            'title'             => $data['title'] ?? (($data['name'] ?? 'Unknown') . ' Lead'),
            'description'       => $data['message'] ?? null,
            'person_id'         => $person?->id,
            'lead_status_id'    => $status?->id,
            'lead_source_id'    => $source?->id,
            'pipeline_id'       => $pipeline?->id,
            'pipeline_stage_id' => $pipeline?->pipelineStages()->first()?->id,
            'user_owner_id'     => 1,
            'user_created_id'   => 1,
        ]);

        return response()->json([
            'success' => true,
            'lead_id' => $lead->lead_id,
            'message' => 'Lead created successfully',
        ], 201);
    }
}
