/**
 * Background Job Scheduler
 * Manages scheduling and execution of background notification jobs
 */

import { getEnabledNotifications, loadNotificationPreferences } from './notificationPreferences.js';
import { calculateNextNotificationTime } from './notificationScheduler.js';
import NotificationService from './notificationService.js';

/**
 * Job Scheduler
 * Manages recurring background jobs
 */
export class BackgroundJobScheduler {
  constructor() {
    this.jobs = new Map();
    this.intervals = new Map();
    this.isRunning = false;
  }
  
  /**
   * Register a background job
   */
  registerJob(jobId, jobConfig) {
    this.jobs.set(jobId, {
      id: jobId,
      ...jobConfig,
      lastRun: null,
      nextRun: null,
      status: 'pending'
    });
  }
  
  /**
   * Unregister a job
   */
  unregisterJob(jobId) {
    this.stopJob(jobId);
    this.jobs.delete(jobId);
  }
  
  /**
   * Start a specific job
   */
  startJob(jobId) {
    const job = this.jobs.get(jobId);
    
    if (!job) {
      throw new Error(`Job ${jobId} not found`);
    }
    
    if (this.intervals.has(jobId)) {
      return;
    }
    
    if (job.type === 'daily' && job.time) {
      this.scheduleDailyJob(jobId, job);
    } else if (job.type === 'interval' && job.intervalMinutes) {
      this.scheduleIntervalJob(jobId, job);
    }
  }
  
  /**
   * Stop a specific job
   */
  stopJob(jobId) {
    const intervalData = this.intervals.get(jobId);
    
    if (intervalData) {
      if (intervalData.timeout) {
        clearTimeout(intervalData.timeout);
      }
      if (intervalData.interval) {
        clearInterval(intervalData.interval);
      }
      
      this.intervals.delete(jobId);
    }
    
    const job = this.jobs.get(jobId);
    if (job) {
      job.status = 'stopped';
    }
  }
  
  /**
   * Schedule a daily job
   */
  scheduleDailyJob(jobId, job) {
    const nextTime = calculateNextNotificationTime(job.time, job.timezone);
    job.nextRun = nextTime;
    job.status = 'scheduled';
    
    const delay = nextTime.getTime() - Date.now();
    
    const timeout = setTimeout(async () => {
      await this.executeJob(jobId);
      
      this.intervals.delete(jobId);
      this.scheduleDailyJob(jobId, job);
    }, delay);
    
    this.intervals.set(jobId, { timeout, type: 'daily' });
    
    console.log(`Scheduled daily job ${jobId} for ${nextTime.toLocaleString()}`);
  }
  
  /**
   * Schedule an interval job
   */
  scheduleIntervalJob(jobId, job) {
    const intervalMs = job.intervalMinutes * 60 * 1000;
    job.status = 'running';
    
    const interval = setInterval(async () => {
      await this.executeJob(jobId);
    }, intervalMs);
    
    this.intervals.set(jobId, { interval, type: 'interval' });
    
    this.executeJob(jobId);
    
    console.log(`Scheduled interval job ${jobId} every ${job.intervalMinutes} minutes`);
  }
  
  /**
   * Execute a job
   */
  async executeJob(jobId) {
    const job = this.jobs.get(jobId);
    
    if (!job || !job.handler) {
      console.error(`Job ${jobId} not found or has no handler`);
      return;
    }
    
    job.status = 'running';
    job.lastRun = new Date();
    
    console.log(`Executing job: ${jobId}`);
    
    try {
      await job.handler();
      job.status = 'completed';
      console.log(`Job ${jobId} completed successfully`);
    } catch (error) {
      job.status = 'failed';
      console.error(`Job ${jobId} failed:`, error);
    }
  }
  
  /**
   * Start all registered jobs
   */
  startAll() {
    this.isRunning = true;
    
    this.jobs.forEach((job, jobId) => {
      this.startJob(jobId);
    });
  }
  
  /**
   * Stop all jobs
   */
  stopAll() {
    this.isRunning = false;
    
    this.intervals.forEach((_, jobId) => {
      this.stopJob(jobId);
    });
  }
  
  /**
   * Get job status
   */
  getJobStatus(jobId) {
    return this.jobs.get(jobId);
  }
  
  /**
   * Get all jobs
   */
  getAllJobs() {
    return Array.from(this.jobs.values());
  }
  
  /**
   * Get running jobs
   */
  getRunningJobs() {
    return this.getAllJobs().filter(job => 
      job.status === 'running' || job.status === 'scheduled'
    );
  }
}

/**
 * Global scheduler instance
 */
let globalScheduler = null;

/**
 * Get or create global scheduler
 */
export function getScheduler() {
  if (!globalScheduler) {
    globalScheduler = new BackgroundJobScheduler();
  }
  return globalScheduler;
}

/**
 * Initialize background jobs for an app
 */
export async function initializeBackgroundJobs(appId, jobHandlers) {
  const scheduler = getScheduler();
  const preferences = loadNotificationPreferences(appId);
  const enabled = getEnabledNotifications(appId);
  
  enabled.forEach(({ type, settings }) => {
    const jobId = `${appId}.${type}`;
    const handler = jobHandlers[type];
    
    if (!handler) {
      console.warn(`No handler registered for ${jobId}`);
      return;
    }
    
    const jobConfig = {
      appId,
      type: settings.time ? 'daily' : 'interval',
      time: settings.time,
      timezone: settings.timezone,
      intervalMinutes: settings.checkIntervalMinutes,
      handler: async () => {
        try {
          await handler(settings, NotificationService);
        } catch (error) {
          console.error(`Error in job handler ${jobId}:`, error);
        }
      }
    };
    
    scheduler.registerJob(jobId, jobConfig);
    scheduler.startJob(jobId);
    
    console.log(`Initialized job: ${jobId}`, settings);
  });
  
  return scheduler;
}

/**
 * Stop background jobs for an app
 */
export function stopBackgroundJobs(appId) {
  const scheduler = getScheduler();
  const jobs = scheduler.getAllJobs().filter(job => job.appId === appId);
  
  jobs.forEach(job => {
    scheduler.stopJob(job.id);
  });
}

/**
 * Restart background jobs for an app
 */
export async function restartBackgroundJobs(appId, jobHandlers) {
  stopBackgroundJobs(appId);
  await initializeBackgroundJobs(appId, jobHandlers);
}

/**
 * Simple in-memory job queue for immediate execution
 */
export class JobQueue {
  constructor() {
    this.queue = [];
    this.isProcessing = false;
  }
  
  /**
   * Add job to queue
   */
  async enqueue(job) {
    this.queue.push(job);
    
    if (!this.isProcessing) {
      await this.processQueue();
    }
  }
  
  /**
   * Process queue
   */
  async processQueue() {
    if (this.queue.length === 0) {
      this.isProcessing = false;
      return;
    }
    
    this.isProcessing = true;
    
    while (this.queue.length > 0) {
      const job = this.queue.shift();
      
      try {
        await job();
      } catch (error) {
        console.error('Job queue error:', error);
      }
    }
    
    this.isProcessing = false;
  }
  
  /**
   * Get queue size
   */
  size() {
    return this.queue.length;
  }
  
  /**
   * Clear queue
   */
  clear() {
    this.queue = [];
    this.isProcessing = false;
  }
}

/**
 * Global job queue instance
 */
let globalQueue = null;

/**
 * Get or create global job queue
 */
export function getJobQueue() {
  if (!globalQueue) {
    globalQueue = new JobQueue();
  }
  return globalQueue;
}

export default BackgroundJobScheduler;
