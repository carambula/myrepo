/**
 * Home Screen Template
 * 
 * This template shows how to create a proper home screen with:
 * - Logo positioned at exactly 32px from top (desktop)
 * - Centered layout
 * - Consistent button spacing
 * - Theme toggle
 */

import React from 'react';
import { HomeLayout } from '@min-apps/design-system/layouts';
import { Button, ThemeToggle } from '@min-apps/design-system/components';
import { spacing } from '@min-apps/design-system/tokens';

function Home() {
  const handleGetStarted = () => {
    // Navigate to main app view
    console.log('Get started clicked');
  };

  const handleSecondaryAction = () => {
    // Navigate to secondary view (e.g., browse, library)
    console.log('Secondary action clicked');
  };

  return (
    <HomeLayout
      logo="/logo.svg"  // Replace with your app's logo path
      title="Your App Name"
      subtitle="Your app tagline or description"
    >
      {/* Theme toggle in top right */}
      <div style={{ 
        position: 'absolute', 
        top: spacing[4], 
        right: spacing[4] 
      }}>
        <ThemeToggle />
      </div>

      {/* Main actions */}
      <div style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        gap: spacing[4],
        marginTop: spacing[8],
        width: '100%',
        maxWidth: '400px'
      }}>
        <Button 
          variant="primary" 
          fullWidth
          onClick={handleGetStarted}
        >
          Get Started
        </Button>
        
        <Button 
          variant="outline" 
          fullWidth
          onClick={handleSecondaryAction}
        >
          Browse Content
        </Button>
      </div>

      {/* Optional: Additional info or links */}
      <p style={{ 
        marginTop: spacing[6],
        color: 'var(--color-text-secondary)',
        fontSize: '14px'
      }}>
        New to this app? <a href="/about" style={{ color: 'var(--color-primary-main)' }}>Learn more</a>
      </p>
    </HomeLayout>
  );
}

export default Home;
