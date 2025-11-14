const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
// You'll need to download your service account key from Firebase Console
let serviceAccount;
try {
  serviceAccount = require('./service-account-key.json');
} catch (error) {
  console.error('❌ Service account key not found!');
  console.log('📋 Please follow these steps:');
  console.log('1. Go to Firebase Console: https://console.firebase.google.com/');
  console.log('2. Select your project: dp2025-2290f');
  console.log('3. Go to Project Settings (gear icon) → Service accounts');
  console.log('4. Click "Generate new private key"');
  console.log('5. Download the JSON file and save it as "service-account-key.json" in this folder');
  console.log('6. Run the script again: npm start');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'dp2025-2290f.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Function to upload video to Firebase Storage
async function uploadVideoToStorage(videoPath, fileName) {
  try {
    const file = bucket.file(`videos/${fileName}`);
    await bucket.upload(videoPath, {
      destination: file,
      metadata: {
        contentType: 'video/mp4', // Adjust based on your video format
      },
    });
    
    // Make the file publicly accessible
    await file.makePublic();
    
    // Get the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
    console.log('Video uploaded successfully:', publicUrl);
    return publicUrl;
  } catch (error) {
    console.error('Error uploading video:', error);
    throw error;
  }
}

// Function to add policy to Firestore
async function addPolicyToDatabase(policyData) {
  try {
    const docRef = await db.collection('policies').doc(policyData.id).set({
      title: policyData.title,
      description: policyData.description,
      category: policyData.category,
      link: policyData.link,
      content: policyData.content,
      videoUrl: policyData.videoUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('Policy added with ID:', policyData.id);
    return policyData.id;
  } catch (error) {
    console.error('Error adding policy to database:', error);
    throw error;
  }
}

// Main function to add policy with video
async function addPolicyWithVideo() {
  try {
    // Configuration - Update these values
    const config = {
      // Video file path (update this to your video file path)
      videoPath: 'C:\\flutter_project\\testvideo.mp4',
      
      // Policy details
      policy: {
        title: 'test policy',
        description: 'This is a sample policy description',
        category: 'Agriculture', // Choose from: Agriculture, Education, Healthcare, Housing, Social Welfare
        link: 'https://www.myscheme.gov.in/schemes/pmuy', // Your policy URL
        content: 'Detailed policy content goes here...',
      }
    };

    // Check if video file exists
    if (!fs.existsSync(config.videoPath)) {
      console.error('❌ Video file not found:', config.videoPath);
      console.log('📋 Please follow these steps:');
      console.log('1. Place your video file in the project directory');
      console.log('2. Update the videoPath in the script (line ~45)');
      console.log('3. Example: videoPath: "./my-video.mp4"');
      console.log('4. Run the script again: npm start');
      return;
    }

    // Generate unique filename
    const timestamp = Date.now();
    const fileName = `${timestamp}_${path.basename(config.videoPath)}`;

    console.log('Uploading video...');
    const videoUrl = await uploadVideoToStorage(config.videoPath, fileName);

    console.log('Adding policy to database...');
    const policyData = {
      id: Date.now().toString(),
      ...config.policy,
      videoUrl: videoUrl
    };

    const policyId = await addPolicyToDatabase(policyData);

    console.log('✅ Success! Policy added with video:');
    console.log('Policy ID:', policyId);
    console.log('Video URL:', videoUrl);
    console.log('Category:', config.policy.category);

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Run the script
addPolicyWithVideo();
