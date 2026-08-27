# Journey Ground Truth and Shuttle Compatibility

This document defines which transport outcomes Shuttle Connect treats as observed fact, which are user-confirmed, and how a shuttle is considered relevant to a passenger journey.

## Why this matters

A large mobility dataset is useful only when the outcome labels are defensible. A shuttle arriving at a stop does **not** prove that every waiting passenger boarded. Likewise, a check-in disappearing should not automatically be labelled a successful journey.

The analytics layer therefore records the source of each outcome and preserves unresolved demand when the evidence does not support a stronger conclusion.

## Waiting lifecycle

Every waiting session receives a random `journeyId` that is independent of the student's Firebase UID.

An active journey contains:

- boarding stop;
- intended destination;
- created/expiry timestamps;
- missed-boarding count;
- no terminal `endReason`.

A journey ends through one of the following verified paths:

| Outcome | Event | Evidence source | Removes from live demand? |
|---|---|---|---|
| Student says they boarded | `boarded` | `studentConfirmed` | Yes |
| Student cancels waiting | `waitingCancelled` | `studentConfirmed` | Yes |
| Device leaves the stop geofence | `geofenceExited` | `systemObserved` | Yes |
| Check-in reaches TTL | `waitingExpired` | `systemObserved` | Yes |
| Active journey is replaced | `waitingEnded` / `replaced` | `systemObserved` | Old journey only |
| Compatible shuttle arrives but student cannot board | `boardingMissed` | `studentConfirmed` | **No** |

`boardingMissed` is intentionally non-terminal. It represents a capacity/service failure while the passenger still wants transport. This is a direct input to unmet-demand and capacity-shortage metrics.

## Arrival is not boarding

A driver marking `Arrived` creates a `shuttleArrived` service event and a stop-service record. It does not remove waiting passengers. The transient arrival state is cleared after the boarding grace period, but unresolved passengers remain in the queue until they board, cancel, leave the geofence, or expire.

This prevents the system from overstating served demand.

## Wait duration

Terminal journey events include `waitSeconds` when the timestamps are available:

```text
waitSeconds = endedAt - createdAt
```

This allows median, P90 and distributional wait-time metrics to be computed from outcome-labelled journeys rather than estimates.

## Compatibility model

### Current operational fallback

Until verified ordered routes are loaded, a driver declares the destination/corridor currently being served. The live shuttle document publishes `servingDestinationStopId`.

For a student travelling to destination `D`:

- shuttle with `servingDestinationStopId == D` → **compatible**;
- shuttle assigned to another destination → **other service**;
- shuttle without an assignment → **assignment unknown**.

Only compatible shuttles are used for the student's compatible ETA and boarding/missed-boarding prompt.

### Route-aware target

The domain already supports:

- `routeId`;
- ordered `RouteStop.sequence`;
- direction;
- `tripId`;
- `currentStopSequence`.

When operator-verified route data is available, compatibility should require all of the following:

1. the shuttle is assigned to the relevant route/trip;
2. the passenger's boarding stop is on that route;
3. the destination is on that route in the valid travel direction;
4. the boarding stop has not already been passed by the current trip;
5. the vehicle is active and its location is fresh.

The current corridor fallback must then be replaced by route-sequence matching rather than retained as a hidden assumption.

## Data-quality rules

- Student UID is not written into `analytics_events`.
- Raw events are server-written only.
- Every event has a schema version and deployment context.
- `outcomeSource` distinguishes user-confirmed from system-observed outcomes.
- Missed boarding does not imply why boarding failed unless a future structured reason is explicitly collected.
- Unverified KNUST routes, capacities and operating assumptions must not be labelled as official data.

## Next ground-truth improvements

The next useful additions are:

- operator-verified vehicle capacity;
- structured missed-boarding reason (`vehicleFull`, accessibility constraint, service refusal, other);
- automatic trip assignment from verified schedules/operations;
- actual boarding/alighting validation where an operator has suitable ticketing or counting infrastructure;
- ETA prediction logging linked to actual arrival events for model evaluation.
