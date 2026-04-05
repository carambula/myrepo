/**
 * Concrete Job Handlers
 * Actual implementations for background notification jobs
 */

import {
  createCyclismoMorningNotification,
  createCyclismoRecapNotification,
  createCyclismoStreamStartNotification,
  createMorningQueueNotification,
  createPriorityContentNotification,
  createNewEpisodesNotification
} from './notificationScheduler.js';

/**
 * Cyclismo Job Handlers
 */
export const CyclismoJobHandlers = {
  /**
   * Morning races notification handler
   */
  async morning_races(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running Cyclismo morning races job...');
    
    try {
      const racesData = await this.fetchRacesForToday();
      
      if (!racesData || !racesData.races || racesData.races.length === 0) {
        console.log('No races today, skipping notification');
        return;
      }
      
      const notification = createCyclismoMorningNotification(racesData);
      
      if (notification) {
        await notificationService.send(notification);
        console.log('Sent morning races notification');
      }
    } catch (error) {
      console.error('Error in morning races job:', error);
    }
  },
  
  /**
   * Recap notification handler
   */
  async recap(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running Cyclismo recap job...');
    
    try {
      const lastRace = await this.getLastRaceOfDay();
      
      if (!lastRace) {
        console.log('No races today, skipping recap');
        return;
      }
      
      const lastRaceEndTime = new Date(lastRace.endTime);
      const recapTime = new Date(
        lastRaceEndTime.getTime() + (settings.hoursAfterLastRace * 60 * 60 * 1000)
      );
      
      const now = new Date();
      if (now < recapTime) {
        console.log('Too early for recap, waiting...');
        return;
      }
      
      const recapData = await this.fetchRecapContent(lastRace);
      const notification = createCyclismoRecapNotification(recapData);
      
      if (notification) {
        await notificationService.send(notification);
        console.log('Sent recap notification');
      }
    } catch (error) {
      console.error('Error in recap job:', error);
    }
  },
  
  /**
   * Stream start notification handler
   */
  async stream_start(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running Cyclismo stream start job...');
    
    try {
      const upcomingRaces = await this.fetchUpcomingRaces();
      const savedRaces = settings.onlySavedRaces ? await this.getSavedRaces() : null;
      
      const now = new Date();
      const notifyWindow = settings.minutesBefore * 60 * 1000;
      
      for (const race of upcomingRaces) {
        if (settings.onlySavedRaces && !savedRaces?.some(sr => sr.id === race.id)) {
          continue;
        }
        
        const raceStartTime = new Date(race.startTime);
        const timeDiff = raceStartTime - now;
        
        const alreadyNotified = await this.wasRaceNotified(race.id);
        
        if (timeDiff > 0 && timeDiff <= notifyWindow && !alreadyNotified) {
          const notification = createCyclismoStreamStartNotification(
            race,
            settings.minutesBefore
          );
          
          await notificationService.send(notification);
          await this.markRaceAsNotified(race.id);
          console.log(`Sent stream start notification for race: ${race.name}`);
        }
      }
    } catch (error) {
      console.error('Error in stream start job:', error);
    }
  },
  
  /**
   * API methods (to be implemented by consuming app)
   */
  async fetchRacesForToday() {
    console.warn('fetchRacesForToday not implemented, using mock data');
    return {
      races: [
        { id: '1', name: 'Stage 5', time: '14:00', streamUrl: 'https://...' }
      ],
      streamers: ['NBC Sports', 'Eurosport']
    };
  },
  
  async getLastRaceOfDay() {
    console.warn('getLastRaceOfDay not implemented');
    return null;
  },
  
  async fetchRecapContent(lastRace) {
    console.warn('fetchRecapContent not implemented, using mock data');
    return {
      podcasts: [{ title: 'Stage Recap' }],
      replays: [{ title: 'Full Stage' }]
    };
  },
  
  async fetchUpcomingRaces() {
    console.warn('fetchUpcomingRaces not implemented');
    return [];
  },
  
  async getSavedRaces() {
    console.warn('getSavedRaces not implemented');
    return [];
  },
  
  async wasRaceNotified(raceId) {
    const key = `cyclismo-notified-${raceId}`;
    return localStorage.getItem(key) === 'true';
  },
  
  async markRaceAsNotified(raceId) {
    const key = `cyclismo-notified-${raceId}`;
    localStorage.setItem(key, 'true');
  }
};

/**
 * Podlink Job Handlers
 */
export const PodlinkJobHandlers = {
  /**
   * Morning queue notification handler
   */
  async morning_queue(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running Podlink morning queue job...');
    
    try {
      await this.updatePodcastQueue();
      
      const queueData = await this.getQueueData();
      
      if (settings.useAppleIntelligence && queueData.newItems?.length > 0) {
        queueData.aiSummary = await this.generateAISummary(queueData.newItems);
      }
      
      const notification = createMorningQueueNotification(
        queueData,
        settings.useAppleIntelligence
      );
      
      if (notification) {
        await notificationService.send(notification);
        console.log('Sent morning queue notification');
      }
    } catch (error) {
      console.error('Error in morning queue job:', error);
    }
  },
  
  /**
   * Priority podcasts notification handler
   */
  async priority_podcasts(settings, notificationService) {
    if (!settings.enabled || !settings.priorityPodcastIds?.length) return;
    
    console.log('Running Podlink priority podcasts job...');
    
    try {
      const newEpisodes = await this.checkPriorityPodcasts(settings.priorityPodcastIds);
      
      for (const episode of newEpisodes) {
        const alreadyNotified = await this.wasEpisodeNotified(episode.id);
        
        if (!alreadyNotified) {
          const notification = createPriorityContentNotification(episode, 'podcast');
          await notificationService.send(notification);
          await this.markEpisodeAsNotified(episode.id);
          console.log(`Sent priority podcast notification: ${episode.title}`);
        }
      }
    } catch (error) {
      console.error('Error in priority podcasts job:', error);
    }
  },
  
  /**
   * API methods
   */
  async updatePodcastQueue() {
    console.warn('updatePodcastQueue not implemented');
  },
  
  async getQueueData() {
    console.warn('getQueueData not implemented, using mock data');
    return {
      newItems: [
        { title: 'Episode 42', podcastName: 'Tech Talk' }
      ],
      queue: []
    };
  },
  
  async generateAISummary(episodes) {
    console.warn('generateAISummary not implemented, using simple summary');
    return `You have ${episodes.length} new episode${episodes.length > 1 ? 's' : ''} in your queue`;
  },
  
  async checkPriorityPodcasts(podcastIds) {
    console.warn('checkPriorityPodcasts not implemented');
    return [];
  },
  
  async wasEpisodeNotified(episodeId) {
    const key = `podlink-notified-${episodeId}`;
    return localStorage.getItem(key) === 'true';
  },
  
  async markEpisodeAsNotified(episodeId) {
    const key = `podlink-notified-${episodeId}`;
    localStorage.setItem(key, 'true');
  }
};

/**
 * WatchedIt Job Handlers
 */
export const WatcheditJobHandlers = {
  /**
   * New episodes notification handler
   */
  async new_episodes(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running WatchedIt new episodes job...');
    
    try {
      const newEpisodes = await this.checkForNewEpisodes();
      
      if (!newEpisodes || newEpisodes.length === 0) {
        console.log('No new episodes, skipping notification');
        return;
      }
      
      const notification = createNewEpisodesNotification(newEpisodes);
      
      if (notification) {
        await notificationService.send(notification);
        await this.markEpisodesAsNotified(newEpisodes.map(ep => ep.id));
        console.log('Sent new episodes notification');
      }
    } catch (error) {
      console.error('Error in new episodes job:', error);
    }
  },
  
  /**
   * API methods
   */
  async checkForNewEpisodes() {
    console.warn('checkForNewEpisodes not implemented, using mock data');
    return [
      { id: '1', title: 'New Episode', publishDate: new Date().toISOString() }
    ];
  },
  
  async markEpisodesAsNotified(episodeIds) {
    episodeIds.forEach(id => {
      const key = `watchedit-notified-${id}`;
      localStorage.setItem(key, 'true');
    });
  }
};

/**
 * Yourtube Job Handlers
 */
export const YourtubeJobHandlers = {
  /**
   * Morning queue notification handler
   */
  async morning_queue(settings, notificationService) {
    if (!settings.enabled) return;
    
    console.log('Running Yourtube morning queue job...');
    
    try {
      await this.updateVideoQueue();
      
      const queueData = await this.getQueueData();
      
      if (settings.useAppleIntelligence && queueData.newItems?.length > 0) {
        queueData.aiSummary = await this.generateAISummary(queueData.newItems);
      }
      
      const notification = createMorningQueueNotification(
        queueData,
        settings.useAppleIntelligence
      );
      
      if (notification) {
        await notificationService.send(notification);
        console.log('Sent morning queue notification');
      }
    } catch (error) {
      console.error('Error in morning queue job:', error);
    }
  },
  
  /**
   * Priority channels notification handler
   */
  async priority_channels(settings, notificationService) {
    if (!settings.enabled || !settings.priorityChannelIds?.length) return;
    
    console.log('Running Yourtube priority channels job...');
    
    try {
      const newVideos = await this.checkPriorityChannels(settings.priorityChannelIds);
      
      for (const video of newVideos) {
        const alreadyNotified = await this.wasVideoNotified(video.id);
        
        if (!alreadyNotified) {
          const notification = createPriorityContentNotification(video, 'video');
          await notificationService.send(notification);
          await this.markVideoAsNotified(video.id);
          console.log(`Sent priority channel notification: ${video.title}`);
        }
      }
    } catch (error) {
      console.error('Error in priority channels job:', error);
    }
  },
  
  /**
   * API methods
   */
  async updateVideoQueue() {
    console.warn('updateVideoQueue not implemented');
  },
  
  async getQueueData() {
    console.warn('getQueueData not implemented, using mock data');
    return {
      newItems: [
        { title: 'New Video', channelName: 'Tech Channel' }
      ],
      queue: []
    };
  },
  
  async generateAISummary(videos) {
    console.warn('generateAISummary not implemented, using simple summary');
    return `You have ${videos.length} new video${videos.length > 1 ? 's' : ''} in your queue`;
  },
  
  async checkPriorityChannels(channelIds) {
    console.warn('checkPriorityChannels not implemented');
    return [];
  },
  
  async wasVideoNotified(videoId) {
    const key = `yourtube-notified-${videoId}`;
    return localStorage.getItem(key) === 'true';
  },
  
  async markVideoAsNotified(videoId) {
    const key = `yourtube-notified-${videoId}`;
    localStorage.setItem(key, 'true');
  }
};

/**
 * Get job handlers for an app
 */
export function getJobHandlers(appId) {
  switch (appId) {
    case 'cyclismo':
      return CyclismoJobHandlers;
    case 'podlink':
      return PodlinkJobHandlers;
    case 'watchedit':
      return WatcheditJobHandlers;
    case 'yourtube':
      return YourtubeJobHandlers;
    default:
      return {};
  }
}
