# Firestore Data Model

KNUST Shuttle Connect uses six collections: `users`, `stops`, `checkins`, `shuttles`, `trips`, and `analytics_daily`.

## `users/{uid}`
Stores the Firebase Auth user profile and role (`student`, `driver`, or `admin`). Self-signup is student-only; privileged roles are provisioned administratively.

## `stops/{stopId}`
Stores stop name, coordinates, geofence radius, active status, aggregate `waitingCount`, and shuttle en-route/arrival fields. Clients cannot write `waitingCount`; Cloud Functions maintain it.

## `checkins/{studentUid}`
The document ID is the student UID, structurally enforcing one active check-in per student. Each document stores the stop, created/updated timestamps, and expiry time. Students can only access their own check-in; drivers never see student identities.

## `shuttles/{driverUid}`
Stores opt-in live positions for on-duty drivers: duty status, latitude/longitude, heading, speed and update timestamp.

## `trips/{tripId}`
Append-only service log created when a driver marks arrival. It records the stop, driver/shuttle, en-route and arrival timestamps, and waiting count at arrival.

## `analytics_daily/{stopId}_{yyyy-MM-dd}`
Per-stop daily demand summary with total check-ins and hourly buckets (`h0`–`h23`) used by the admin analytics view.

## Count integrity

```text
student app -> checkins/{uid}
                  |
                  v
          onCheckInWritten
                  |
                  v
        stops.waitingCount

sweepCheckIns -> removes expired/decayed check-ins
recountWaiting -> nightly count reconciliation
driver app -> en-route fields only
admin app -> stop definitions only
```

See `firestore.rules` and `functions/src/index.ts` for the enforcement implementation.
