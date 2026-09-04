/**
 * useOnboardingState Hook
 * Manage onboarding state and completion status
 */

import { useState, useEffect } from 'react';

const STORAGE_KEY_PREFIX = 'onboarding_completed_';

/**
 * Get onboarding completion status from localStorage
 */
export function isOnboardingCompleted(appId) {
  try {
    const key = `${STORAGE_KEY_PREFIX}${appId}`;
    const value = localStorage.getItem(key);
    return value === 'true';
  } catch (error) {
    console.error('Error checking onboarding status:', error);
    return false;
  }
}

/**
 * Mark onboarding as completed in localStorage
 */
export function setOnboardingCompleted(appId, completed = true) {
  try {
    const key = `${STORAGE_KEY_PREFIX}${appId}`;
    localStorage.setItem(key, String(completed));
    return true;
  } catch (error) {
    console.error('Error saving onboarding status:', error);
    return false;
  }
}

/**
 * Reset onboarding status (useful for testing or allowing users to re-run)
 */
export function resetOnboarding(appId) {
  return setOnboardingCompleted(appId, false);
}

/**
 * Hook to manage onboarding state
 */
export function useOnboardingState(appId) {
  const [completed, setCompleted] = useState(() => isOnboardingCompleted(appId));
  const [showOnboarding, setShowOnboarding] = useState(!completed);

  useEffect(() => {
    const isCompleted = isOnboardingCompleted(appId);
    setCompleted(isCompleted);
    setShowOnboarding(!isCompleted);
  }, [appId]);

  const markAsCompleted = () => {
    setOnboardingCompleted(appId, true);
    setCompleted(true);
    setShowOnboarding(false);
  };

  const restart = () => {
    resetOnboarding(appId);
    setCompleted(false);
    setShowOnboarding(true);
  };

  return {
    completed,
    showOnboarding,
    markAsCompleted,
    restart
  };
}
