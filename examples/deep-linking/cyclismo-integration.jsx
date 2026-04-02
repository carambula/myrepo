/**
 * Cyclismo Guide Deep Linking Integration Example
 * 
 * This example shows how to integrate the deep linking system into Cyclismo Guide
 * to ensure all cycling race/rider links open in the app with proper deep linking.
 */

import React from 'react';
import {
  DeepLink,
  useOpenLink,
  DeepLinkPreferencesPanel,
  openContent,
  CONTENT_TYPES,
  APP_IDS,
} from '@min-apps/design-system/deepLinking';

/**
 * Example: Race Calendar Component
 * Shows how to make all ProCyclingStats/CyclingNews links open in Cyclismo
 */
function RaceCalendar({ races }) {
  return (
    <div className="race-calendar">
      {races.map(race => (
        <div key={race.id} className="race-item">
          <h3>{race.name}</h3>
          <p>{race.date}</p>
          <span className="race-category">{race.category}</span>
          
          {/* Deep link to ProCyclingStats - will open in Cyclismo */}
          {race.pcsUrl && (
            <DeepLink href={race.pcsUrl}>
              View on ProCyclingStats
            </DeepLink>
          )}
          
          {/* Deep link to CyclingNews */}
          {race.cyclingNewsUrl && (
            <DeepLink href={race.cyclingNewsUrl}>
              View on CyclingNews
            </DeepLink>
          )}
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Rider Profiles
 * Shows how to handle rider deep linking
 */
function RiderProfiles({ riders }) {
  const { open } = useOpenLink();
  
  return (
    <div className="rider-profiles">
      {riders.map(rider => (
        <div 
          key={rider.id} 
          className="rider-item"
          onClick={() => {
            if (rider.pcsUrl) {
              open(rider.pcsUrl);
            }
          }}
        >
          <img src={rider.photo} alt={rider.name} />
          <h4>{rider.name}</h4>
          <p>{rider.team}</p>
          <span>{rider.nationality}</span>
          
          {rider.pcsUrl && (
            <DeepLink href={rider.pcsUrl}>
              Full Stats
            </DeepLink>
          )}
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Team Rosters
 * Shows how to handle team deep linking
 */
function TeamRosters({ teams }) {
  return (
    <div className="team-rosters">
      <h3>Teams</h3>
      {teams.map(team => (
        <div key={team.id} className="team-item">
          <img src={team.logo} alt={team.name} />
          <div className="team-info">
            <h4>{team.name}</h4>
            <span>{team.category}</span>
            
            <DeepLink href={`https://www.procyclingstats.com/team/${team.slug}`}>
              View Full Roster
            </DeepLink>
          </div>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Live Race Tracking
 * Shows how to handle live race updates with deep linking
 */
function LiveRaceTracker({ liveRaces }) {
  const { openContent } = useOpenLink();
  
  const handleOpenRace = async (raceId) => {
    await openContent(CONTENT_TYPES.RACE, raceId, {
      appId: APP_IDS.CYCLISMO,
    });
  };
  
  return (
    <div className="live-race-tracker">
      <h3>Live Now</h3>
      {liveRaces.map(race => (
        <div key={race.id} className="live-race">
          <div className="live-indicator">🔴 LIVE</div>
          <h4>{race.name}</h4>
          <p>Stage {race.currentStage} - {race.kmRemaining} km to go</p>
          <button onClick={() => handleOpenRace(race.id)}>
            Watch Live
          </button>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Race Alerts
 * Shows how to create race alerts with deep linking
 */
function RaceAlerts({ upcomingRaces }) {
  return (
    <div className="race-alerts">
      <h3>Upcoming Race Alerts</h3>
      <p>Get notified when these races start</p>
      
      {upcomingRaces.map(race => (
        <div key={race.id} className="alert-item">
          <div className="race-info">
            <h4>{race.name}</h4>
            <span>{race.startTime}</span>
          </div>
          
          <DeepLink 
            href={`https://www.procyclingstats.com/race/${race.slug}`}
            className="alert-link"
          >
            View Race Details
          </DeepLink>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Share Race Feature
 * Shows how to create shareable race deep links
 */
function ShareRaceButton({ raceId, raceName }) {
  const [copied, setCopied] = React.useState(false);
  
  const handleShare = async () => {
    const { createShareableLink } = await import('@min-apps/design-system/deepLinking');
    
    const link = createShareableLink(CONTENT_TYPES.RACE, raceId);
    
    if (navigator.share) {
      await navigator.share({
        title: raceName,
        text: `Watch ${raceName}`,
        url: link,
      });
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(link);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };
  
  return (
    <button onClick={handleShare}>
      {copied ? 'Link Copied!' : 'Share Race'}
    </button>
  );
}

/**
 * Example: Cyclismo Settings
 * Shows how to add deep linking preferences
 */
function CyclismoSettings() {
  return (
    <div className="settings-page">
      <h1>Settings</h1>
      
      <section>
        <h2>Notifications</h2>
        {/* Other settings */}
      </section>
      
      <section>
        <h2>Deep Linking</h2>
        <DeepLinkPreferencesPanel title="Cycling Preferences" />
        <p className="help-text">
          Choose which app opens when you click cycling links from external 
          sources like ProCyclingStats or CyclingNews.
        </p>
      </section>
    </div>
  );
}

/**
 * Example: Add Race to Favorites
 * Shows how to add races to favorites via URL
 */
function AddRaceToFavorites() {
  const [raceUrl, setRaceUrl] = React.useState('');
  const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
  
  const handleAddToFavorites = () => {
    const parsed = parseExternalUrl(raceUrl);
    
    if (parsed && parsed.contentType === CONTENT_TYPES.RACE) {
      addToFavorites(parsed.extractedId, 'race');
      setRaceUrl('');
    } else {
      alert('Please enter a valid race URL');
    }
  };
  
  return (
    <div className="add-to-favorites">
      <h3>Add to Favorites</h3>
      <input
        type="text"
        value={raceUrl}
        onChange={(e) => setRaceUrl(e.target.value)}
        placeholder="Paste ProCyclingStats or CyclingNews URL"
      />
      <button onClick={handleAddToFavorites}>Add</button>
    </div>
  );
}

/**
 * Example: Stage Results
 * Shows how to handle stage-specific deep linking
 */
function StageResults({ race }) {
  return (
    <div className="stage-results">
      <h3>{race.name} - Stages</h3>
      {race.stages.map(stage => (
        <div key={stage.id} className="stage-item">
          <h4>Stage {stage.number}: {stage.name}</h4>
          <p>{stage.distance} km</p>
          
          <DeepLink 
            href={`https://www.procyclingstats.com/race/${race.slug}/${stage.year}/stage-${stage.number}`}
          >
            View Stage Details
          </DeepLink>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Rider Comments with Links
 * Shows how to handle comments that might contain rider/race links
 */
function RaceComments({ comments }) {
  const { extractAllIdsFromText } = require('@min-apps/design-system/deepLinking');
  
  return (
    <div className="race-comments">
      {comments.map(comment => {
        const ids = extractAllIdsFromText(comment.text);
        
        return (
          <div key={comment.id} className="comment">
            <div className="comment-header">
              <strong>{comment.author}</strong>
              <span>{comment.timestamp}</span>
            </div>
            <p>{comment.text}</p>
            
            {/* Show all referenced races/riders */}
            {ids.length > 0 && (
              <div className="referenced-content">
                <h4>Referenced:</h4>
                {ids.map((item, index) => (
                  <DeepLink key={index} href={item.url}>
                    {item.contentType}
                  </DeepLink>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

/**
 * Example: Race Recaps
 * Shows how to link to race recaps and highlights
 */
function RaceRecaps({ recaps }) {
  return (
    <div className="race-recaps">
      <h3>Recent Race Recaps</h3>
      {recaps.map(recap => (
        <div key={recap.id} className="recap-item">
          <img src={recap.thumbnail} alt={recap.raceName} />
          <div className="recap-info">
            <h4>{recap.raceName}</h4>
            <p>{recap.description}</p>
            
            <DeepLink href={recap.raceUrl}>
              View Full Results
            </DeepLink>
            
            {recap.winnerUrl && (
              <DeepLink href={recap.winnerUrl}>
                Winner: {recap.winnerName}
              </DeepLink>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Notification Handler
 * Shows how to handle deep links from notifications
 */
function handleRaceNotification(notificationData) {
  const { openLink, openContent } = require('@min-apps/design-system/deepLinking');
  
  if (notificationData.raceUrl) {
    openLink(notificationData.raceUrl);
  } else if (notificationData.raceId) {
    openContent(CONTENT_TYPES.RACE, notificationData.raceId, {
      appId: APP_IDS.CYCLISMO,
    });
  }
}

/**
 * Example: Favorite Riders
 * Shows how to manage favorite riders with deep linking
 */
function FavoriteRiders({ favoriteRiders }) {
  const { open } = useOpenLink();
  
  return (
    <div className="favorite-riders">
      <h3>Your Favorite Riders</h3>
      {favoriteRiders.map(rider => (
        <div 
          key={rider.id} 
          className="favorite-rider"
          onClick={() => open(rider.pcsUrl)}
        >
          <img src={rider.photo} alt={rider.name} />
          <div className="rider-info">
            <h4>{rider.name}</h4>
            <p>{rider.team}</p>
            <DeepLink href={rider.pcsUrl}>View Profile</DeepLink>
          </div>
        </div>
      ))}
    </div>
  );
}

/**
 * Example: Grand Tour Tracker
 * Shows how to track Grand Tours with deep linking
 */
function GrandTourTracker({ grandTour }) {
  return (
    <div className="grand-tour-tracker">
      <h2>{grandTour.name}</h2>
      
      <div className="tour-overview">
        <DeepLink href={grandTour.pcsUrl}>
          View Full Tour Details
        </DeepLink>
      </div>
      
      <div className="classification-leaders">
        <h3>Leaders</h3>
        
        <div className="leader-item">
          <span>🟡 General Classification</span>
          <DeepLink href={grandTour.gcLeader.pcsUrl}>
            {grandTour.gcLeader.name}
          </DeepLink>
        </div>
        
        <div className="leader-item">
          <span>🟢 Points Classification</span>
          <DeepLink href={grandTour.pointsLeader.pcsUrl}>
            {grandTour.pointsLeader.name}
          </DeepLink>
        </div>
        
        <div className="leader-item">
          <span>🔴 Mountains Classification</span>
          <DeepLink href={grandTour.mountainsLeader.pcsUrl}>
            {grandTour.mountainsLeader.name}
          </DeepLink>
        </div>
      </div>
    </div>
  );
}

/**
 * Example: Import from UCI Code
 * Shows how to handle UCI rider codes
 */
function ImportRiderByUCI() {
  const [uciCode, setUciCode] = React.useState('');
  
  const handleImport = async () => {
    // This would typically look up the rider by UCI code
    // and find their ProCyclingStats URL
    const riderUrl = await fetchRiderUrlByUCI(uciCode);
    
    if (riderUrl) {
      const { parseExternalUrl } = require('@min-apps/design-system/deepLinking');
      const parsed = parseExternalUrl(riderUrl);
      
      if (parsed) {
        addToFavorites(parsed.extractedId, 'rider');
      }
    }
  };
  
  return (
    <div className="import-uci">
      <h3>Add Rider by UCI Code</h3>
      <input
        type="text"
        value={uciCode}
        onChange={(e) => setUciCode(e.target.value)}
        placeholder="Enter UCI code (e.g., 10007506366)"
      />
      <button onClick={handleImport}>Add Rider</button>
    </div>
  );
}

// Example data
const exampleRaces = [
  {
    id: 'tour-de-france-2026',
    name: 'Tour de France',
    date: 'July 1-23, 2026',
    category: 'Grand Tour',
    pcsUrl: 'https://www.procyclingstats.com/race/tour-de-france/2026',
    cyclingNewsUrl: 'https://www.cyclingnews.com/races/tour-de-france-2026',
  },
];

const exampleRiders = [
  {
    id: 'tadej-pogacar',
    name: 'Tadej Pogačar',
    team: 'UAE Team Emirates',
    nationality: 'Slovenia',
    photo: 'https://example.com/pogacar.jpg',
    pcsUrl: 'https://www.procyclingstats.com/rider/tadej-pogacar',
  },
];

// Placeholder functions
function addToFavorites(id, type) {
  console.log('Adding to favorites:', id, type);
}

async function fetchRiderUrlByUCI(uciCode) {
  // Placeholder
  return '';
}

export {
  RaceCalendar,
  RiderProfiles,
  TeamRosters,
  LiveRaceTracker,
  RaceAlerts,
  ShareRaceButton,
  CyclismoSettings,
  AddRaceToFavorites,
  StageResults,
  RaceComments,
  RaceRecaps,
  handleRaceNotification,
  FavoriteRiders,
  GrandTourTracker,
  ImportRiderByUCI,
  exampleRaces,
  exampleRiders,
};
