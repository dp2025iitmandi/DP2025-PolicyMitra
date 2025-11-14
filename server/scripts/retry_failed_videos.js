/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
require('dotenv').config();

const {
  FIREBASE_ADMIN_CREDENTIALS,
  FIREBASE_STORAGE_BUCKET,
} = process.env;

if (!FIREBASE_ADMIN_CREDENTIALS) {
  console.error('[RetryFailedVideos] FIREBASE_ADMIN_CREDENTIALS env var is required.');
  process.exit(1);
}

let credentials;
try {
  if (FIREBASE_ADMIN_CREDENTIALS.trim().startsWith('{')) {
    credentials = JSON.parse(FIREBASE_ADMIN_CREDENTIALS);
  } else {
    const resolvedPath = path.resolve(FIREBASE_ADMIN_CREDENTIALS);
    credentials = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  }
} catch (error) {
  console.error('[RetryFailedVideos] Unable to parse credentials:', error);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(credentials),
    storageBucket: FIREBASE_STORAGE_BUCKET,
  });
}

const firestore = admin.firestore();

const isDryRun = process.argv.includes('--dry-run');

(async () => {
  try {
    console.log(`[RetryFailedVideos] Starting ${isDryRun ? 'dry-run ' : ''}process...`);
    const snapshot = await firestore
      .collection('policies')
      .where('videoStatus', '==', 'failed')
      .get();

    if (snapshot.empty) {
      console.log('[RetryFailedVideos] No failed policies found.');
      process.exit(0);
    }

    console.log(`[RetryFailedVideos] Found ${snapshot.size} failed policies.`);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const policyId = doc.id;
      console.log(`- Policy ${policyId} (${data.title ?? 'Untitled'}) - Error: ${data.videoError ?? 'n/a'}`);

      if (isDryRun) continue;

      await doc.ref.update({
        videoStatus: 'pending',
        videoError: admin.firestore.FieldValue.delete(),
        videoHeygenId: admin.firestore.FieldValue.delete(),
        videoUrl: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(isDryRun
      ? '[RetryFailedVideos] Dry-run completed. No changes applied.'
      : '[RetryFailedVideos] Failed policies reset. They can now be regenerated.');
    process.exit(0);
  } catch (error) {
    console.error('[RetryFailedVideos] Error:', error);
    process.exit(1);
  }
})();


