/** KNUST Shuttle Connect — Cloud Functions. */
import { onDocumentWritten, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  FieldValue,
  Timestamp,
  DocumentSnapshot,
  WriteBatch,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

const BOARDING_GRACE_MINUTES = 5;
const BATCH_SIZE = 200;
const EVENT_SCHEMA_VERSION = 2;

// First deployment context. Future deployments replace these identifiers while
// retaining the same event contract.
const DEPLOYMENT_CONTEXT = {
  countryId: "GH",
  cityId: "kumasi",
  networkId: "knust",
  operatorId: "knust-transport",
};

const stopTopic = (stopId: string) => `stop_${stopId}`;

type Intent = {
  journeyId: string | null;
  stopId: string;
  destinationStopId: string;
  createdAt: Timestamp | null;
};

function intentOf(snap: DocumentSnapshot | undefined): Intent | null {
  if (!snap || !snap.exists) return null;
  const data = snap.data();
  const stopId = data?.stopId as string | undefined;
  const destinationStopId = data?.destinationStopId as string | undefined;
  if (!stopId || !destinationStopId) return null;
  return {
    journeyId: (data?.journeyId as string | undefined) ?? null,
    stopId,
    destinationStopId,
    createdAt: (data?.createdAt as Timestamp | undefined) ?? null,
  };
}

function activeIntentOf(snap: DocumentSnapshot | undefined): Intent | null {
  if (!snap || !snap.exists) return null;
  const data = snap.data();
  if (data?.endReason || data?.endedAt) return null;
  return intentOf(snap);
}

function sameIntent(a: Intent | null, b: Intent | null): boolean {
  return a?.stopId === b?.stopId &&
    a?.destinationStopId === b?.destinationStopId;
}

function sameJourney(a: Intent | null, b: Intent | null): boolean {
  return sameIntent(a, b) && a?.journeyId === b?.journeyId;
}

function missedBoardingCountOf(snap: DocumentSnapshot | undefined): number {
  if (!snap || !snap.exists) return 0;
  return (snap.data()?.missedBoardingCount as number | undefined) ?? 0;
}

function timestampOf(
  snap: DocumentSnapshot | undefined,
  field: string
): Timestamp | null {
  if (!snap || !snap.exists) return null;
  return (snap.data()?.[field] as Timestamp | undefined) ?? null;
}

function addAnalyticsEvent(
  batch: WriteBatch,
  eventType: string,
  fields: Record<string, unknown>
): void {
  const ref = db.collection("analytics_events").doc();
  batch.set(ref, {
    eventId: ref.id,
    eventType,
    occurredAt: FieldValue.serverTimestamp(),
    schemaVersion: EVENT_SCHEMA_VERSION,
    ...DEPLOYMENT_CONTEXT,
    ...fields,
  });
}

function waitSeconds(intent: Intent, endedAt: Timestamp | null): number | null {
  if (!intent.createdAt || !endedAt) return null;
  return Math.max(
    0,
    Math.round((endedAt.toMillis() - intent.createdAt.toMillis()) / 1000)
  );
}

function terminalEventType(reason: string | null): string {
  switch (reason) {
    case "boarded":
      return "boarded";
    case "cancelled":
      return "waitingCancelled";
    case "geofenceExited":
      return "geofenceExited";
    case "expired":
      return "waitingExpired";
    default:
      return "waitingEnded";
  }
}

function terminalSource(reason: string | null): string {
  switch (reason) {
    case "boarded":
    case "cancelled":
      return "studentConfirmed";
    case "geofenceExited":
    case "expired":
      return "systemObserved";
    default:
      return "unknown";
  }
}

export const onCheckInWritten = onDocumentWritten(
  "checkins/{uid}",
  async (event) => {
    const beforeActive = activeIntentOf(event.data?.before);
    const afterActive = activeIntentOf(event.data?.after);
    const afterAny = intentOf(event.data?.after);
    const terminalReason = event.data?.after.exists
      ? ((event.data?.after.data()?.endReason as string | undefined) ?? null)
      : null;
    const endedAt = timestampOf(event.data?.after, "endedAt");
    const beforeMissed = missedBoardingCountOf(event.data?.before);
    const afterMissed = missedBoardingCountOf(event.data?.after);

    const sameActiveJourney = sameJourney(beforeActive, afterActive);
    const missedIncrease = sameActiveJourney && afterMissed > beforeMissed;
    if (sameActiveJourney && !missedIncrease) return;

    const batch = db.batch();
    let hasWrites = false;

    if (!sameIntent(beforeActive, afterActive)) {
      if (beforeActive) {
        batch.update(db.doc(`stops/${beforeActive.stopId}`), {
          waitingCount: FieldValue.increment(-1),
          [`destinationDemand.${beforeActive.destinationStopId}`]:
            FieldValue.increment(-1),
        });
        hasWrites = true;
      }

      if (afterActive) {
        batch.update(db.doc(`stops/${afterActive.stopId}`), {
          waitingCount: FieldValue.increment(1),
          [`destinationDemand.${afterActive.destinationStopId}`]:
            FieldValue.increment(1),
        });

        const now = new Date();
        const dateKey = now.toISOString().slice(0, 10);
        batch.set(
          db.doc(`analytics_daily/${afterActive.stopId}_${dateKey}`),
          {
            stopId: afterActive.stopId,
            date: dateKey,
            total: FieldValue.increment(1),
            hourly: { [`h${now.getUTCHours()}`]: FieldValue.increment(1) },
          },
          { merge: true }
        );
        hasWrites = true;
      }
    }

    if (beforeActive && !afterActive) {
      const type = terminalEventType(terminalReason);
      addAnalyticsEvent(batch, type, {
        journeyId: beforeActive.journeyId,
        stopId: beforeActive.stopId,
        destinationStopId: beforeActive.destinationStopId,
        endReason: terminalReason ?? "unknown",
        outcomeSource: terminalSource(terminalReason),
        waitSeconds: waitSeconds(beforeActive, endedAt ?? Timestamp.now()),
        missedBoardingCount: beforeMissed,
      });
      hasWrites = true;

      // A terminal update is persisted first so its outcome can be observed by
      // this trigger. Trusted server code then removes it from the live store.
      if (event.data?.after.exists && terminalReason) {
        batch.delete(event.data.after.ref);
      }
    }

    if (!beforeActive && afterActive) {
      addAnalyticsEvent(batch, "waitingStarted", {
        journeyId: afterActive.journeyId,
        stopId: afterActive.stopId,
        destinationStopId: afterActive.destinationStopId,
      });
      hasWrites = true;
    }

    // Replacing an active journey with another active journey should preserve
    // both sides of the history even if the old and new stops are identical.
    if (beforeActive && afterActive && !sameJourney(beforeActive, afterActive)) {
      addAnalyticsEvent(batch, "waitingEnded", {
        journeyId: beforeActive.journeyId,
        stopId: beforeActive.stopId,
        destinationStopId: beforeActive.destinationStopId,
        endReason: "replaced",
        outcomeSource: "systemObserved",
        waitSeconds: waitSeconds(beforeActive, Timestamp.now()),
        missedBoardingCount: beforeMissed,
      });
      addAnalyticsEvent(batch, "waitingStarted", {
        journeyId: afterActive.journeyId,
        stopId: afterActive.stopId,
        destinationStopId: afterActive.destinationStopId,
      });
      hasWrites = true;
    }

    if (missedIncrease && afterAny) {
      addAnalyticsEvent(batch, "boardingMissed", {
        journeyId: afterAny.journeyId,
        stopId: afterAny.stopId,
        destinationStopId: afterAny.destinationStopId,
        reportedCount: afterMissed,
        increment: afterMissed - beforeMissed,
        outcomeSource: "studentConfirmed",
      });
      hasWrites = true;
    }

    if (hasWrites) await batch.commit();
  }
);

export const sweepCheckIns = onSchedule("every 5 minutes", async () => {
  const now = Timestamp.now();

  const expired = await db
    .collection("checkins")
    .where("expiresAt", "<=", now)
    .limit(BATCH_SIZE)
    .get();
  if (!expired.empty) {
    const batch = db.batch();
    let marked = 0;
    expired.docs.forEach((doc) => {
      if (doc.data().endReason || doc.data().endedAt) return;
      batch.update(doc.ref, {
        endReason: "expired",
        endedAt: now,
        updatedAt: now,
      });
      marked++;
    });
    if (marked > 0) await batch.commit();
    logger.info(`Marked ${marked} stale check-ins as expired`);
  }

  // Arrival is a service observation, not proof that every waiting passenger
  // boarded. Keep unresolved passengers active; only clear the stop's transient
  // arrival state after the grace window.
  const graceCutoff = Timestamp.fromMillis(
    now.toMillis() - BOARDING_GRACE_MINUTES * 60 * 1000
  );
  const arrivedStops = await db
    .collection("stops")
    .where("arrivedAt", "<=", graceCutoff)
    .get();

  if (!arrivedStops.empty) {
    const batch = db.batch();
    arrivedStops.docs.forEach((stopDoc) => {
      batch.update(stopDoc.ref, {
        enRouteBy: null,
        enRouteAt: null,
        arrivedAt: null,
      });
    });
    await batch.commit();
    logger.info(`Cleared arrival state for ${arrivedStops.size} stops`);
  }
});

export const onStopStatusChanged = onDocumentUpdated(
  "stops/{stopId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const stopId = event.params.stopId;
    const stopName = (after.name as string) ?? stopId;

    const enRouteStarted = !before.enRouteBy && after.enRouteBy && !after.arrivedAt;
    const justArrived = !before.arrivedAt && after.arrivedAt;
    if (!enRouteStarted && !justArrived) return;

    const driverUid = (after.enRouteBy as string | undefined) ?? null;
    let service: Record<string, unknown> = {};
    if (driverUid) {
      const shuttle = await db.doc(`shuttles/${driverUid}`).get();
      if (shuttle.exists) {
        const data = shuttle.data() ?? {};
        service = {
          routeId: (data.routeId as string | undefined) ?? null,
          serviceTripId: (data.tripId as string | undefined) ?? null,
          routeDirection: (data.routeDirection as string | undefined) ?? null,
          servingDestinationStopId:
            (data.servingDestinationStopId as string | undefined) ?? null,
          currentStopSequence:
            (data.currentStopSequence as number | undefined) ?? null,
        };
      }
    }

    const batch = db.batch();

    if (enRouteStarted) {
      addAnalyticsEvent(batch, "shuttleEnRoute", {
        vehicleId: driverUid,
        stopId,
        waitingCount: (after.waitingCount as number | undefined) ?? 0,
        ...service,
      });
    }

    if (justArrived) {
      const tripRef = db.collection("trips").doc();
      batch.set(tripRef, {
        stopId,
        stopName,
        driverUid,
        enRouteAt: after.enRouteAt ?? null,
        arrivedAt: after.arrivedAt,
        waitingAtArrival: (after.waitingCount as number | undefined) ?? 0,
        createdAt: FieldValue.serverTimestamp(),
        ...service,
      });
      addAnalyticsEvent(batch, "shuttleArrived", {
        tripId: tripRef.id,
        vehicleId: driverUid,
        stopId,
        waitingAtArrival: (after.waitingCount as number | undefined) ?? 0,
        ...service,
      });
    }

    try {
      await batch.commit();
    } catch (err) {
      logger.warn(`transport event write failed for ${stopId}`, err as Error);
    }

    const message = justArrived
      ? {
          title: `Shuttle arrived at ${stopName}`,
          body: "Did you board? Tap ‘I boarded’. If the shuttle was full, report ‘Couldn’t board’ and you’ll remain in the queue.",
        }
      : {
          title: "Shuttle on the way 🚌",
          body: `A shuttle is heading to ${stopName} now.`,
        };

    try {
      await getMessaging().send({
        topic: stopTopic(stopId),
        notification: message,
        android: { priority: "high" as const },
      });
    } catch (err) {
      logger.warn(`FCM send failed for ${stopId}`, err as Error);
    }
  }
);

export const recountWaiting = onSchedule("every day 03:00", async () => {
  const [stops, checkins] = await Promise.all([
    db.collection("stops").get(),
    db.collection("checkins").get(),
  ]);

  const totals = new Map<string, number>();
  const destinationCounts = new Map<string, Map<string, number>>();

  checkins.docs.forEach((doc) => {
    const data = doc.data();
    if (data.endReason || data.endedAt) return;
    const stopId = data.stopId as string | undefined;
    const destinationStopId = data.destinationStopId as string | undefined;
    if (!stopId || !destinationStopId) return;

    totals.set(stopId, (totals.get(stopId) ?? 0) + 1);
    const byDestination = destinationCounts.get(stopId) ?? new Map<string, number>();
    byDestination.set(
      destinationStopId,
      (byDestination.get(destinationStopId) ?? 0) + 1
    );
    destinationCounts.set(stopId, byDestination);
  });

  const batch = db.batch();
  stops.docs.forEach((stopDoc) => {
    const byDestination = destinationCounts.get(stopDoc.id) ??
      new Map<string, number>();
    batch.update(stopDoc.ref, {
      waitingCount: totals.get(stopDoc.id) ?? 0,
      destinationDemand: Object.fromEntries(byDestination.entries()),
    });
  });
  await batch.commit();
  logger.info("Nightly total and destination-demand recount complete");
});
