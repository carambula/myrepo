//
//  OnboardingState.swift
//  WatchedIt
//
//  Tracks new user experience: intro seen and per-feature "completed" for onboarding flow.
//  Used only on iOS; tvOS does not show this flow.
//

import Foundation

#if os(iOS)
public enum OnboardingState {
    // MARK: - Storage Keys
    
    public static let introSeenKey = "onboardingIntroSeen"
    public static let streamingCompletedKey = "onboardingStreamingCompleted"
    public static let podcastCompletedKey = "onboardingPodcastCompleted"
    public static let listsCompletedKey = "onboardingListsCompleted"
    
    // MARK: - Read / Write
    
    public static var introSeen: Bool {
        get { UserDefaults.standard.bool(forKey: introSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: introSeenKey) }
    }
    
    public static var streamingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: streamingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: streamingCompletedKey) }
    }
    
    public static var podcastCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: podcastCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: podcastCompletedKey) }
    }
    
    public static var listsCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: listsCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: listsCompletedKey) }
    }
    
    /// True if we should show the full-screen new user experience on launch.
    public static var shouldShowOnboarding: Bool {
        !introSeen || !streamingCompleted || !podcastCompleted || !listsCompleted
    }
    
    /// Resets all onboarding state so the new user experience is shown again (e.g. for dogfooding).
    /// Does not clear actual preferences (streaming, podcast, lists).
    public static func resetNewUserExperience() {
        UserDefaults.standard.set(false, forKey: introSeenKey)
        UserDefaults.standard.set(false, forKey: streamingCompletedKey)
        UserDefaults.standard.set(false, forKey: podcastCompletedKey)
        UserDefaults.standard.set(false, forKey: listsCompletedKey)
    }
}
#endif
