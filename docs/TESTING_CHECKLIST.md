# Testing Checklist

## Automated

Run before merging:

```bash
flutter pub get
flutter analyze
flutter test
npm --prefix functions install
npm --prefix functions run typecheck
```

## Student flow

- Sign in with a KNUST email account.
- Verify phone OTP fallback with Firebase test numbers.
- Confirm nearest-stop detection with location permission enabled.
- Confirm a check-in succeeds inside the configured geofence and fails outside it.
- Confirm a second active check-in replaces the previous one.
- Confirm board/cancel removes the check-in.
- Confirm stale check-ins disappear after expiry.
- Confirm live shuttle ETA appears only when a fresh shuttle position exists.

## Driver flow

- Confirm stops are sorted by waiting count.
- Mark a stop en route, arrived, then done.
- Confirm live location sharing is opt-in and switches off correctly.
- Verify students see only the shuttle position, not driver identity.

## Admin flow

- Add/edit/deactivate a stop.
- Confirm admins cannot accidentally overwrite `waitingCount` through stop editing.
- Verify daily analytics and peak-hour charts with seeded/test data.

## Firebase / security

- Students can read/write only their own check-in.
- Drivers cannot read `checkins`.
- Drivers can update only shuttle status fields on stops.
- Clients cannot write aggregate counts, trip logs, or analytics counters.
- Cloud Functions correctly increment/decrement counts and perform expiry/arrival cleanup.

## Pre-launch

Stop coordinates in `tool/seed_stops.mjs` are placeholders. Verify every stop name, coordinate, route and geofence radius with the KNUST transport office before a live deployment.
