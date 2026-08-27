# Transport KPI Dictionary

This dictionary fixes the meaning of core metrics so dashboards, reports and models do not silently use different definitions.

## Demand

### Waiting demand
Number of active verified check-ins at a stop at a point in time.

### OD demand
Number of verified waiting starts for a boarding-stop/destination-stop pair in a defined period.

### Peak demand
Maximum concurrent waiting demand within the reporting interval.

### Demand growth rate
Change in active waiting demand per unit time. Useful for identifying rapidly worsening queues before they become large.

## Passenger service

### Wait time
`service_outcome_time - waiting_started_time` for journeys with a verified service outcome.

Until boarding ground truth is implemented, do not treat generic `waitingEnded` as successful boarding.

### Median wait time
50th percentile of verified passenger wait times.

### P90 wait time
90th percentile of verified passenger wait times. This is a key reliability measure because averages can hide poor passenger experiences.

### Served demand rate
`verified_boardings / verified_transport_requests`.

Requires outcome classification and must not be calculated from generic check-in deletion.

### Unmet demand rate
`verified_unserved_requests / verified_transport_requests`.

Potential unserved categories include vehicle full, abandonment after excessive wait and service expiry. These categories must remain separate until confidently observed.

## Vehicle and capacity

### Load factor
`observed_or_estimated_occupancy / safe_vehicle_capacity`.

### Capacity shortfall
`max(0, waiting_demand - expected_available_capacity)` for a compatible arriving vehicle or set of vehicles.

### Vehicle utilisation
Share of in-service time or distance during which a vehicle is productively serving the network. The precise denominator must be stated in each report.

## Operations

### Headway
Elapsed time between consecutive compatible vehicles serving the same route/direction at the same reference point.

### Headway variability
Variability of observed headways around the planned or median headway. Report the statistic used, e.g. standard deviation or coefficient of variation.

### Bunching event
Two or more consecutive vehicles whose observed headway falls below a configured fraction of the target headway. The threshold must be network-configurable.

### Stop dwell time
`departure_time - arrival_time` at a stop.

### Segment travel time
Elapsed time from leaving one ordered route stop/segment boundary to reaching the next.

### Route reliability
A declared reliability measure based on arrival/headway adherence. Never publish a percentage without the tolerance definition used.

## ETA quality

### ETA error
`actual_arrival_time - predicted_arrival_time`.

Signed error shows early/late bias.

### ETA absolute error
Absolute value of ETA error.

### MAE
Mean absolute ETA error across the evaluation set.

### Median absolute error
Median absolute ETA error. More robust to a few extreme delays.

### RMSE
Root mean square ETA error. Penalises large misses more heavily.

### Interval coverage
Share of actual arrivals falling inside the predicted ETA interval. Compare observed coverage to the interval's stated confidence level.

All ETA metrics should be grouped by `etaModelVersion` and evaluated on time-separated out-of-sample data.

## Safety and security

### Safety report rate
Number of validated safety/security reports per chosen exposure unit, e.g. 1,000 journeys or 10,000 passenger-minutes.

### Safety hotspot score
A transparent weighted aggregation of validated reports by location and time. Raw report counts should remain available alongside any score.

## Data quality

### GPS freshness
Elapsed time between a vehicle location observation and the time it is consumed.

### GPS completeness
Share of expected in-service telemetry intervals with a usable location observation.

### Outcome completeness
Share of transport requests with a confidently classified end state.

### Route assignment completeness
Share of in-service vehicle observations linked to a verified route, direction and trip where applicable.

## Reporting rule

Every dashboard metric should declare:

- reporting period;
- network/operator scope;
- route/direction scope if applicable;
- numerator and denominator;
- inclusion/exclusion rules;
- whether values are observed, inferred or modelled;
- data-quality coverage.
