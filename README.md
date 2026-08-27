# KNUST Shuttle Connect

A cross-platform Flutter/Firebase shuttle-demand and transport-intelligence app for KNUST, Kumasi. Students check in at a bus stop with **“I'm Waiting Here”**; drivers see live aggregate demand and can route shuttles toward the busiest stops.

## Current capabilities

- **Student:** KNUST email or phone-OTP authentication, nearest-stop detection, GPS-verified check-in, automatic expiry/geofence exit, live waiting count, anonymous shuttle map and ETA.
- **Driver:** demand-ranked stop list, en-route/arrived workflow, opt-in live shuttle location sharing and demand map.
- **Admin:** stop management and daily/peak-hour demand analytics.
- **Backend:** Firebase Auth, Firestore, Cloud Functions and FCM notifications.
- **Privacy:** drivers see aggregate demand, not student identities or stored student locations.

## Phase 4 — ETA intelligence

Phase 4 is in progress. The original straight-line ETA has been upgraded to a transparent statistical baseline that:

- adjusts crow-flies distance toward approximate road distance;
- blends recent GPS speed with a fallback campus-speed prior;
- discounts stale or implausible speed observations;
- applies a provisional peak-period adjustment;
- returns uncertainty ranges and confidence levels.

These are benchmark assumptions, not measured KNUST transport parameters. The next step is ordered route/stop modelling so the system can determine whether a shuttle is actually approaching a stop and use route-segment distances. See [`docs/PHASE4_ETA_BASELINE.md`](docs/PHASE4_ETA_BASELINE.md).

## Tech stack

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Firebase Cloud Functions (TypeScript)
- Google Maps Flutter
- Geolocator
- Provider

## Run locally

### Prerequisites

- Flutter SDK 3.27+
- Node.js 20+
- Firebase CLI
- FlutterFire CLI

The repository contains application source but not generated Android/iOS platform folders. On first checkout:

```bash
flutter create --org gh.edu.knust --project-name knust_shuttle_connect .
flutter pub get
```

Then configure your Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
npm --prefix functions install
firebase use <your-project-id>
firebase deploy --only firestore:rules,functions
```

Google Maps API keys and Android/iOS location/notification permissions are also required for full device functionality.

Run the app with:

```bash
flutter run
```

## Quality checks

```bash
flutter analyze
flutter test
npm --prefix functions install
npm --prefix functions run typecheck
```

GitHub Actions runs these checks automatically on pushes and pull requests.

## Data integrity

Waiting counts are not client-writable. Students create/delete their own `checkins/{uid}` documents, and Cloud Functions maintain `stops.waitingCount`. Check-ins expire automatically and a nightly recount repairs any drift.

See:

- [`docs/FIRESTORE_DATA_MODEL.md`](docs/FIRESTORE_DATA_MODEL.md)
- [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md)
- [`docs/PHASE4_ETA_BASELINE.md`](docs/PHASE4_ETA_BASELINE.md)

## Important pre-launch note

The stops in `tool/seed_stops.mjs` use **approximate placeholder coordinates**. Verify every stop, route and geofence radius with the KNUST transport office before a live deployment.
