/**
 * Cyclismo Guide Onboarding Configuration
 * Introduces users to cycling race tracking features
 */

export const cyclismoOnboardingConfig = {
  appId: 'cyclismo',
  appName: 'Cyclismo Guide',
  appDescription: 'Your guide to pro cycling',
  
  steps: [
    {
      id: 'welcome',
      title: 'Welcome to Cyclismo',
      description: 'Never miss a moment of professional cycling with real-time race guides and notifications.',
      icon: '/assets/cyclismo/icon-welcome.svg',
      features: null,
    },
    {
      id: 'features',
      title: 'Follow Every Race',
      description: 'Stay connected to the world of professional cycling.',
      features: [
        {
          icon: '/assets/cyclismo/icon-schedule.svg',
          title: 'Race Schedule',
          description: 'View upcoming races with times, routes, and streaming information.',
        },
        {
          icon: '/assets/cyclismo/icon-stream.svg',
          title: 'Stream Alerts',
          description: 'Get notified minutes before races start so you never miss the action.',
        },
        {
          icon: '/assets/cyclismo/icon-recap.svg',
          title: 'Race Recaps',
          description: 'Find podcasts and replay links after each stage or race concludes.',
        },
        {
          icon: '/assets/cyclismo/icon-save.svg',
          title: 'Save Races',
          description: 'Mark races you care about and get personalized notifications.',
        },
      ],
    },
    {
      id: 'notifications',
      title: 'Race Day Notifications',
      description: 'Get timely alerts about races, streams, and recaps.',
      permissionType: 'notifications',
      benefits: [
        'Morning summary of today\'s races',
        'Pre-race alerts before streams start',
        'Recap notifications with podcasts and replays',
        'Customizable timing for all notifications',
      ],
    },
    {
      id: 'notification-settings',
      title: 'Customize Notifications',
      description: 'Set up when and how you want to be notified about races.',
      type: 'notification-preferences',
      settings: [
        {
          id: 'morning_races',
          title: 'Morning Race Summary',
          description: 'Daily notification with today\'s race schedule',
          defaultEnabled: true,
          defaultTime: '08:00',
        },
        {
          id: 'stream_start',
          title: 'Stream Start Alerts',
          description: 'Notification before each race stream begins',
          defaultEnabled: true,
          defaultMinutesBefore: 15,
        },
        {
          id: 'recap',
          title: 'Race Recaps',
          description: 'Notification when podcasts and replays are available',
          defaultEnabled: true,
          defaultHoursAfter: 2,
        },
      ],
    },
    {
      id: 'theme',
      title: 'Choose Your Theme',
      description: 'Select the appearance that works best for you. You can change this anytime in settings.',
      type: 'theme-selector',
    },
    {
      id: 'ready',
      title: 'Ready to Race!',
      description: 'Your personal cycling guide is ready. Enjoy the races!',
      icon: '/assets/cyclismo/icon-ready.svg',
      ctaText: 'View Races',
    },
  ],
  
  // Color scheme
  theme: {
    primary: '#4CAF50',
    secondary: '#009688',
    accent: '#8BC34A',
  },
  
  // Default settings to apply after onboarding
  defaultSettings: {
    notifications: {
      morning_races: {
        enabled: false,
        time: '08:00',
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      },
      stream_start: {
        enabled: false,
        minutesBefore: 15,
        onlySavedRaces: false,
      },
      recap: {
        enabled: false,
        hoursAfterLastRace: 2,
      },
    },
  },
};

export default cyclismoOnboardingConfig;
