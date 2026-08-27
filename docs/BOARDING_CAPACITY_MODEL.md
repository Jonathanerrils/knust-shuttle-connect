# Boarding Capacity Model

Shuttle Connect does not promise exact available seats. In many real operations passengers may stand, app adoption is incomplete, and the platform cannot safely infer an exact onboard census. The product therefore reports **boarding-space bands with confidence**.

## Capacity concepts

- `seatedCapacity`: physical seats in the vehicle.
- `standingCapacity`: operator-approved standing passengers, if standing is legally/operationally permitted.
- `safeCapacity`: `seatedCapacity + standingCapacity`; this is operator reference data, never inferred from crowding behaviour.
- `trackedOnboardCount`: passengers the platform can associate with the active vehicle/trip from confirmed digital journeys. It is not assumed to equal total occupancy.
- `driverOccupancyBand`: a simple stopped-driver observation.

Unsafe overcrowding must never be used to increase `safeCapacity`.

## Occupancy bands

The live product uses broad states:

- `empty`;
- `light` — plenty of room;
- `moderate` — moderate occupancy;
- `limited` — limited boarding space;
- `full` — full / very limited boarding;
- `unknown`.

The driver interface intentionally avoids requiring exact passenger counting. A driver updates the state only while safely stopped.

## Confidence

A fresh driver report is the strongest MVP live signal:

- <= 5 minutes old: high confidence;
- > 5 and <= 15 minutes: medium confidence;
- older: low confidence.

When no useful driver report exists, `trackedOnboardCount / safeCapacity` can provide a broad fallback band. Because app adoption is not yet measured as complete, that fallback is limited to medium confidence. If neither signal is usable, occupancy remains unknown/low confidence.

## Student display

Students see wording such as:

```text
Compatible shuttle · 6 min
Limited boarding space (medium confidence)
```

They do **not** see claims such as `7 seats left` unless a future certified passenger-counting source can support that precision.

## Capacity shortage ground truth

`boardingMissed` is a direct student-confirmed signal that service arrived but did not satisfy the passenger's demand. The journey stays active and the student remains in the queue.

This enables analysis of:

- missed boardings per stop/route/time;
- repeated missed boardings within one journey;
- missed boardings while a shuttle was reported `full` or `limited`;
- demand remaining after an arrival;
- corridors where one vehicle is routinely insufficient.

## Future occupancy fusion

Later versions may combine:

1. operator-verified safe capacity;
2. fresh driver occupancy band;
3. confirmed boardings associated with a specific vehicle/trip;
4. expected alightings from destination-aware journeys;
5. historical app adoption/calibration;
6. automatic passenger-counting hardware where available.

Every estimate should retain its source and confidence. Raw signals should be preserved so improved models can be rebuilt without rewriting history.
