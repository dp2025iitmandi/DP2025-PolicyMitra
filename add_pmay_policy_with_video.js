const admin = require('firebase-admin');
const axios = require('axios');
require('dotenv').config({ path: './server/.env' });

// Initialize Firebase Admin SDK
let serviceAccount;
try {
  serviceAccount = require('./service-account-key.json');
} catch (error) {
  console.error('❌ Service account key not found!');
  console.log('📋 Please ensure service-account-key.json exists in the project root');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'dp2025-2290f.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// HeyGen API Configuration
const HEYGEN_API_KEY = process.env.HEYGEN_API_KEY;
const HEYGEN_BASE_URL = 'https://api.heygen.com/v2';
const BACKEND_URL = 'http://localhost:3000';

if (!HEYGEN_API_KEY) {
  console.error('❌ HEYGEN_API_KEY not found in server/.env');
  process.exit(1);
}

// Function to generate script using Gemini API
async function generateScriptWithGemini(policy) {
  try {
    const GEMINI_API_KEY = 'AIzaSyBiuYd8f1QGCVxJWuKa89lwrfLXxBIGXTw';
    const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    
    const schemeData = `
SCHEME NAME: ${policy.title}

DESCRIPTION: ${policy.description}

POLICY DETAILS: ${policy.content}

DOCUMENTS REQUIRED: ${policy.documentsRequired || 'Not specified'}
`;

    const prompt = `You are an expert government-scheme video scriptwriter for AI avatar awareness videos in India.

Input will be: SCHEME NAME, DESCRIPTION, POLICY DETAILS, DOCUMENTS REQUIRED.

Based on this, generate a CLEAN NARRATION SCRIPT in HINDI for an AI avatar video with the following CRITICAL rules:

**LANGUAGE REQUIREMENTS:**
- Script MUST be in HINDI (Devanagari script)
- Use simple, clear Hindi that is easy to understand for all Indian citizens
- Use Indian currency (₹ Rupees) when mentioning amounts
- Reference Indian places, cities, or states when giving examples
- Use Indian names and contexts

**IMPORTANT FORMAT REQUIREMENTS:**
- Output ONLY plain narration text in Hindi - NO scene descriptions, NO brackets, NO "Narration:" labels
- Length: 200-250 words (approximately 90 seconds / 1 minute 30 seconds of speech)
- Write as a continuous, natural narration that flows smoothly
- Tone: professional, optimistic, and inspiring

**CONTENT REQUIREMENTS:**
- Must include: purpose, eligibility, benefits, application process, and required documents
- No questions asked — fill any missing detail with realistic assumptions
- The narration should sound natural for an AI avatar speaking directly to the viewer
- End with an inspiring closing line like: "[SCHEME NAME] के माध्यम से हर नागरिक को सशक्त बनाना।"

**OUTPUT FORMAT:**
Output ONLY the Hindi narration text, nothing else. No scene descriptions, no formatting, just the plain Hindi text that the avatar will speak.

${schemeData}`;

    const response = await axios.post(GEMINI_URL, {
      contents: [{
        parts: [{ text: prompt }]
      }],
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 10000
      }
    });

    if (response.data.candidates && response.data.candidates[0]) {
      return response.data.candidates[0].content.parts[0].text.trim();
    }
    return null;
  } catch (error) {
    console.error('Error generating script with Gemini:', error.message);
    return null;
  }
}

// Function to generate video using HeyGen API
async function generateVideoWithHeyGen(script, title) {
  try {
    // First, get available avatars
    console.log('📋 Fetching available avatars...');
    const avatarsResponse = await axios.get(`${HEYGEN_BASE_URL}/avatars`, {
      headers: { 'X-Api-Key': HEYGEN_API_KEY }
    });
    
    console.log('Avatars response type:', typeof avatarsResponse.data);
    console.log('Avatars response keys:', Object.keys(avatarsResponse.data || {}));
    console.log('Avatars response.data type:', typeof avatarsResponse.data?.data);
    console.log('Avatars response.data is array:', Array.isArray(avatarsResponse.data?.data));
    
    // Try different response structures
    let avatars = [];
    if (avatarsResponse.data && avatarsResponse.data.data && avatarsResponse.data.data.avatars && Array.isArray(avatarsResponse.data.data.avatars)) {
      // Structure: { data: { data: { avatars: [...] } } }
      avatars = avatarsResponse.data.data.avatars;
      console.log(`✅ Found ${avatars.length} avatars in data.data.avatars`);
    } else if (avatarsResponse.data && avatarsResponse.data.data && Array.isArray(avatarsResponse.data.data)) {
      // Structure: { data: { data: [...] } }
      avatars = avatarsResponse.data.data;
      console.log(`✅ Found ${avatars.length} avatars in data.data`);
    } else if (avatarsResponse.data && avatarsResponse.data.avatars && Array.isArray(avatarsResponse.data.avatars)) {
      // Structure: { data: { avatars: [...] } }
      avatars = avatarsResponse.data.avatars;
      console.log(`✅ Found ${avatars.length} avatars in data.avatars`);
    } else if (avatarsResponse.data && Array.isArray(avatarsResponse.data)) {
      // Structure: { data: [...] }
      avatars = avatarsResponse.data;
      console.log(`✅ Found ${avatars.length} avatars in data (direct array)`);
    } else {
      console.error('❌ Could not parse avatars response');
      console.error('Response structure:', JSON.stringify(avatarsResponse.data, null, 2));
      return null;
    }
    
    if (avatars.length === 0) {
      console.error('❌ No avatars found in parsed array');
      console.error('Response:', JSON.stringify(avatarsResponse.data, null, 2));
      return null;
    }
    
    // Use the first available avatar - HeyGen uses talking_photo_id for avatars
    const firstAvatar = avatars[0];
    if (!firstAvatar) {
      console.error('❌ First avatar is undefined');
      console.error('Avatars array:', avatars);
      return null;
    }
    
    const avatarId = firstAvatar.talking_photo_id || firstAvatar.avatar_id || firstAvatar.id || firstAvatar.avatarId || firstAvatar.avatar;
    
    if (!avatarId) {
      console.error('❌ Could not find avatar_id in response');
      console.error('Avatar object:', JSON.stringify(firstAvatar, null, 2));
      return null;
    }
    
    console.log(`✅ Using avatar: ${avatarId} (${firstAvatar.talking_photo_name || firstAvatar.name || 'Unknown'})`);
    
    // Get available voices
    console.log('📋 Fetching available voices...');
    const voicesResponse = await axios.get(`${HEYGEN_BASE_URL}/voices`, {
      headers: { 'X-Api-Key': HEYGEN_API_KEY }
    });
    
    // Try different response structures
    let voices = [];
    if (voicesResponse.data && voicesResponse.data.data && voicesResponse.data.data.voices && Array.isArray(voicesResponse.data.data.voices)) {
      // Structure: { data: { data: { voices: [...] } } }
      voices = voicesResponse.data.data.voices;
      console.log(`✅ Found ${voices.length} voices in data.data.voices`);
    } else if (voicesResponse.data && voicesResponse.data.data && Array.isArray(voicesResponse.data.data)) {
      // Structure: { data: { data: [...] } }
      voices = voicesResponse.data.data;
      console.log(`✅ Found ${voices.length} voices in data.data`);
    } else if (voicesResponse.data && voicesResponse.data.voices && Array.isArray(voicesResponse.data.voices)) {
      // Structure: { data: { voices: [...] } }
      voices = voicesResponse.data.voices;
      console.log(`✅ Found ${voices.length} voices in data.voices`);
    } else if (voicesResponse.data && Array.isArray(voicesResponse.data)) {
      // Structure: { data: [...] }
      voices = voicesResponse.data;
      console.log(`✅ Found ${voices.length} voices in data (direct array)`);
    } else {
      console.error('❌ Could not parse voices response');
      console.error('Response structure:', JSON.stringify(voicesResponse.data, null, 2));
      return null;
    }
    
    if (voices.length === 0) {
      console.error('❌ No voices found in parsed array');
      console.error('Response:', JSON.stringify(voicesResponse.data, null, 2));
      return null;
    }
    
    // Try to find a Hindi voice first, otherwise use the first available voice
    let selectedVoice = null;
    
    // Look for Hindi voices (check language, name, or description)
    for (const voice of voices) {
      const voiceName = (voice.name || voice.voice_name || '').toLowerCase();
      const voiceLang = (voice.language || voice.lang || '').toLowerCase();
      const voiceDesc = (voice.description || '').toLowerCase();
      
      if (voiceName.includes('hindi') || voiceName.includes('hin') ||
          voiceLang.includes('hindi') || voiceLang.includes('hin') ||
          voiceDesc.includes('hindi') || voiceDesc.includes('hin')) {
        selectedVoice = voice;
        console.log(`✅ Found Hindi voice: ${voiceName || voiceLang || 'Hindi'}`);
        break;
      }
    }
    
    // If no Hindi voice found, use the first available voice
    if (!selectedVoice) {
      selectedVoice = voices[0];
      console.log(`⚠️  No Hindi voice found, using first available voice`);
    }
    
    if (!selectedVoice) {
      console.error('❌ No voice available');
      console.error('Voices array:', voices);
      return null;
    }
    
    const voiceId = selectedVoice.voice_id || selectedVoice.id || selectedVoice.voiceId || selectedVoice.voice;
    
    if (!voiceId) {
      console.error('❌ Could not find voice_id in response');
      console.error('Voice object:', JSON.stringify(selectedVoice, null, 2));
      return null;
    }
    
    console.log(`✅ Using voice: ${voiceId} (${selectedVoice.name || selectedVoice.voice_name || 'Unknown'})`);
    
    // Generate video
    console.log('🎬 Generating video with HeyGen API...');
    const requestBody = {
      video_inputs: [
        {
          character: {
            type: "avatar",
            avatar_id: avatarId,
            avatar_style: "normal"
          },
          voice: {
            type: "text",
            input_text: script,
            voice_id: voiceId,
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
      }
    };
    
    if (title) {
      requestBody.title = title;
    }
    
    const response = await axios.post(
      `${HEYGEN_BASE_URL}/video/generate`,
      requestBody,
      {
        headers: {
          'X-Api-Key': HEYGEN_API_KEY,
          'Content-Type': 'application/json'
        },
        timeout: 60000
      }
    );
    
    if (response.data && response.data.data) {
      const videoId = response.data.data.video_id;
      console.log(`✅ Video generation started. Video ID: ${videoId}`);
      
      // Poll for video completion
      console.log('⏳ Waiting for video to be ready...');
      console.log('   Waiting 30 seconds before first status check (videos take time to process)...');
      await new Promise(resolve => setTimeout(resolve, 30000));
      
      // Increase polling iterations for longer videos (up to 20 minutes = 240 iterations)
      const maxIterations = 240; // 20 minutes total (30s initial + 240 * 5s = 20.5 minutes)
      for (let i = 0; i < maxIterations; i++) {
        if (i > 0) {
          await new Promise(resolve => setTimeout(resolve, 5000));
        }
        
        try {
          const statusResponse = await axios.get(
            `${HEYGEN_BASE_URL}/video/${videoId}`,
            {
              headers: { 'X-Api-Key': HEYGEN_API_KEY },
              timeout: 30000
            }
          );
          
          const videoData = statusResponse.data.data || statusResponse.data;
          const status = videoData.status;
          const downloadUrl = videoData.download_url || videoData.video_url;
          
          console.log(`   Status check ${i + 1}/${maxIterations}: ${status}`);
          
          // Debug: Print full response every 12 checks (every minute)
          if ((i + 1) % 12 === 0 || i === 0) {
            console.log(`   Full response: ${JSON.stringify(statusResponse.data, null, 2).substring(0, 500)}`);
          }
          
          if (status === 'completed' || status === 'done' || status === 'success') {
            if (downloadUrl) {
              console.log(`✅ Video ready! Download URL: ${downloadUrl}`);
              return downloadUrl;
            } else {
              console.log(`⚠️  Status is ${status} but no download_url found`);
              console.log(`   Video data: ${JSON.stringify(videoData, null, 2).substring(0, 500)}`);
            }
          } else if (status === 'failed' || status === 'error') {
            console.error('❌ Video generation failed:', videoData.error || videoData.message);
            return null;
          }
        } catch (error) {
          if (error.response) {
            if (error.response.status === 404) {
              // 404 is normal while video is still processing
              if ((i + 1) % 12 === 0) {
                console.log(`   Video not found (404) - still processing (${i + 1}/${maxIterations})`);
                console.log(`   This is normal - videos can take 5-15 minutes to generate`);
              }
            } else {
              console.log(`   Status check failed: ${error.response.status} (${i + 1}/${maxIterations})`);
              console.log(`   Response: ${JSON.stringify(error.response.data, null, 2).substring(0, 200)}`);
            }
          } else {
            console.log(`   Request error: ${error.message} (${i + 1}/${maxIterations})`);
          }
        }
      }
      
      console.error(`❌ Timeout waiting for video generation (waited ${(30 + maxIterations * 5) / 60} minutes)`);
      console.error('   Video may still be processing. Check HeyGen dashboard or try again later.');
      return null;
    }
    
    return null;
  } catch (error) {
    console.error('Error generating video with HeyGen:', error.response?.data || error.message);
    return null;
  }
}

// Function to download video from URL
async function downloadVideo(videoUrl) {
  try {
    const response = await axios.get(videoUrl, {
      responseType: 'arraybuffer',
      timeout: 300000 // 5 minutes
    });
    
    return Buffer.from(response.data);
  } catch (error) {
    console.error('Error downloading video:', error.message);
    return null;
  }
}

// Function to upload video to Firebase Storage
async function uploadVideoToStorage(videoBuffer, fileName) {
  try {
    const file = bucket.file(`videos/${fileName}`);
    await file.save(videoBuffer, {
      metadata: {
        contentType: 'video/mp4'
      }
    });
    
    await file.makePublic();
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
    console.log('✅ Video uploaded to Firebase Storage:', publicUrl);
    return publicUrl;
  } catch (error) {
    console.error('Error uploading video:', error.message);
    return null;
  }
}

// Function to add policy to Firestore
async function addPolicyToDatabase(policyData) {
  try {
    await db.collection('policies').doc(policyData.id).set({
      title: policyData.title,
      description: policyData.description,
      category: policyData.category,
      link: policyData.link || null,
      content: policyData.content,
      documentsRequired: policyData.documentsRequired || null,
      videoUrl: policyData.videoUrl || null,
      scriptText: policyData.scriptText || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Policy added to database with ID:', policyData.id);
    return policyData.id;
  } catch (error) {
    console.error('Error adding policy to database:', error.message);
    throw error;
  }
}

// Main function
async function addPMAYPolicyWithVideo() {
  try {
    console.log('🚀 Starting PMAY-G policy upload with video generation...\n');
    
    // Policy data
    const policy = {
      id: Date.now().toString(),
      title: 'Pradhan Mantri Awas Yojana - PMAY-G',
      description: 'Pradhan Mantri Awas Yojana - Gramin (PMAY-G) is a flagship housing scheme launched by the Government of India to provide affordable housing to rural households. The scheme aims to build 2.95 crore pucca houses by March 2024 for eligible rural families.',
      category: 'Housing',
      link: 'https://pmaymis.gov.in/',
      content: `Pradhan Mantri Awas Yojana - Gramin (PMAY-G) is a comprehensive housing scheme launched by the Ministry of Rural Development, Government of India.

**Objectives:**
- Provide pucca houses to all eligible rural households
- Ensure housing for all by 2024
- Improve quality of life in rural areas
- Promote sustainable and disaster-resilient housing

**Key Features:**
- Financial assistance of up to ₹1.20 lakh per house in plain areas
- Financial assistance of up to ₹1.30 lakh per house in hilly/difficult areas
- Additional assistance of ₹12,000 for toilet construction
- Convergence with other government schemes like Swachh Bharat Mission

**Benefits:**
- Free housing for eligible beneficiaries
- Financial assistance for construction
- Support for toilet construction
- Convergence with other welfare schemes
- Disaster-resilient housing construction
- Improved quality of life

**Eligibility:**
- Households without pucca houses
- Households living in kutcha or dilapidated houses
- Priority to SC/ST households
- Priority to women-headed households
- Priority to differently-abled persons
- Priority to minorities

**Documents Required:**
- Aadhar Card
- Bank account details
- Income certificate
- Caste certificate (if applicable)
- Disability certificate (if applicable)
- Photographs of existing house
- Land ownership documents`,
      documentsRequired: 'Aadhar Card, Bank account details, Income certificate, Caste certificate (if applicable), Disability certificate (if applicable), Photographs of existing house, Land ownership documents'
    };
    
    console.log('📝 Step 1: Generating script with Gemini...');
    const script = await generateScriptWithGemini(policy);
    
    if (!script || script.trim().length === 0) {
      console.error('❌ Failed to generate script');
      return;
    }
    
    console.log(`✅ Script generated (${script.length} characters)\n`);
    console.log('Script preview:', script.substring(0, 200) + '...\n');
    
    console.log('🎬 Step 2: Generating video with HeyGen API...');
    const heygenVideoUrl = await generateVideoWithHeyGen(script, policy.title);
    
    if (!heygenVideoUrl) {
      console.error('❌ Failed to generate video');
      return;
    }
    
    console.log(`✅ Video generated: ${heygenVideoUrl}\n`);
    
    console.log('📥 Step 3: Downloading video...');
    const videoBuffer = await downloadVideo(heygenVideoUrl);
    
    if (!videoBuffer) {
      console.error('❌ Failed to download video');
      return;
    }
    
    console.log(`✅ Video downloaded (${videoBuffer.length} bytes)\n`);
    
    console.log('☁️ Step 4: Uploading video to Firebase Storage...');
    const fileName = `pmay_${Date.now()}.mp4`;
    const firebaseStorageUrl = await uploadVideoToStorage(videoBuffer, fileName);
    
    if (!firebaseStorageUrl) {
      console.error('❌ Failed to upload video to Firebase Storage');
      return;
    }
    
    console.log('✅ Video uploaded to Firebase Storage\n');
    
    console.log('💾 Step 5: Saving policy to database...');
    const policyData = {
      ...policy,
      videoUrl: firebaseStorageUrl,
      scriptText: script
    };
    
    await addPolicyToDatabase(policyData);
    
    console.log('\n✅ SUCCESS! Policy uploaded with video:');
    console.log('Policy ID:', policyData.id);
    console.log('Title:', policyData.title);
    console.log('Video URL:', firebaseStorageUrl);
    console.log('Category:', policyData.category);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

// Run the script
addPMAYPolicyWithVideo();

