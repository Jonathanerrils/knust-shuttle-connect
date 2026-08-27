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

function stopIdOf(snap: DocumentSnapshot | undefined): string | null {
  if (!snap || !snap.exists) return null;
  return (snap.data()?.stopId as string | undefined) ?? null;
}

export const onCheckInWritten = onDocumentWritten(
  "checkins/{uid}",
  async (event) => {
    const beforeStop = stopIdOf(event.data?.before);
    const afterStop = stopIdOf(event.data?.after);
    if (beforeStop === afterStop) return;

    const batch = db.batch();
    if (beforeStop) {
      batch.set(
        db.doc(`stops/${beforeStop}`),
        { waitingCount: FieldValue.increment(-1) },
        { merge: true }
      );
    }
    if (afterStop) {
      batch.set(
        db.doc(`stops/${afterStop}`),
        { waitingCount: FieldValue.increment(1) },
        { merge: true }
      );
      const now = new Date();
      const dateKey = now.toISOString().slice(0, 10);
      batch.set(
        db.doc(`analytics_daily/${afterStop}_${dateKey}`),
        {
          stopId: afterStop,
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

  const counts = new Map<string, number>();
  checkins.docs.forEach((doc) => {
    const stopId = doc.data().stopId as string | undefined;
    if (stopId) counts.set(stopId, (counts.get(stopId) ?? 0) + 1);
  });

  const batch = db.batch();
  stops.docs.forEach((stopDoc) => {
    const actual = counts.get(stopDoc.id) ?? 0;
    if ((stopDoc.data().waitingCount ?? 0) !== actual) {
      batch.update(stopDoc.ref, { waitingCount: actual });
    }
  });
  await batch.commit();
  logger.info("Nightly recount complete");
});
