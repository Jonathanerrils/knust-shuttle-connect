# Firestore Data Model

KNUST Shuttle Connect separates live operational state from durable analytics history. The current core collections are `users`, `stops`, `checkins`, `shuttles`, `trips`, `analytics_daily`, and `analytics_events`, with reference collections for `networks`, `operators`, `routes`, and `vehicles`.

## `users/{uid}`
Stores the Firebase Auth user profile and role (`student`, `driver`, or `admin`). Self-signup is student-only; privileged roles are provisioned administratively.

## `stops/{stopId}`
Stores stop name, coordinates, geofence radius, active status, aggregate demand, and transient shuttle service state.

Important aggregate fields include:

- `waitingCount`: all active waiting sessions at the stop;
- `destinationDemand.{destinationStopId}`: active waiting demand for a specific destination;
- `enRouteBy`, `enRouteAt`, `arrivedAt`: transient service state.

Drivers read these aggregates but never individual student check-ins. Clients cannot directly write demand counters; trusted Cloud Functions maintain and reconcile them.

## `checkins/{studentUid}`
The document ID is the student UID, structurally enforcing one live waiting record per student. The UID is used only for access control and operational state; it is not copied into the raw analytics event stream.

An active document includes:

- `journeyId`: random identifier used to link analytics events without exposing the student UID;
- `stopId`, `stopName`;
- `destinationStopId`, `destinationStopName`;
- `createdAt`, `updatedAt`, `expiresAt`;
- `missedBoardingCount`;
- optional `lastMissedBoardingAt`.

A terminal transition temporarily adds:

- `endReason`: `boarded`, `cancelled`, `geofenceExited`, or server-side `expired`;
- `endedAt`.

The client writes the terminal state first. The Cloud Function observes it, writes the durable outcome event, updates aggregate demand, and then deletes the completed operational record.

A `boardingMissed` report increments `missedBoardingCount` but does **not** end the journey or remove the student from live demand.

## `shuttles/{driverUid}`
Stores opt-in live positions and service assignment for on-duty drivers. Fields can include:

- `onDuty`;
- latitude/longitude;
- heading and speed;
- `updatedAt`;
- `servingDestinationStopId` as the current MVP compatibility fallback;
- optional `routeId`, `tripId`, `routeDirection`, and `currentStopSequence` for verified route-aware operation.

The student's map distinguishes compatible, other-service, and assignment-unknown shuttles. Unassigned vehicles are never silently treated as compatible.

## `trips/{tripId}`
Append-only stop-service log created when a driver marks arrival. It records stop, driver/vehicle, en-route and arrival timestamps, waiting count at arrival, and available route/trip assignment metadata.

A shuttle arrival is service evidence, not proof that all waiting students boarded.

## `analytics_daily/{stopId}_{yyyy-MM-dd}`
Per-stop daily demand summary with total check-in starts and hourly buckets (`h0`–`h23`) used by operational analytics.

## `analytics_events/{eventId}`
Immutable server-written raw event stream intended for future warehouse export and model evaluation.

Common fields:

- `eventId`;
- `eventType`;
- `occurredAt`;
- `schemaVersion`;
- `countryId`, `cityId`, `networkId`, `operatorId`;
- optional `journeyId`, `tripId`, `vehicleId`, `routeId`, `stopId`, `destinationStopId`;
- event-specific ground-truth fields such as `waitSeconds`, `outcomeSource`, and `missedBoardingCount`.

Current outcome/service events include:

- `waitingStarted`;
- `waitingEnded`;
- `waitingCancelled`;
- `waitingExpired`;
- `geofenceExited`;
- `boarded`;
- `boardingMissed`;
- `shuttleEnRoute`;
- `shuttleArrived`.

Clients cannot write this collection. Admin access is read-only through Firestore rules; trusted server code creates the raw records.

## Reference collections

`networks`, `operators`, `routes`, and `vehicles` are intended to hold scalable transport reference data. They are readable in-app when authenticated and writable only by administrators. The model is deliberately generic so another university, city, operator, or country can use the same architecture.

## Demand and outcome integrity

```text
student app -> active checkins/{uid}
                    |
                    v
             onCheckInWritten
               /          \
              v            v
   stops aggregate      analytics_events
   live demand          immutable history

student outcome -> terminal check-in state
                         |
                         v
                  outcome event +
                  aggregate decrement
                         |
                         v
                  server deletes record

boardingMissed -> analytics event only
                  student remains waiting

sweepCheckIns -> marks true TTL expiries
recountWaiting -> nightly reconciliation of active total + destination demand
driver app -> live shuttle/service assignment + stop service state
admin app -> network/reference definitions
```

See `firestore.rules`, `functions/src/index.ts`, and `docs/GROUND_TRUTH_AND_COMPATIBILITY.md` for the enforcement and ground-truth contract.
