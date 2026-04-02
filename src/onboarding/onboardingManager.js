/**
 * OnboardingManager
 * Manages onboarding state and progress for min apps
 */

const STORAGE_KEY_PREFIX = 'min-apps-onboarding-';

export class OnboardingManager {
  /**
   * Check if user has completed onboarding for a specific app
   * @param {string} appId - App identifier (cyclismo, podlink, watchedit, yourtube)
   * @returns {boolean}
   */
  static hasCompletedOnboarding(appId) {
    try {
      const value = localStorage.getItem(`${STORAGE_KEY_PREFIX}${appId}`);
      return value === 'completed';
    } catch (error) {
      console.error('Error checking onboarding status:', error);
      return false;
    }
  }

  /**
   * Mark onboarding as completed for a specific app
   * @param {string} appId - App identifier
   */
  static markOnboardingComplete(appId) {
    try {
      localStorage.setItem(`${STORAGE_KEY_PREFIX}${appId}`, 'completed');
      localStorage.setItem(`${STORAGE_KEY_PREFIX}${appId}-completed-at`, new Date().toISOString());
    } catch (error) {
      console.error('Error marking onboarding complete:', error);
    }
  }

  /**
   * Reset onboarding status (useful for testing or re-onboarding)
   * @param {string} appId - App identifier
   */
  static resetOnboarding(appId) {
    try {
      localStorage.removeItem(`${STORAGE_KEY_PREFIX}${appId}`);
      localStorage.removeItem(`${STORAGE_KEY_PREFIX}${appId}-completed-at`);
      localStorage.removeItem(`${STORAGE_KEY_PREFIX}${appId}-current-step`);
    } catch (error) {
      console.error('Error resetting onboarding:', error);
    }
  }

  /**
   * Save current onboarding step
   * @param {string} appId - App identifier
   * @param {number} step - Current step number
   */
  static saveCurrentStep(appId, step) {
    try {
      localStorage.setItem(`${STORAGE_KEY_PREFIX}${appId}-current-step`, step.toString());
    } catch (error) {
      console.error('Error saving current step:', error);
    }
  }

  /**
   * Get current onboarding step
   * @param {string} appId - App identifier
   * @returns {number} - Current step (defaults to 1)
   */
  static getCurrentStep(appId) {
    try {
      const step = localStorage.getItem(`${STORAGE_KEY_PREFIX}${appId}-current-step`);
      return step ? parseInt(step, 10) : 1;
    } catch (error) {
      console.error('Error getting current step:', error);
      return 1;
    }
  }

  /**
   * Get completion date for a specific app
   * @param {string} appId - App identifier
   * @returns {Date|null}
   */
  static getCompletionDate(appId) {
    try {
      const dateStr = localStorage.getItem(`${STORAGE_KEY_PREFIX}${appId}-completed-at`);
      return dateStr ? new Date(dateStr) : null;
    } catch (error) {
      console.error('Error getting completion date:', error);
      return null;
    }
  }

  /**
   * Check if onboarding should be shown
   * @param {string} appId - App identifier
   * @returns {boolean}
   */
  static shouldShowOnboarding(appId) {
    return !this.hasCompletedOnboarding(appId);
  }

  /**
   * Skip onboarding (mark as completed without going through all steps)
   * @param {string} appId - App identifier
   */
  static skipOnboarding(appId) {
    this.markOnboardingComplete(appId);
  }

  /**
   * Get all completed onboardings
   * @returns {Array<{appId: string, completedAt: Date}>}
   */
  static getAllCompletedOnboardings() {
    const apps = ['cyclismo', 'podlink', 'watchedit', 'yourtube'];
    return apps
      .filter(appId => this.hasCompletedOnboarding(appId))
      .map(appId => ({
        appId,
        completedAt: this.getCompletionDate(appId),
      }));
  }
}

export default OnboardingManager;
