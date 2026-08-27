# Data Platform Foundation

## Goal

Shuttle Connect should be able to grow from one campus deployment into a reusable transport-data platform. The product therefore separates deployment context from transport behaviour and records important actions as immutable, versioned events.

## Deployment hierarchy

Every analytical record can be scoped by:

```text
countryId
cityId
networkId
operatorId
```

The first deployment currently uses:

```text
GH / kumasi / knust / knust-transport
```

These are deployment values, not hard-coded assumptions about the platform's future geography.

## Core reference entities

The domain now contains reusable concepts for:

- transport context;
- route and ordered route stops;
- route direction;
- vehicle and safe capacity;
- transport trip.

Future Firestore reference collections are reserved for `networks`, `operators`, `routes` and `vehicles`, with administrator-only mutation.

## Immutable event stream

Trusted Cloud Functions write `analytics_events/{eventId}`. Clients cannot write to this collection. Each event contains:

- `eventId`;
- `eventType`;
- server timestamp (`occurredAt`);
- `schemaVersion`;
- `countryId`;
- `cityId`;
- `networkId`;
- `operatorId`;
- optional `journeyId`, `tripId`, `vehicleId`, `routeId`, `stopId`, `destinationStopId`;
- event-specific fields.

Initial server-generated event types include:

- `waitingStarted`;
- `waitingEnded`;
- `waitingExpired`;
- `shuttleEnRoute`;
- `shuttleArrived`.

The schema deliberately distinguishes facts from interpretations. A generic check-in deletion is `waitingEnded` until the system has enough evidence to classify the outcome as boarded, cancelled, geofence exit or another reason.

## Privacy design

A check-in receives a random `journeyId` generated independently of the student's Firebase uid. The analytics event stream uses this journey identifier instead of carrying the student's account identifier.

Student GPS continues to be used for geofence verification rather than continuous movement history. Raw student coordinates should not become an analytics field unless a future use case has a clear necessity, legal basis and retention policy.

Drivers never receive individual check-in records. They see only aggregate stop/destination demand.

## Raw, clean and analytics layers

When a warehouse is introduced, preserve three logical layers:

### Raw

Append-only export of original server events. Never rewrite historical raw events.

### Clean

Validated records with:

- standard IDs;
- deduplication;
- timestamp checks;
- impossible-speed filters;
- missing-value flags;
- quality flags;
- schema migrations.

### Analytics

Derived facts such as:

- origin-destination demand;
- wait time;
- headway;
- route-segment travel time;
- passenger service outcomes;
- capacity utilisation;
- ETA prediction error;
- safety hot spots.

## BigQuery target

Firestore remains the operational store. BigQuery should become the analytical warehouse once volume justifies it. `analytics_events` is intentionally shaped so it can be exported as a fact table without embedding mobile UI assumptions.

Recommended warehouse tables:

```text
fact_transport_events
fact_vehicle_positions
fact_eta_predictions
fact_boarding_outcomes
fact_safety_reports

dim_country
dim_city
dim_network
dim_operator
dim_route
dim_stop
dim_vehicle
dim_calendar
```

Partition fact tables by event/service date and cluster where useful by `networkId`, `routeId`, `stopId` and `vehicleId`.

## Data quality

Future telemetry should include explicit quality metadata where relevant:

- GPS accuracy;
- source timestamp vs ingestion timestamp;
- app/schema/model version;
- stale-position flag;
- impossible-jump flag;
- missing-route flag;
- off-route flag;
- inferred vs observed outcome.

The system should prefer a smaller trustworthy dataset over a larger ambiguous one.

## Ground truth roadmap

The next high-value instrumentation work is:

1. classify check-in endings into boarded, cancelled, expired, geofence exit and unresolved;
2. assign verified route/direction/trip IDs to vehicles;
3. record vehicle positions with quality metadata and adaptive sampling;
4. record ETA predictions with model version and confidence;
5. record actual arrival timestamps and pair them with prior predictions;
6. record capacity and occupancy observations;
7. export the immutable event stream into BigQuery;
8. build reproducible OD, reliability and unmet-demand datasets.
