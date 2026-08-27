# Route-Demand, Safety and Sponsored Content — MVP Design

## What this phase adds

This phase changes a check-in from “I am waiting at this stop” to a transport intent:

- boarding stop;
- intended destination;
- check-in expiry and GPS verification as before.

The server converts those private check-ins into aggregate destination demand on each stop. Drivers do not receive student identities or individual travel records.

## Driver demand model

Until verified KNUST route sequences are available, a driver selects the destination/corridor currently being served. Every stop is then ranked and coloured by the number of waiting students whose intended destination matches that selection.

Provisional visual bands:

- 0: grey;
- 1–4: blue (emerging demand);
- 5–9: green (normal demand);
- 10–19: amber (high demand);
- 20+: red (urgent demand).

These are UI assumptions, not claims about KNUST shuttle capacity. They should later be calibrated against verified vehicle capacities and operating data.

## Privacy contract

`checkins/{uid}` remains readable only by the student and admins. Drivers read only aggregate fields on `stops/{stopId}`:

```text
waitingCount: 23
destinationDemand:
  brunei: 14
  ksb: 6
  library: 3
```

The Cloud Function maintains both total and destination-specific counts. A nightly recount rebuilds both aggregates from source check-ins to self-heal drift.

## Safety and security

Student screens contain short contextual safety/security guidance below the transport action. This content is visually distinct from sponsored material and is never labelled as advertising.

Driver screens remain free of advertising. The existing safety warning tells drivers to use the interface only while safely stopped.

## Sponsored content

The student home screen reserves a clearly labelled `Sponsored` card. It currently contains no real advertiser and no tracking SDK.

Future campaign selection should use coarse campus zones and campaign context only. Advertisers should receive aggregate campaign metrics, not student identity, precise location history, selected destination or check-in records.

## Next route-aware step

The current destination selector is a deliberate bridge to verified route intelligence. The next model should add:

- `Route` entity;
- ordered `RouteStop` sequence;
- direction;
- shuttle route assignment;
- approaching/passed-stop logic;
- compatible-shuttle filtering for students;
- route-segment ETA instead of straight-line distance.

Once route data is verified, the driver should no longer manually choose a destination/corridor; their assigned route and direction should determine relevant demand automatically.
