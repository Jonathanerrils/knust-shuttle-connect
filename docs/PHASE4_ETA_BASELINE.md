# Phase 4 — ETA Intelligence Baseline

## Why this phase exists

The original Shuttle Connect ETA was intentionally simple: straight-line distance divided by current shuttle speed, with a ~20 km/h fallback. Phase 4 introduces a transparent, testable ETA baseline before any machine-learning model is added.

## Baseline model

For each shuttle-stop pair:

1. Compute crow-flies distance with the existing geodesic utility.
2. Inflate distance by a road-factor of 1.25 to reflect that campus roads are not straight lines.
3. Validate observed shuttle speed. Values below 2 m/s or above 15 m/s are treated as unreliable.
4. Shrink recent observed speed toward a 5.5 m/s campus prior.
5. Down-weight stale observations and ignore them after three minutes.
6. Apply a 20% congestion penalty during provisional peak periods (07:00–09:00 and 16:00–18:00).
7. Return a point ETA plus a confidence-dependent uncertainty interval.

These are benchmark assumptions, not measured KNUST operating parameters. They should be calibrated once real trip histories are collected.

## Confidence levels

- **High** — plausible speed observation no more than 60 seconds old.
- **Medium** — plausible observation between 61 and 180 seconds old.
- **Low** — no reliable recent observation; the estimator mainly uses the baseline.

## Why not ML yet?

A predictive model is useful only if it beats a defensible baseline on unseen trips. Future data should include route and direction, ordered route segment, timestamp, location, speed, stop being approached and actual arrival time.

## Roadmap

### 4A — completed
- confidence-aware ETA baseline;
- speed shrinkage and stale-reading handling;
- provisional peak-period adjustment;
- uncertainty interval;
- backward-compatible `Shuttle.etaMinutesTo()` API;
- deterministic unit tests.

### 4B — next
- add `Route` and `RouteStop` domain entities;
- encode ordered stop sequences and route direction;
- replace the generic road factor with route-segment distance;
- determine whether a shuttle is actually approaching a requested stop;
- expose ETA range/confidence in the student UI.

### 4C — data collection
- log anonymised route-segment travel times;
- create a reproducible modelling dataset;
- add data-quality checks and missing-GPS diagnostics.

### 4D — model comparison
Compare constant-speed, Phase 4 baseline, segment/hour historical median, regression-style models, and tree-based models using time-aware validation and out-of-sample error.
