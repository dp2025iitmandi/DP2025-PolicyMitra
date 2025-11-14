const admin = require('firebase-admin');
const fs = require('fs');

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
    
    console.log('✅ Policy added with ID:', policyData.id);
    return policyData.id;
  } catch (error) {
    console.error('❌ Error adding policy to database:', error);
    throw error;
  }
}

// Main function to add Swachh Bharat Mission policy
async function addSwachhBharatPolicy() {
  try {
    const policyData = {
      id: Date.now().toString(),
      title: 'Swachh Bharat Mission',
      description: 'Swachh Bharat Mission (SBM) is a country-wide campaign initiated by the Government of India in 2014 to eliminate open defecation and improve solid waste management. The mission aims to make India clean and open defecation free by October 2, 2019, as a tribute to Mahatma Gandhi on his 150th birth anniversary.',
      category: 'Social Welfare',
      link: 'https://swachhbharatmission.gov.in/',
      content: `Swachh Bharat Mission (SBM) is a comprehensive sanitation program launched by the Government of India on October 2, 2014, on the 150th birth anniversary of Mahatma Gandhi.

**Objectives:**
- Eliminate open defecation in India
- Eradicate manual scavenging
- Generate awareness about sanitation and its linkage with public health
- Create a people's movement for sanitation
- Build capacity at the local level

**Key Components:**
1. **Swachh Bharat Mission (Gramin)**: Focuses on rural sanitation
2. **Swachh Bharat Mission (Urban)**: Focuses on urban sanitation

**Benefits:**
- Improved public health and hygiene
- Reduction in waterborne diseases
- Better quality of life
- Environmental protection
- Women empowerment through safe sanitation facilities

**Eligibility:**
- All citizens of India
- Rural and urban households
- Public institutions
- Community organizations

**Documents Required:**
- Aadhar Card
- Proof of residence
- Bank account details
- Photographs of existing facilities (if applicable)`,
      documentsRequired: 'Aadhar Card, Proof of residence, Bank account details, Photographs of existing facilities (if applicable)',
      videoUrl: null, // Will be generated later
      scriptText: null
    };

    console.log('📝 Adding Swachh Bharat Mission policy to database...');
    const policyId = await addPolicyToDatabase(policyData);

    console.log('\n✅ Success! Policy added:');
    console.log('Policy ID:', policyId);
    console.log('Title:', policyData.title);
    console.log('Category:', policyData.category);
    console.log('\n📹 Next step: Generate video for this policy through the Flutter app');
    console.log('   - Open the app');
    console.log('   - Find "Swachh Bharat Mission" policy');
    console.log('   - Click "Generate Video" button');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
addSwachhBharatPolicy();

