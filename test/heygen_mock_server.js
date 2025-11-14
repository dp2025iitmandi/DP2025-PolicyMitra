/* eslint-disable no-console */
const express = require('express');

const app = express();
const PORT = process.env.MOCK_PORT || 5050;

app.use(express.json());

const mockResponse = {
  video_id: 'test123',
  status: 'completed',
  video_url: 'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4',
};

app.post('/api/generateVideo', (req, res) => {
  console.log('[HeyGen Mock] Received generateVideo request', req.body);
  res.json({
    success: true,
    data: mockResponse,
  });
});

app.get('/api/videoStatus/:videoId', (req, res) => {
  console.log(`[HeyGen Mock] Returning status for video ${req.params.videoId}`);
  res.json({
    success: true,
    data: mockResponse,
  });
});

app.listen(PORT, () => {
  console.log(`[HeyGen Mock] Mock server running on port ${PORT}`);
});


