// Firebase Firestore game system analyzer
const fs = require('fs');
const path = require('path');
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');

// Initialize Firebase with your config
const firebaseConfig = {
  // Your web app firebase config goes here
  // This will be read from a config file
};

async function loadConfig() {
  try {
    const configPath = path.join(__dirname, 'firebase_config.json');
    if (fs.existsSync(configPath)) {
      const configData = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(configData);
    } else {
      console.error('Firebase config file not found. Create analysis_scripts/firebase_config.json');
      return null;
    }
  } catch (error) {
    console.error('Error loading config:', error);
    return null;
  }
}

async function analyzeGameSystems() {
  // Load Firebase config
  const config = await loadConfig();
  if (!config) {
    process.exit(1);
  }

  // Initialize Firebase
  const app = initializeApp(config);
  const db = getFirestore(app);
  
  // Map to store game system counts
  const gameSystemCounts = {};
  
  try {
    console.log('Fetching quest cards from Firestore...');
    
    // Get all documents from questCards collection
    const querySnapshot = await getDocs(collection(db, 'questCards'));
    
    console.log(`Found ${querySnapshot.size} quest cards to analyze`);
    
    // Process each document
    querySnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.gameSystem && typeof data.gameSystem === 'string' && data.gameSystem.trim() !== '') {
        const gameSystem = data.gameSystem;
        gameSystemCounts[gameSystem] = (gameSystemCounts[gameSystem] || 0) + 1;
      }
    });
    
    // Generate variation groups
    console.log(`Identified ${Object.keys(gameSystemCounts).length} unique game systems`);
    const variationGroups = generateVariationGroups(gameSystemCounts);
    
    // Create analysis_reports directory if it doesn't exist
    const reportsDir = 'analysis_reports';
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir);
    }
    
    // Save the reports
    fs.writeFileSync(
      `${reportsDir}/game_system_frequency.json`, 
      JSON.stringify(gameSystemCounts, null, 2)
    );
    
    fs.writeFileSync(
      `${reportsDir}/game_system_variations.json`, 
      JSON.stringify(variationGroups, null, 2)
    );
    
    console.log('Reports saved to analysis_reports directory');
    
  } catch (error) {
    console.error('Error analyzing game systems:', error);
  }
}

function generateVariationGroups(gameSystemCounts) {
  const variationGroups = {};
  const processedSystems = new Set();
  
  // For each game system
  Object.entries(gameSystemCounts).forEach(([system, count]) => {
    // Skip if already processed
    if (processedSystems.has(system)) return;
    
    // Mark as processed
    processedSystems.add(system);
    
    // Create new group
    const normalizedSystem = system.toLowerCase();
    const group = [];
    
    // Add this system as primary
    group.push({
      name: system,
      count: count,
      matchType: 'primary'
    });
    
    // Find variations
    Object.entries(gameSystemCounts).forEach(([otherSystem, otherCount]) => {
      if (system !== otherSystem && !processedSystems.has(otherSystem)) {
        const normalizedOther = otherSystem.toLowerCase();
        
        // Check for similar names
        let isSimilar = false;
        
        // Substring match
        if (normalizedSystem.includes(normalizedOther) || 
            normalizedOther.includes(normalizedSystem)) {
          isSimilar = true;
        }
        
        // Acronym check
        const systemWords = normalizedSystem.split(/[\s&]+/);
        const acronym = systemWords
          .map(word => word.length > 0 ? word[0] : '')
          .join('');
        
        if (normalizedOther === acronym) {
          isSimilar = true;
        }
        
        if (isSimilar) {
          group.push({
            name: otherSystem,
            count: otherCount,
            matchType: 'variation'
          });
          processedSystems.add(otherSystem);
        }
      }
    });
    
    // Only add groups with variations
    if (group.length > 1) {
      variationGroups[system] = group;
    }
  });
  
  return variationGroups;
}

analyzeGameSystems().catch(console.error);
