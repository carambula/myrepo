/**
 * Podlink (Podcast Min) Onboarding Configuration
 * Introduces users to podcast management features
 */

export const podlinkOnboardingConfig = {
  appId: 'podlink',
  appName: 'Podlink',
  appDescription: 'Your minimal podcast manager',
  
  steps: [
    {
      id: 'welcome',
      title: 'Welcome to Podlink',
      description: 'A minimal, focused way to manage your podcast queue and never miss an episode.',
      icon: '/assets/podlink/icon-welcome.svg',
      features: null,
    },
    {
      id: 'features',
      title: 'Powerful Yet Simple',
      description: 'Everything you need to manage podcasts, nothing you don\'t.',
      features: [
        {
          icon: '/assets/podlink/icon-queue.svg',
          title: 'Smart Queue',
          description: 'Automatically organize episodes in a queue tailored to your listening habits.',
        },
        {
          icon: '/assets/podlink/icon-priority.svg',
          title: 'Priority Podcasts',
          description: 'Mark your favorite podcasts for instant notifications when new episodes drop.',
        },
        {
          icon: '/assets/podlink/icon-apple-intel.svg',
          title: 'Apple Intelligence',
          description: 'Get AI-powered summaries and insights about your podcast queue.',
        },
        {
          icon: '/assets/podlink/icon-minimal.svg',
          title: 'Minimal Design',
          description: 'Clean interface that lets you focus on listening, not managing.',
        },
      ],
    },
    {
      id: 'notifications',
      title: 'Never Miss an Episode',
      description: 'Get notified about new episodes from your priority podcasts and daily queue summaries.',
      permissionType: 'notifications',
      benefits: [
        'Instant notifications for priority podcasts',
        'Morning queue summary with Apple Intelligence',
        'Customizable check intervals',
        'Stay up to date effortlessly',
      ],
    },
    {
      id: 'priority-setup',
      title: 'Set Priority Podcasts',
      description: 'Choose podcasts you never want to miss. You can update these anytime.',
      type: 'priority-podcast-selector',
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
      title: 'Ready to Listen!',
      description: 'Your podcast queue is ready. Start listening to what matters.',
      icon: '/assets/podlink/icon-ready.svg',
      ctaText: 'Start Listening',
    },
  ],
  
  // Color scheme
  theme: {
    primary: '#FF9800',
    secondary: '#FF5722',
    accent: '#FFC107',
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
      priority_podcasts: {
        enabled: false,
        checkIntervalMinutes: 60,
        priorityPodcastIds: [],
      },
    },
  },
};

export default podlinkOnboardingConfig;
