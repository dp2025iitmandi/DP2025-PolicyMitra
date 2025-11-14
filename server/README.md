# HeyGen Video Backend Server

Backend server for securely handling HeyGen API video generation requests.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file (copy from `.env.example`):
```bash
cp .env.example .env
```

3. Add your HeyGen API key to `.env`:
```
HEYGEN_API_KEY=sk_V2_hgu_k5NtqKSR5OV_2hYTCpr4P4bg3uYPFSEVsDqxbuCtpPyp
HEYGEN_CALLBACK_URL=http://localhost:3000/heygen-webhook
GEMINI_API_KEY=AIzaSyBiuYd8f1QGCVxJWuKa89lwrfLXxBIGXTw
PORT=3000
```

4. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## API Endpoints

### POST /api/generateVideo
Generate a video using HeyGen API.

**Request Body:**
```json
{
  "title": "Video Title",
  "caption": "Video Caption",
  "avatar_id": "avatar_id_here",
  "voice_id": "voice_id_here",
  "input_text": "Script text for the video"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "video_id": "video_id_here",
    "status": "processing",
    ...
  }
}
```

### GET /api/videoStatus/:videoId
Check the status of a video generation.

**Response:**
```json
{
  "success": true,
  "data": {
    "video_id": "video_id_here",
    "status": "completed",
    "download_url": "https://...",
    ...
  }
}
```

### GET /health
Health check endpoint.

## Environment Variables

- `HEYGEN_API_KEY` - Your HeyGen API key (required)
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (development/production)

