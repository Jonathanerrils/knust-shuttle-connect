import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const EVENT_SCHEMA_VERSION = 3;
const DEPLOYMENT_CONTEXT = {
  countryId: "GH",
  cityId: "kumasi",
  networkId: "knust",
  operatorId: "knust-transport",
};

const ALLOWED_BANDS = new Set(["empty", "light", "moderate", "limited", "full"]);

export const onShuttleOccupancyChanged = onDocumentUpdated(
  "shuttles/{shuttleId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeBand = before.driverOccupancyBand as string | undefined;
    const afterBand = after.driverOccupancyBand as string | undefined;
    const beforeReportedAt = before.occupancyReportedAt;
    const afterReportedAt = after.occupancyReportedAt;

    const bandChanged = beforeBand !== afterBand;
    const reportRefreshed = beforeReportedAt !== afterReportedAt;
    if (!bandChanged && !reportRefreshed) return;
    if (!afterBand || !ALLOWED_BANDS.has(afterBand)) return;

    const ref = db.collection("analytics_events").doc();
    await ref.set({
      eventId: ref.id,
      eventType: "occupancyReported",
      occurredAt: FieldValue.serverTimestamp(),
      schemaVersion: EVENT_SCHEMA_VERSION,
      ...DEPLOYMENT_CONTEXT,
      vehicleId: event.params.shuttleId,
      occupancyBand: afterBand,
      outcomeSource: "driverConfirmed",
      routeId: (after.routeId as string | undefined) ?? null,
      serviceTripId: (after.tripId as string | undefined) ?? null,
      routeDirection: (after.routeDirection as string | undefined) ?? null,
      servingDestinationStopId:
        (after.servingDestinationStopId as string | undefined) ?? null,
      currentStopSequence:
        (after.currentStopSequence as number | undefined) ?? null,
      trackedOnboardCount:
        (after.trackedOnboardCount as number | undefined) ?? null,
      safeCapacity: (after.safeCapacity as number | undefined) ?? null,
    });
  }
);
