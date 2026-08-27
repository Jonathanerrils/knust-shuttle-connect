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
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

const BOARDING_GRACE_MINUTES = 5;
const BATCH_SIZE = 400;

const stopTopic = (stopId: string) => `stop_${stopId}`;

type Intent = {
  stopId: string;
  destinationStopId: string;
};

function intentOf(snap: DocumentSnapshot | undefined): Intent | null {
  if (!snap || !snap.exists) return null;
  const data = snap.data();
  const stopId = data?.stopId as string | undefined;
  const destinationStopId = data?.destinationStopId as string | undefined;
  if (!stopId || !destinationStopId) return null;
  return { stopId, destinationStopId };
}

function sameIntent(a: Intent | null, b: Intent | null): boolean {
  return a?.stopId === b?.stopId &&
    a?.destinationStopId === b?.destinationStopId;
}

export const onCheckInWritten = onDocumentWritten(
  "checkins/{uid}",
  async (event) => {
    const before = intentOf(event.data?.before);
    const after = intentOf(event.data?.after);
    if (sameIntent(before, after)) return;

    const batch = db.batch();

    if (before) {
      batch.update(db.doc(`stops/${before.stopId}`), {
        waitingCount: FieldValue.increment(-1),
        [`destinationDemand.${before.destinationStopId}`]:
          FieldValue.increment(-1),
      });
    }

    if (after) {
      batch.update(db.doc(`stops/${after.stopId}`), {
        waitingCount: FieldValue.increment(1),
        [`destinationDemand.${after.destinationStopId}`]:
          FieldValue.increment(1),
      });

      const now = new Date();
      const dateKey = now.toISOString().slice(0, 10);
      batch.set(
        db.doc(`analytics_daily/${after.stopId}_${dateKey}`),
        {
          stopId: after.stopId,
          date: dateKey,
          total: FieldValue.increment(1),
          hourly: { [`h${now.getUTCHours()}`]: FieldValue.increment(1) },
        },
        { merge: true }
      );
    }

    await batch.commit();
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
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    logger.info(`Expired ${expired.size} stale check-ins`);
  }

  const graceCutoff = Timestamp.fromMillis(
    now.toMillis() - BOARDING_GRACE_MINUTES * 60 * 1000
  );
  const arrivedStops = await db
    .collection("stops")
    .where("arrivedAt", "<=", graceCutoff)
    .get();

  for (const stopDoc of arrivedStops.docs) {
    const arrivedAt = stopDoc.data().arrivedAt as Timestamp;
    const waiting = await db
      .collection("checkins")
      .where("stopId", "==", stopDoc.id)
      .get();
    const batch = db.batch();
    let cleared = 0;
    waiting.docs.forEach((doc) => {
      const createdAt = doc.data().createdAt as Timestamp | undefined;
      if (!createdAt || createdAt.toMillis() <= arrivedAt.toMillis()) {
        batch.delete(doc.ref);
        cleared++;
      }
    });
    batch.update(stopDoc.ref, {
      enRouteBy: null,
      enRouteAt: null,
      arrivedAt: null,
    });
    await batch.commit();
    logger.info(`Arrival decay at ${stopDoc.id}: cleared ${cleared}`);
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

    if (justArrived) {
      try {
        await db.collection("trips").add({
          stopId,
          stopName,
          driverUid: (after.enRouteBy as string | undefined) ?? null,
          enRouteAt: after.enRouteAt ?? null,
          arrivedAt: after.arrivedAt,
          waitingAtArrival: (after.waitingCount as number | undefined) ?? 0,
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logger.warn(`trip log failed for ${stopId}`, err as Error);
      }
    }

    const message = justArrived
      ? {
          title: `Shuttle arrived at ${stopName}`,
          body: "Did you board? Open the app and tap ‘I boarded’ — otherwise you’ll be removed from the queue in 5 minutes.",
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
