const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// HeyGen API Configuration
const HEYGEN_API_KEY = process.env.HEYGEN_API_KEY;
const HEYGEN_BASE_URL = 'https://api.heygen.com/v2';
const HEYGEN_CALLBACK_URL = process.env.HEYGEN_CALLBACK_URL;

if (!HEYGEN_API_KEY) {
  console.error('ERROR: HEYGEN_API_KEY is not set in environment variables!');
  console.error('Please create a .env file with HEYGEN_API_KEY=your_key');
  process.exit(1);
}

if (!HEYGEN_CALLBACK_URL) {
  console.error('ERROR: HEYGEN_CALLBACK_URL is not set in environment variables!');
  console.error('Please create a .env file with HEYGEN_CALLBACK_URL=https://your-domain/heygen-webhook');
  process.exit(1);
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'HeyGen Video Backend is running' });
});

// Generate video endpoint
// POST /api/generateVideo
// Body: { title, caption, avatar_id, voice_id, input_text }
app.post('/api/generateVideo', async (req, res) => {
  try {
    const { title, caption, avatar_id, voice_id, input_text } = req.body;

    // Validate required fields
    if (!input_text) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['input_text'],
        received: { input_text: !!input_text }
      });
    }

    // If avatar_id or voice_id not provided, fetch available ones
    let finalAvatarId = avatar_id;
    let finalVoiceId = voice_id;

    if (!finalAvatarId) {
      try {
        const avatarsResponse = await axios.get(`${HEYGEN_BASE_URL}/avatars`, {
          headers: { 'X-Api-Key': HEYGEN_API_KEY }
        });
        const avatars = avatarsResponse.data.data || avatarsResponse.data || [];
        if (avatars.length > 0) {
          finalAvatarId = avatars[0].avatar_id || avatars[0].id;
          console.log(`[${new Date().toISOString()}] Using default avatar: ${finalAvatarId}`);
        } else {
          return res.status(400).json({
            error: 'No avatars available',
            message: 'Could not fetch avatars from HeyGen API'
          });
        }
      } catch (error) {
        console.error('Error fetching avatars:', error.message);
        return res.status(500).json({
          error: 'Failed to fetch avatars',
          message: error.message
        });
      }
    }

    if (!finalVoiceId) {
      try {
        const voicesResponse = await axios.get(`${HEYGEN_BASE_URL}/voices`, {
          headers: { 'X-Api-Key': HEYGEN_API_KEY }
        });
        const voices = voicesResponse.data.data || voicesResponse.data || [];
        if (voices.length > 0) {
          finalVoiceId = voices[0].voice_id || voices[0].id;
          console.log(`[${new Date().toISOString()}] Using default voice: ${finalVoiceId}`);
        } else {
          return res.status(400).json({
            error: 'No voices available',
            message: 'Could not fetch voices from HeyGen API'
          });
        }
      } catch (error) {
        console.error('Error fetching voices:', error.message);
        return res.status(500).json({
          error: 'Failed to fetch voices',
          message: error.message
        });
      }
    }

    console.log(`[${new Date().toISOString()}] Generating video with HeyGen API...`);
    console.log(`Title: ${title || 'N/A'}`);
    console.log(`Avatar ID: ${finalAvatarId}`);
    console.log(`Voice ID: ${finalVoiceId}`);
    console.log(`Input text length: ${input_text.length} characters`);

    // Prepare request body according to HeyGen API v2 spec
    // Format: https://docs.heygen.com/reference/create-an-avatar-video-v2
    const requestBody = {
      video_inputs: [
        {
          character: {
            type: "avatar",
            avatar_id: finalAvatarId,
            avatar_style: "normal"
          },
          voice: {
            type: "text",
            input_text: input_text,
            voice_id: finalVoiceId,
            speed: 1.0
          }
        }
      ],
      dimension: {
        width: 1280,
        height: 720
      },
      // Enable subtitles for Hindi content
      subtitle: {
        enabled: true,
        language: "hi" // Hindi language code
      },
      callback_url: HEYGEN_CALLBACK_URL
    };
    
    // Add title if provided
    if (title) {
      requestBody.title = title;
    }

    // Call HeyGen API
    const response = await axios.post(
      `${HEYGEN_BASE_URL}/video/generate`,
      requestBody,
      {
        headers: {
          'X-Api-Key': HEYGEN_API_KEY,
          'Content-Type': 'application/json'
        },
        timeout: 60000 // 60 second timeout
      }
    );

    console.log(`[${new Date().toISOString()}] HeyGen API response status: ${response.status}`);
    console.log(`[${new Date().toISOString()}] Response data:`, JSON.stringify(response.data, null, 2));

    // Return the response from HeyGen API
    res.json({
      success: true,
      data: response.data
    });

  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error generating video:`, error.message);
    
    if (error.response) {
      // HeyGen API returned an error response
      console.error('HeyGen API Error Response:', error.response.status, error.response.data);
      return res.status(error.response.status || 500).json({
        error: 'HeyGen API error',
        message: error.response.data?.message || error.message,
        status: error.response.status,
        details: error.response.data
      });
    } else if (error.request) {
      // Request was made but no response received
      console.error('No response from HeyGen API');
      return res.status(503).json({
        error: 'Service unavailable',
        message: 'HeyGen API did not respond. Please try again later.'
      });
    } else {
      // Error setting up the request
      return res.status(500).json({
        error: 'Internal server error',
        message: error.message
      });
    }
  }
});

// Check video status endpoint
// GET /api/videoStatus/:videoId
app.get('/api/videoStatus/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;

    if (!videoId) {
      return res.status(400).json({
        error: 'Missing video ID'
      });
    }

    console.log(`[${new Date().toISOString()}] Checking video status for ID: ${videoId}`);

    // Call HeyGen API to check video status
    const response = await axios.get(
      `${HEYGEN_BASE_URL}/video/${videoId}`,
      {
        headers: {
          'X-Api-Key': HEYGEN_API_KEY
        },
        timeout: 30000 // 30 second timeout
      }
    );

    console.log(`[${new Date().toISOString()}] Video status response:`, response.status);
    console.log(`[${new Date().toISOString()}] Video data:`, JSON.stringify(response.data, null, 2));

    res.json({
      success: true,
      data: response.data
    });

  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error checking video status:`, error.message);
    
    if (error.response) {
      return res.status(error.response.status || 500).json({
        error: 'HeyGen API error',
        message: error.response.data?.message || error.message,
        status: error.response.status,
        details: error.response.data
      });
    } else if (error.request) {
      return res.status(503).json({
        error: 'Service unavailable',
        message: 'HeyGen API did not respond. Please try again later.'
      });
    } else {
      return res.status(500).json({
        error: 'Internal server error',
        message: error.message
      });
    }
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(`[${new Date().toISOString()}] Unhandled error:`, err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] HeyGen Video Backend server running on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Health check: http://localhost:${PORT}/health`);
  console.log(`[${new Date().toISOString()}] Generate video: POST http://localhost:${PORT}/api/generateVideo`);
  console.log(`[${new Date().toISOString()}] Check status: GET http://localhost:${PORT}/api/videoStatus/:videoId`);
});

