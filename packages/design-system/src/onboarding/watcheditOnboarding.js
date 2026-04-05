/**
 * WatchedIt (Movie Min) Onboarding Configuration
 * Introduces users to movie tracking features
 */

export const watcheditOnboardingConfig = {
  appId: 'watchedit',
  appName: 'WatchedIt',
  appDescription: 'Track and discover movies',
  
  steps: [
    {
      id: 'welcome',
      title: 'Welcome to WatchedIt',
      description: 'Your minimalist companion for tracking movies and discovering what to watch next.',
      icon: '/assets/watchedit/icon-welcome.svg',
      features: null,
    },
    {
      id: 'features',
      title: 'Discover Features',
      description: 'WatchedIt helps you organize your movie watching experience.',
      features: [
        {
          icon: '/assets/watchedit/icon-track.svg',
          title: 'Track Movies',
          description: 'Keep a record of every movie you watch with ratings and notes.',
        },
        {
          icon: '/assets/watchedit/icon-discover.svg',
          title: 'Smart Discovery',
          description: 'Get personalized movie recommendations based on your taste.',
        },
        {
          icon: '/assets/watchedit/icon-watchlist.svg',
          title: 'Watchlist',
          description: 'Save movies you want to watch and never forget them.',
        },
        {
          icon: '/assets/watchedit/icon-podcasts.svg',
          title: 'Movie Podcasts',
          description: 'Find and listen to podcasts discussing your favorite movies.',
        },
      ],
    },
    {
      id: 'notifications',
      title: 'Stay Updated',
      description: 'Get notified about new episodes of movie podcasts you follow.',
      permissionType: 'notifications',
      benefits: [
        'New episodes from podcasts you follow',
        'Daily summary of available content',
        'Never miss a discussion about your favorite movies',
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
      title: 'You\'re All Set!',
      description: 'Start tracking movies and discover your next favorite film.',
      icon: '/assets/watchedit/icon-ready.svg',
      ctaText: 'Start Watching',
    },
  ],
  
  // Color scheme
  theme: {
    primary: '#9C27B0',
    secondary: '#2196F3',
    accent: '#FF9800',
  },
  
  // Default settings to apply after onboarding
  defaultSettings: {
    notifications: {
      new_episodes: {
        enabled: false,
        time: '09:00',
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      },
    },
  },
};

export default watcheditOnboardingConfig;
