const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://tougkqvrnrhtvsobecoa.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvdWdrcXZybnJodHZzb2JlY29hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NDA4NDksImV4cCI6MjA3NjIxNjg0OX0.4pwBgfwrecMrKnrhue8T4JqQBsVltDnqC4_tz8hU65Y';

const supabase = createClient(supabaseUrl, supabaseKey);

async function addPolicyToSupabase() {
  try {
    // Policy data
    const policyData = {
      id: Date.now().toString(),
      title: 'test policy',
      description: 'This is a sample policy description',
      category: 'Agriculture',
      link: 'https://www.myscheme.gov.in/schemes/pmuy',
      content: 'In May 2016, the Ministry of Petroleum and Natural Gas (MOPNG), introduced the \'Pradhan Mantri Ujjwala Yojana\' (PMUY) as a flagship scheme with an objective to make clean cooking fuel such as LPG available to the rural and deprived households which were otherwise using traditional cooking fuels such as firewood, coal, cow-dung cakes etc. Usage of traditional cooking fuels had detrimental impacts on the health of rural women as well as on the environment.\n\nThe scheme was launched on 1st May 2016 in Ballia, Uttar Pradesh by Hon\'ble Prime Minister of India, Shri. Narendra Modi\n\nThe target under the scheme was to release 8 Crore LPG Connections to the deprived households by March 2020.On 7th September 2019, Hon\'ble Prime Minister of India handed over the 8th Crore LPG connection in Aurangabad, Maharashtra.The release of 8 Crore LPG connections under the scheme has also helped in increasing the LPG coverage from 62% on 1st May 2016 to 99.8% as on 1st April 2021.Under the Union Budget for FY 21-22, provision for release of additional 1 Crore LPG connections under the PMUY scheme has been made. In this phase, special facility has been given to migrant families.',
      video_url: 'https://storage.googleapis.com/dp2025-2290f.firebasestorage.app/videos/1761158467070_testvideo.mp4',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    console.log('Adding policy to Supabase...');
    
    const { data, error } = await supabase
      .from('policies')
      .insert([policyData]);

    if (error) {
      console.error('❌ Error adding policy to Supabase:', error);
      return;
    }

    console.log('✅ Success! Policy added to Supabase:');
    console.log('Policy ID:', policyData.id);
    console.log('Title:', policyData.title);
    console.log('Category:', policyData.category);
    console.log('Video URL:', policyData.video_url);

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Run the function
addPolicyToSupabase();
