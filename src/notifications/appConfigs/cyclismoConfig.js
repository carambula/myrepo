/**
 * Cyclismo Guide Notification Configuration
 * Implementation guide and helpers for Cyclismo-specific notifications
 */

import { CYCLISMO_NOTIFICATION_TYPES } from '../notificationTypes.js';
import {
  createCyclismoMorningNotification,
  createCyclismoRecapNotification,
  createCyclismoStreamStartNotification,
  calculateNextNotificationTime
} from '../notificationScheduler.js';

/**
 * Background job handlers for Cyclismo
 * 
 * These are template functions that should be called by the background job scheduler.
 * Override the API methods with your actual data fetching logic.
 */
export const CyclismoBackgroundJobs = {
  /**
   * Morning race notification job
   * Should run daily at the user's specified time
   * 
   * @param {Function} fetchRacesForToday - Your API function to fetch today's races
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async morningRaces(fetchRacesForToday, sendNotification, settings) {
    if (!settings.enabled) return;

    try {
      const racesData = await fetchRacesForToday();
      
      if (!racesData || racesData.races.length === 0) {
        console.log('No races today, skipping notification');
        return;
      }

      const notification = createCyclismoMorningNotification(racesData);
      
      if (notification) {
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in morning races job:', error);
    }
  },

  /**
   * Recap notification job
   * Should run X hours after the last race of the day
   * 
   * @param {Function} fetchRecapContent - Your API function to fetch podcasts/replays
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   * @param {Object} lastRace - Last race of the day
   */
  async recap(fetchRecapContent, sendNotification, settings, lastRace) {
    if (!settings.enabled) return;

    try {
      const lastRaceEndTime = new Date(lastRace.endTime);
      const recapTime = new Date(
        lastRaceEndTime.getTime() + (settings.hoursAfterLastRace * 60 * 60 * 1000)
      );

      const now = new Date();
      if (now < recapTime) {
        console.log('Too early for recap, waiting...');
        return;
      }

      const recapData = await fetchRecapContent(lastRace);
      const notification = createCyclismoRecapNotification(recapData);
      
      if (notification) {
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in recap job:', error);
    }
  },

  /**
   * Stream start notification job
   * Should run for each race, X minutes before start
   * 
   * @param {Function} fetchUpcomingRaces - Your API function to fetch upcoming races
   * @param {Function} getSavedRaces - Your function to get user's saved races
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async streamStart(fetchUpcomingRaces, getSavedRaces, sendNotification, settings) {
    if (!settings.enabled) return;

    try {
      const upcomingRaces = await fetchUpcomingRaces();
      const savedRaces = settings.onlySavedRaces ? await getSavedRaces() : null;

      const now = new Date();
      const notifyWindow = settings.minutesBefore * 60 * 1000;

      for (const race of upcomingRaces) {
        if (settings.onlySavedRaces && !savedRaces.some(sr => sr.id === race.id)) {
          continue;
        }

        const raceStartTime = new Date(race.startTime);
        const timeDiff = raceStartTime - now;

        if (timeDiff > 0 && timeDiff <= notifyWindow + 60000) {
          const notification = createCyclismoStreamStartNotification(
            race,
            settings.minutesBefore
          );
          await sendNotification(notification);
        }
      }
    } catch (error) {
      console.error('Error in stream start job:', error);
    }
  }
};

/**
 * Schedule setup helper for Cyclismo
 * Returns configuration for setting up platform background tasks
 */
export function getCyclismoScheduleConfig(preferences) {
  const schedules = [];

  if (preferences.morning_races?.enabled) {
    schedules.push({
      id: 'cyclismo.morning_races',
      type: 'daily',
      time: preferences.morning_races.time,
      handler: 'CyclismoBackgroundJobs.morningRaces'
    });
  }

  if (preferences.stream_start?.enabled) {
    schedules.push({
      id: 'cyclismo.stream_start',
      type: 'interval',
      intervalMinutes: 15,
      handler: 'CyclismoBackgroundJobs.streamStart'
    });
  }

  return schedules;
}

/**
 * Web implementation note
 * 
 * For web apps, the BackgroundJobScheduler handles all scheduling automatically.
 * Simply override the API methods above with your actual implementations:
 * 
 * Example:
 * CyclismoBackgroundJobs.fetchRacesForToday = async function() {
 *   const response = await fetch('/api/races/today');
 *   return response.json();
 * };
 * 
 * The scheduler will call these methods at the scheduled times.
 */
