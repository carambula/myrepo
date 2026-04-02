/**
 * Yourtube (Video Min) Onboarding Configuration
 * Introduces users to video queue management features
 */

export const yourtubeOnboardingConfig = {
  appId: 'yourtube',
  appName: 'Yourtube',
  appDescription: 'Minimal YouTube queue manager',
  
  steps: [
    {
      id: 'welcome',
      title: 'Welcome to Yourtube',
      description: 'Cut through the noise and focus on the videos that matter to you.',
      icon: '/assets/yourtube/icon-welcome.svg',
      features: null,
    },
    {
      id: 'features',
      title: 'Watch Intentionally',
      description: 'Transform how you consume video content with these powerful features.',
      features: [
        {
          icon: '/assets/yourtube/icon-queue.svg',
          title: 'Smart Video Queue',
          description: 'Automatically organize videos from your subscriptions into a clean queue.',
        },
        {
          icon: '/assets/yourtube/icon-priority.svg',
          title: 'Priority Channels',
          description: 'Mark important channels to get notified the moment they upload.',
        },
        {
          icon: '/assets/yourtube/icon-apple-intel.svg',
          title: 'Apple Intelligence',
          description: 'Get AI summaries of your queue to decide what to watch first.',
        },
        {
          icon: '/assets/yourtube/icon-focus.svg',
          title: 'Distraction-Free',
          description: 'No recommendations, no infinite scroll. Just your queue.',
        },
      ],
    },
    {
      id: 'notifications',
      title: 'Stay in the Loop',
      description: 'Get notified about new videos from priority channels and queue updates.',
      permissionType: 'notifications',
      benefits: [
        'Instant alerts for priority channel uploads',
        'Daily queue summary powered by Apple Intelligence',
        'Customizable notification frequency',
        'Never miss important content',
      ],
    },
    {
      id: 'priority-setup',
      title: 'Choose Priority Channels',
      description: 'Select channels you want to follow closely. You can adjust these later.',
      type: 'priority-channel-selector',
      skipAllowed: true,
    },
    {
      id: 'theme',
      title: 'Choose Your Theme',
      description: 'Select the appearance that works best for you. You can change this anytime in settings.',
      type: 'theme-selector',
    },
    {
      id: 'ready',
      title: 'You\'re Ready!',
      description: 'Your video queue awaits. Watch with intention.',
      icon: '/assets/yourtube/icon-ready.svg',
      ctaText: 'Start Watching',
    },
  ],
  
  // Color scheme
  theme: {
    primary: '#F44336',
    secondary: '#E91E63',
    accent: '#FF5722',
  },
  
  // Default settings to apply after onboarding
  defaultSettings: {
    notifications: {
      morning_queue: {
        enabled: false,
        time: '08:00',
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        useAppleIntelligence: true,
      },
      priority_channels: {
        enabled: false,
        checkIntervalMinutes: 60,
        priorityChannelIds: [],
      },
    },
  },
};

export default yourtubeOnboardingConfig;
