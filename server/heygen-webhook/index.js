/* eslint-disable no-console */
const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const localEnvPath = path.resolve(__dirname, '.env');
const parentEnvPath = path.resolve(__dirname, '..', '.env');

require('dotenv').config({ path: parentEnvPath });
require('dotenv').config({ path: localEnvPath });

const {
  HEYGEN_WEBHOOK_SECRET = '',
  FIREBASE_ADMIN_CREDENTIALS,
  FIREBASE_STORAGE_BUCKET,
} = process.env;

if (!FIREBASE_ADMIN_CREDENTIALS) {
  console.error('[Webhook] FIREBASE_ADMIN_CREDENTIALS environment variable is required.');
  process.exit(1);
}

if (!FIREBASE_STORAGE_BUCKET) {
  console.error('[Webhook] FIREBASE_STORAGE_BUCKET environment variable is required.');
  process.exit(1);
}

let serviceAccount;
try {
  if (FIREBASE_ADMIN_CREDENTIALS.trim().startsWith('{')) {
    serviceAccount = JSON.parse(FIREBASE_ADMIN_CREDENTIALS);
  } else {
    const resolvedPath = path.resolve(__dirname, FIREBASE_ADMIN_CREDENTIALS);
    serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  }
} catch (error) {
  console.error('[Webhook] Failed to parse FIREBASE_ADMIN_CREDENTIALS:', error);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: FIREBASE_STORAGE_BUCKET,
  });
}

const firestore = admin.firestore();
const bucket = admin.storage().bucket();

const app = express();
app.use(
  express.json({
    limit: '5mb',
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  }),
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'heygen-webhook' });
});

app.post('/heygen-webhook', async (req, res) => {
  const start = Date.now();
  try {
    if (HEYGEN_WEBHOOK_SECRET) {
      const signature = req.headers['x-heygen-signature'];
      if (!signature) {
        return res.status(401).json({ error: 'Missing webhook signature header' });
      }

      const expected = crypto.createHmac('sha256', HEYGEN_WEBHOOK_SECRET).update(req.rawBody || Buffer.from(JSON.stringify(req.body))).digest('hex');
      const signatureBuffer = Buffer.from(signature, 'hex');
      const expectedBuffer = Buffer.from(expected, 'hex');

      if (
        signatureBuffer.length !== expectedBuffer.length ||
        !crypto.timingSafeEqual(signatureBuffer, expectedBuffer)
      ) {
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }
    }

    const payload = req.body || {};
    const data = payload.data || payload;
    const videoId =
      data.video_id ||
      data.videoId ||
      payload.video_id ||
      payload.videoId;
    const status = (data.status || payload.status || '').toLowerCase();
    const downloadUrl =
      data.download_url ||
      data.video_url ||
      payload.download_url ||
      payload.video_url;

    if (!videoId) {
      console.warn('[Webhook] Missing video_id in payload', payload);
      return res.status(400).json({ error: 'Missing video_id' });
    }

    console.log(`[Webhook] Received event for video ${videoId} with status ${status || 'unknown'}`);

    const policySnapshot = await firestore
      .collection('policies')
      .where('videoHeygenId', '==', videoId)
      .limit(1)
      .get();

    if (policySnapshot.empty) {
      console.warn(`[Webhook] No policy found for video_id ${videoId}.`);
      return res.status(200).json({ message: 'No matching policy. Ignored.' });
    }

    const policyDoc = policySnapshot.docs[0];
    const policyRef = policyDoc.ref;
    const policyData = policyDoc.data();
    const policyId = policyRef.id;

    if (policyData.videoUrl && policyData.videoStatus === 'completed') {
      console.log(`[Webhook] Policy ${policyId} already completed. Skipping reprocessing.`);
      return res.status(200).json({
        message: 'Video already processed',
        policyId,
        videoUrl: policyData.videoUrl,
      });
    }

    if (!status) {
      await policyRef.update({
        videoStatus: 'processing',
        videoLastPayload: data,
        videoHeygenId: videoId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return res.status(200).json({ message: 'Status updated to processing', policyId });
    }

    if (status === 'failed' || status === 'error') {
      const errorMsg =
        data.error ||
        data.message ||
        payload.error ||
        payload.message ||
        'Unknown HeyGen failure';
      await policyRef.update({
        videoStatus: 'failed',
        videoError: errorMsg,
        videoLastPayload: data,
        videoHeygenId: videoId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.error(`[Webhook] Marked policy ${policyId} as failed: ${errorMsg}`);
      return res.status(200).json({ message: 'Failure recorded', policyId });
    }

    if ((status === 'completed' || status === 'done' || status === 'success') && downloadUrl) {
      console.log(`[Webhook] Downloading video for policy ${policyId} from HeyGen.`);
      const response = await axios.get(downloadUrl, {
        responseType: 'arraybuffer',
        timeout: 1000 * 60 * 5,
      });

      const storagePath = `videos/${policyId}.mp4`;
      const file = bucket.file(storagePath);

      await file.save(response.data, {
        contentType: 'video/mp4',
        resumable: false,
        metadata: {
          cacheControl: 'public,max-age=31536000',
        },
      });

      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: '2500-01-01',
      });

      await policyRef.update({
        videoUrl: signedUrl,
        videoStatus: 'completed',
        videoError: admin.firestore.FieldValue.delete(),
        videoHeygenId: videoId,
        videoStoragePath: storagePath,
        videoCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        videoLastPayload: data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Webhook] Uploaded video for policy ${policyId} to Firebase Storage.`);
      return res.status(200).json({
        message: 'Video stored successfully',
        policyId,
        videoUrl: signedUrl,
      });
    }

    await policyRef.update({
      videoStatus: status,
      videoLastPayload: data,
      videoHeygenId: videoId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[Webhook] Updated status for policy ${policyId} to ${status}.`);
    return res.status(200).json({
      message: 'Status recorded',
      policyId,
      status,
    });
  } catch (error) {
    console.error('[Webhook] Error handling webhook:', error);
    return res.status(500).json({ error: error.message });
  } finally {
    console.log(`[Webhook] Handler completed in ${Date.now() - start}ms`);
  }
});

const port = process.env.WEBHOOK_PORT || process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`[Webhook] HeyGen webhook listener running on port ${port}`);
});


