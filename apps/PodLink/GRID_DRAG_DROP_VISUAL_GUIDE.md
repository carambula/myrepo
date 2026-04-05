# Grid Drag and Drop - Visual Guide

## User Interaction Flow

```
┌─────────────────────────────────────────────────────┐
│  PodLink - Main Screen (Grid View)                  │
└─────────────────────────────────────────────────────┘

STEP 1: Initial State
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │  ← Toolbar
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  A  │  │  B  │  │  C  │                     │  ← Row 1
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  D  │  │  E  │  │  F  │                     │  ← Row 2
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
└───────────────────────────────────────────────────┘

User wants to move Podcast A to position E


STEP 2: Long Press
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │░A░░░│  │  B  │  │  C  │    ← A is pressed    │
│   └─────┘  └─────┘  └─────┘                     │
│     ↑                                             │
│   Long press                                      │
│   (~1 second)                                     │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  D  │  │  E  │  │  F  │                     │
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
└───────────────────────────────────────────────────┘


STEP 3: Lift Animation
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌═════┐  ┌─────┐  ┌─────┐                     │
│   ║  A  ║  │  B  │  │  C  │    ← A lifts up      │
│   ╚═════╝  └─────┘  └─────┘      with shadow     │
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  D  │  │  E  │  │  F  │                     │
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
└───────────────────────────────────────────────────┘


STEP 4: Drag to Position B
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│            ┌═════┐                               │
│   [empty]  ║  A  ║  ┌─────┐                     │
│            ╚═════╝  │  C  │    ← B moves left    │
│   ┌─────┐  └─────┘  └─────┘      A hovers        │
│   │  B  │                         over B          │
│   └─────┘                                         │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  D  │  │  E  │  │  F  │                     │
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
└───────────────────────────────────────────────────┘


STEP 5: Continue Dragging to Position E
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  B  │  │  C  │  │  D  │    ← Others shift    │
│   └─────┘  └─────┘  └─────┘      as A moves      │
│                                                   │
│            ┌═════┐  ┌─────┐                     │
│   [empty]  ║  A  ║  │  F  │    ← A hovers        │
│            ╚═════╝  └─────┘      over E position │
│   ┌─────┐                                         │
│   │  E  │                        E moves down     │
│   └─────┘                                         │
│                                                   │
└───────────────────────────────────────────────────┘


STEP 6: Release (Drop)
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  B  │  │  C  │  │  D  │                     │
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  E  │  │░A░░░│  │  F  │    ← A settles      │
│   └─────┘  └─────┘  └─────┘      with spring    │
│              ↓                     animation      │
│          Dropped!                                 │
│                                                   │
└───────────────────────────────────────────────────┘


STEP 7: Final State (Saved)
┌───────────────────────────────────────────────────┐
│  🔍                                      ⊞  👤     │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  B  │  │  C  │  │  D  │    ← New order       │
│   └─────┘  └─────┘  └─────┘      saved to        │
│                                   UserDefaults    │
│   ┌─────┐  ┌─────┐  ┌─────┐                     │
│   │  E  │  │  A  │  │  F  │    ← Persisted       │
│   └─────┘  └─────┘  └─────┘                     │
│                                                   │
└───────────────────────────────────────────────────┘

Order: B → C → D → E → A → F
```

---

## Animation Details

### Spring Animation Parameters

```swift
.spring(response: 0.3, dampingFraction: 0.7)
```

**Visual representation of spring motion:**

```
Position over Time:

  ▲
  │                    ┌──────────── Final position
  │              ┌────┘
  │         ┌───┘
  │    ┌───┘
  │ ┌─┘
  └─┴────────────────────────────────────► Time
  0ms   100ms   200ms   300ms   400ms

Response: 0.3s (300ms) - Quick, snappy
Damping: 0.7 - Slight bounce, natural feel
```

**Without drag and drop:**
```
No animation
Podcasts stay in original order forever
```

**With drag and drop:**
```
Smooth transitions
User control over order
Persists across sessions
```

---

## State Machine Diagram

```
┌─────────────────────────────────────────────────────┐
│                  Drag and Drop States                │
└─────────────────────────────────────────────────────┘

         ┌──────────────┐
         │  IDLE STATE  │
         │              │
         │ draggedPodcast │
         │    = nil      │
         └──────┬───────┘
                │
                │ User long-presses
                │ on podcast
                ▼
         ┌──────────────┐
         │ DRAG START   │
         │              │
         │ draggedPodcast │
         │  = Podcast A  │
         └──────┬───────┘
                │
                │ User drags over
                │ another podcast
                ▼
         ┌──────────────┐
         │ DROP ENTERED │
         │              │
         │ • Calculate   │
         │   fromIndex   │
         │ • Calculate   │
         │   toIndex     │
         │ • Move array  │
         │ • Save order  │
         └──────┬───────┘
                │
                │ (Repeats for each
                │  podcast dragged over)
                │
                ▼
         ┌──────────────┐
         │ PERFORM DROP │
         │              │
         │ draggedPodcast │
         │    = nil      │
         └──────┬───────┘
                │
                │ Return to idle
                ▼
         ┌──────────────┐
         │  IDLE STATE  │
         └──────────────┘
```

---

## Data Flow Diagram

```
┌────────────────────────────────────────────────────────┐
│              Drag and Drop Data Flow                    │
└────────────────────────────────────────────────────────┘

User Action: Long-press and drag podcast
                    │
                    ▼
        ┌──────────────────────┐
        │   .onDrag modifier   │
        │                      │
        │ draggedPodcast = A   │
        │ NSItemProvider(ID)   │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  Drag over Podcast B │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────────────┐
        │ PodcastDropDelegate          │
        │                              │
        │ dropEntered(info:)           │
        │ • Check if valid drop        │
        │ • Find fromIndex (A's pos)   │
        │ • Find toIndex (B's pos)     │
        └──────────┬───────────────────┘
                   │
                   ▼
        ┌──────────────────────────────┐
        │ Array Manipulation           │
        │                              │
        │ followedPodcasts.move(       │
        │   fromOffsets: fromIndex,    │
        │   toOffset: toIndex          │
        │ )                            │
        └──────────┬───────────────────┘
                   │
                   │ with animation
                   ▼
        ┌──────────────────────────────┐
        │  UI Updates (Grid Shifts)    │
        │                              │
        │  Spring animation triggers   │
        │  Other podcasts reposition   │
        └──────────┬───────────────────┘
                   │
                   │ immediately
                   ▼
        ┌──────────────────────────────┐
        │  savePodcastOrder()          │
        │                              │
        │  • Encode array to JSON      │
        │  • Save to UserDefaults      │
        │  • Post notification         │
        └──────────┬───────────────────┘
                   │
                   ▼
        ┌──────────────────────────────┐
        │  UserDefaults                │
        │                              │
        │  Key: "followedPodcasts"     │
        │  Value: [Podcast] JSON       │
        └──────────┬───────────────────┘
                   │
                   │ notification
                   ▼
        ┌──────────────────────────────┐
        │  Other Views Update          │
        │  (if listening)              │
        └──────────────────────────────┘

User releases drag
        │
        ▼
┌──────────────────────┐
│ performDrop(info:)   │
│                      │
│ draggedPodcast = nil │
│ return true          │
└──────────────────────┘
```

---

## Code Structure Visualization

```
PodcastListView.swift
│
├── State Variables
│   ├── @State followedPodcasts: [Podcast]    ← Reordered array
│   ├── @State draggedPodcast: Podcast?       ← Currently dragged
│   └── @State latestEpisodes: [String: Episode]
│
├── Grid Layout
│   └── LazyVGrid
│       └── ForEach(followedPodcasts)
│           └── podcastGridItem(podcast)
│               ├── .onDrag { ... }           ← Drag source
│               └── .onDrop(delegate: ...)    ← Drop target
│
├── Methods
│   ├── loadPodcasts()         ← Load from UserDefaults
│   ├── savePodcastOrder()     ← Save to UserDefaults
│   └── loadLatestEpisodes()
│
└── Drop Delegate (bottom of file)
    └── PodcastDropDelegate: DropDelegate
        ├── performDrop(info:) ← Clean up state
        └── dropEntered(info:) ← Reorder array
```

---

## Component Interaction Map

```
                    ┌────────────────┐
                    │  ContentView   │
                    │                │
                    │  Toolbar with  │
                    │  grid/list     │
                    │  toggle        │
                    └────────┬───────┘
                             │
                             ▼
                ┌────────────────────────┐
                │  PodcastListView       │
                │                        │
                │  Mode: Grid or List    │
                └────────┬───────────────┘
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────┐           ┌──────────────────┐
│  Grid Layout    │           │  List Layout     │
│                 │           │                  │
│ ✅ Drag & Drop  │           │ ❌ No Drag Drop  │
│                 │           │                  │
│ Uses:           │           │ Uses:            │
│ • LazyVGrid     │           │ • LazyVStack     │
│ • .onDrag       │           │ • PodcastRowView │
│ • .onDrop       │           │                  │
│ • DropDelegate  │           │                  │
└─────────┬───────┘           └──────────────────┘
          │
          │ Each grid item
          ▼
┌─────────────────────────┐
│  podcastGridItem()      │
│                         │
│  • Artwork              │
│  • Optional title       │
│  • Unplayed indicator   │
│  • Tap interaction      │
│  • Drag gesture         │
│  • Drop delegate        │
└─────────┬───────────────┘
          │
          │ On drag over
          ▼
┌─────────────────────────┐
│ PodcastDropDelegate     │
│                         │
│ • Validate drop         │
│ • Find indices          │
│ • Reorder array         │
│ • Trigger animation     │
│ • Save to UserDefaults  │
└─────────────────────────┘
```

---

## Persistence Flow

```
App Launch
    │
    ▼
┌────────────────────┐
│ loadPodcasts()     │
│                    │
│ Read UserDefaults  │
│ "followedPodcasts" │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Decode JSON        │
│ → [Podcast]        │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Set state          │
│ followedPodcasts   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Render grid        │
│ in saved order     │
└────────────────────┘

User drags podcast
    │
    ▼
┌────────────────────┐
│ Array reordered    │
│ in memory          │
└────────┬───────────┘
         │
         │ immediately
         ▼
┌────────────────────┐
│savePodcastOrder()  │
│                    │
│ Encode to JSON     │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Write UserDefaults │
│ "followedPodcasts" │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Post notification  │
│ (for other views)  │
└────────────────────┘

App Restart
    │
    ▼
┌────────────────────┐
│ loadPodcasts()     │
│                    │
│ Order preserved!   │
└────────────────────┘
```

---

## Gesture Recognition Flow

```
User touches screen
        │
        ▼
    ┌───────┐
    │ Start │
    └───┬───┘
        │
        ▼
    Touch down
        │
        ├─────────┬─────────┐
        │         │         │
    < 0.5s    0.5-1.0s    > 1.0s
        │         │         │
        ▼         ▼         ▼
    ┌────┐   ┌──────┐  ┌──────┐
    │ Tap│   │ Long │  │ Long │
    └────┘   │Press │  │Press │
             │Start │  │Rec.  │
             └──┬───┘  └──────┘
                │
                ▼
         iOS recognizes
         drag gesture
                │
                ▼
         .onDrag triggers
                │
                ▼
         draggedPodcast
         set to podcast
                │
                ▼
         Visual lift
         animation
                │
                ▼
         User moves
         finger
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
    Over same      Over different
    podcast        podcast
        │                │
        ▼                ▼
    No action      .onDrop triggers
        │          dropEntered()
        │                │
        │                ▼
        │          Array reordered
        │          Animation plays
        │                │
        └────────┬───────┘
                 │
                 ▼
         User lifts finger
                 │
                 ▼
         performDrop()
                 │
                 ▼
         Clear state
         (draggedPodcast = nil)
```

---

## Error Handling Flow

```
User drags podcast
        │
        ▼
┌─────────────────────┐
│ dropEntered()       │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────┐
│ guard let draggedPodcast... │  ← Check 1: Is something dragged?
└─────────┬───────────────────┘
          │
          ├── nil? → Return (no action)
          │
          ▼ Valid
┌─────────────────────────────┐
│ draggedPodcast.id !=        │  ← Check 2: Different podcast?
│ podcast.id                  │
└─────────┬───────────────────┘
          │
          ├── Same? → Return (no action)
          │
          ▼ Different
┌─────────────────────────────┐
│ let fromIndex =             │  ← Check 3: Source index exists?
│ podcasts.firstIndex(...)    │
└─────────┬───────────────────┘
          │
          ├── nil? → Return (shouldn't happen)
          │
          ▼ Found
┌─────────────────────────────┐
│ let toIndex =               │  ← Check 4: Target index exists?
│ podcasts.firstIndex(...)    │
└─────────┬───────────────────┘
          │
          ├── nil? → Return (shouldn't happen)
          │
          ▼ Found
┌─────────────────────────────┐
│ Perform move                │
│ • Array manipulation        │
│ • Animation                 │
│ • Save to UserDefaults      │
└─────────────────────────────┘

All checks passed ✅
No crashes, graceful handling
```

This visual guide shows every step of the drag and drop interaction, from the user's perspective down to the code execution flow.
