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
 * These are template functions that should be called by your platform-specific
 * background job scheduler (iOS BackgroundTasks, Android WorkManager, etc.)
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
 * iOS-specific background task registration
 * Example implementation for Swift integration
 */
export const iOSBackgroundTaskExample = `
// Swift code example for iOS

import BackgroundTasks
import UserNotifications

class CyclismoNotificationManager {
    func registerBackgroundTasks() {
        // Register morning races task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.cyclismo.morning_races",
            using: nil
        ) { task in
            self.handleMorningRacesTask(task: task as! BGAppRefreshTask)
        }
        
        // Register stream start check task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.cyclismo.stream_start",
            using: nil
        ) { task in
            self.handleStreamStartTask(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleMorningRacesTask(at time: String) {
        let request = BGAppRefreshTaskRequest(identifier: "com.cyclismo.morning_races")
        
        // Calculate next notification time
        let nextTime = calculateNextTime(from: time)
        request.earliestBeginDate = nextTime
        
        try? BGTaskScheduler.shared.submit(request)
    }
}
`;

/**
 * Android-specific WorkManager implementation
 * Example implementation for Kotlin integration
 */
export const androidWorkManagerExample = `
// Kotlin code example for Android

import androidx.work.*
import java.util.concurrent.TimeUnit

class CyclismoNotificationManager(private val context: Context) {
    fun scheduleMorningRacesNotification(time: String) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
            
        val workRequest = PeriodicWorkRequestBuilder<MorningRacesWorker>(
            1, TimeUnit.DAYS
        )
            .setConstraints(constraints)
            .setInitialDelay(calculateDelayUntil(time), TimeUnit.MILLISECONDS)
            .build()
            
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "cyclismo_morning_races",
            ExistingPeriodicWorkPolicy.REPLACE,
            workRequest
        )
    }
    
    fun scheduleStreamStartNotifications(intervalMinutes: Int) {
        val workRequest = PeriodicWorkRequestBuilder<StreamStartWorker>(
            intervalMinutes.toLong(), TimeUnit.MINUTES
        ).build()
        
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "cyclismo_stream_start",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}

class MorningRacesWorker(context: Context, params: WorkerParameters) 
    : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        val races = fetchTodaysRaces()
        if (races.isNotEmpty()) {
            sendNotification(createMorningRacesNotification(races))
        }
        return Result.success()
    }
}
`;
