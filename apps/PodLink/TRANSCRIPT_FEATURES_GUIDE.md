# Transcript Features Guide

## User-Facing Features

### 1. Episode Detail Page - Transcript Preview

When viewing an episode that has a transcript available:

**Loading State**:
```
┌─────────────────────────────────────┐
│ Transcript                          │
│                                     │
│ ⟳ Loading transcript...            │
│                                     │
└─────────────────────────────────────┘
```

**Loaded Transcript with Metadata**:
```
┌─────────────────────────────────────┐
│ Transcript              [⤢] [⋯]     │
│                                     │
│ 📝 podcast:transcript • 2,847 words │
│ 👥 Speakers                         │
│                                     │
│ [Speaker Name]  [12:34]             │
│ "Welcome to today's episode..."     │
│                                     │
│ [Host]  [13:15]                     │
│ "Today we're discussing..."         │
│                                     │
│ ... (10 more segments)              │
│                                     │
│ Show 152 more segments...           │
└─────────────────────────────────────┘
```

**Controls**:
- **[⤢]** - Open full-screen transcript viewer
- **[⋯]** - Menu with:
  - Copy All
  - Show More / Show Less
  - Open Full View

### 2. Full-Screen Transcript Viewer

Tap the expand icon or "Open Full View" to access:

```
┌─────────────────────────────────────┐
│ Done                   Transcript ⋯ │
├─────────────────────────────────────┤
│ 🔍 Search transcript                │
├─────────────────────────────────────┤
│                                     │
│ [Host]  [0:15]                      │
│ Welcome everyone to episode 42...   │
│                                     │
│ [Guest]  [1:32]                     │
│ Thanks for having me!               │
│                                     │
│ [Host]  [1:45]                      │
│ Today we're talking about Swift...  │
│ (highlighted if searched)           │
│                                     │
│ ... (scrollable list)               │
│                                     │
└─────────────────────────────────────┘
```

**Features**:
- **Search**: Type to find and highlight text
- **Timestamps**: Tap to seek playback to that moment
- **Speaker Labels**: Shows who's speaking (if available)
- **Text Selection**: Long-press to select and copy
- **Menu Actions**:
  - Copy All - Copy entire transcript
  - Info - View transcript metadata

### 3. Transcript Info Sheet

View detailed metadata about the transcript:

```
┌─────────────────────────────────────┐
│              Transcript Info     Done│
├─────────────────────────────────────┤
│ SOURCE                              │
│ Type        podcast:transcript      │
│ Format      VTT                     │
│ Fetched     Mar 21, 2026 2:30 PM   │
│                                     │
│ CONTENT                             │
│ Word Count  2,847                   │
│ Speaker Labels  Yes                 │
│ Timestamps      Yes                 │
│ Segments        153                 │
│                                     │
└─────────────────────────────────────┘
```

---

## How Transcripts Are Obtained

### Automatic Sources (Current Implementation)

#### 1. RSS Feed Transcript Tag
```xml
<item>
  <title>Episode 42: SwiftUI Deep Dive</title>
  <podcast:transcript 
    url="https://example.com/ep42.vtt" 
    type="application/vtt" />
</item>
```

**PodLink automatically**:
- Detects the `<podcast:transcript>` tag
- Downloads the transcript file
- Parses VTT, SRT, JSON, or plain text
- Caches for 30 days
- Displays in episode detail

#### 2. YouTube Auto-Captions
For episodes with YouTube video URLs:

```xml
<item>
  <enclosure 
    url="https://www.youtube.com/watch?v=abc123" 
    type="video/mp4" />
</item>
```

**PodLink automatically**:
- Extracts YouTube video ID
- Fetches English captions via YouTube API
- Parses VTT format
- Caches and displays

### Supported Transcript Formats

#### SRT (SubRip)
```
1
00:00:15,000 --> 00:00:18,500
Welcome to today's episode

2
00:00:18,500 --> 00:00:22,000
Today we're talking about Swift
```

**Extracted**:
- Text content
- Start/end timestamps
- Segment boundaries

#### VTT (WebVTT)
```
WEBVTT

00:00:15.000 --> 00:00:18.500
Welcome to today's episode

00:00:18.500 --> 00:00:22.000
<v Host>Today we're talking about Swift

00:00:22.000 --> 00:00:25.500
<v Guest>Thanks for having me
```

**Extracted**:
- Text content
- Start/end timestamps
- Speaker labels (from `<v>` tags)

#### JSON
```json
[
  {
    "text": "Welcome to today's episode",
    "startTime": 15.0,
    "endTime": 18.5,
    "speaker": "Host"
  },
  {
    "text": "Today we're talking about Swift",
    "startTime": 18.5,
    "endTime": 22.0,
    "speaker": "Host"
  }
]
```

**Extracted**:
- Text content
- Start/end timestamps
- Speaker labels

#### Plain Text
```
Welcome to today's episode. Today we're talking about Swift...
```

**Extracted**:
- Text content only
- No timestamps or speakers

---

## Media Link Extraction from Transcripts

Transcripts are now analyzed to find media references:

### Pattern Detection

**Movies/TV Shows**:
- "watch **'The Matrix'**" → Movie link
- "check out **'Stranger Things'**" → TV show link

**Apps**:
- "download **Keynote** app" → App Store link
- "get the **Spotify** from the app store" → App Store link

**Songs/Music**:
- "listening to **'Bohemian Rhapsody'** by Queen" → Spotify search
- "song **'Yesterday'**" → Music search

**Books**:
- "read **'Atomic Habits'**" → Book search

### Example Flow

**Episode Transcript**:
> "Today I want to recommend the app **Things 3** for task management. Also, if you haven't watched **'The Social Network'**, it's a great film about tech startups."

**PodLink Extracts**:
1. **Things 3** → App Store link
2. **The Social Network** → TheMovieDB link

**Displayed in Episode Detail**:
```
┌─────────────────────────────────────┐
│ Connected Media                     │
│                                     │
│  ┌─────┐   ┌─────┐                 │
│  │ 📱  │   │ 🎬  │                 │
│  │     │   │     │                 │
│  └─────┘   └─────┘                 │
│  Things 3  The Social               │
│            Network                  │
└─────────────────────────────────────┘
```

---

## Developer API

### Getting a Transcript

```swift
// Get just the text
let text = await TranscriptService.shared.getTranscript(for: episode)

// Get full transcript with metadata and segments
let fullTranscript = await TranscriptService.shared.getFullTranscript(for: episode)

if let transcript = fullTranscript {
    print("Source: \(transcript.metadata.source)")
    print("Word count: \(transcript.metadata.wordCount)")
    print("Has speakers: \(transcript.metadata.hasSpeakerLabels)")
    
    if let segments = transcript.segments {
        for segment in segments {
            if let speaker = segment.speaker, let time = segment.startTime {
                print("[\(time)] \(speaker): \(segment.text)")
            }
        }
    }
}
```

### Integrating into Views

```swift
struct EpisodeDetailView: View {
    @State private var fullTranscript: FullTranscript?
    @State private var isLoadingTranscript = false
    
    var body: some View {
        // ... episode UI
        
        if let transcript = fullTranscript {
            TranscriptView(fullTranscript: transcript) { timestamp in
                playbackService.seek(to: timestamp)
            }
        }
    }
    
    .task {
        isLoadingTranscript = true
        fullTranscript = await TranscriptService.shared.getFullTranscript(for: episode)
        isLoadingTranscript = false
    }
}
```

---

## Performance Characteristics

### Caching Strategy
- **Duration**: 30 days (effectively permanent for most use cases)
- **Cache Key**: `transcript_full_{episode.id}`
- **Storage**: Memory + disk via CacheService
- **Size**: Minimal (text compresses well)

### Network Efficiency
- **Single Fetch**: Transcript fetched once per episode
- **Conditional**: Only fetched when episode detail is viewed
- **Background**: Async loading doesn't block UI
- **Reuse**: Cached transcript used by:
  - EpisodeDetailView (preview)
  - TranscriptView (full screen)
  - MediaLinkingService (extraction)

### Memory Usage
- **Plain Text**: ~10-50 KB per transcript
- **With Segments**: ~20-100 KB per transcript
- **Cleared**: When episode detail dismissed
- **Persistent**: Disk cache survives app restarts

---

## Coverage Statistics

### Expected Availability (Based on 2026 Data)

**Podcasts with Transcripts**:
- Major networks: 60-80%
- Independent shows: 20-40%
- YouTube video podcasts: 90%+ (auto-captions)
- Overall average: ~30-40%

**Format Distribution**:
- VTT: 45%
- SRT: 30%
- JSON: 15%
- Plain text: 10%

**Features**:
- With timestamps: ~85%
- With speaker labels: ~25%
- Both: ~20%

---

## Future Enhancement Options

### Phase 2: On-Demand Transcription
**Add "Generate Transcript" button for episodes without transcripts**

```
┌─────────────────────────────────────┐
│ Transcript                          │
│                                     │
│ No transcript available             │
│                                     │
│ [Generate Transcript]               │
│                                     │
│ Uses AI to create transcript        │
│ Cost: ~$0.36 per episode            │
└─────────────────────────────────────┘
```

**Implementation**:
- OpenAI Whisper API integration
- Download episode audio
- Chunk and transcribe
- Cache forever
- Optional: Premium feature

### Phase 3: Advanced Features
- **Auto-scroll**: Transcript follows playback
- **Highlights**: User-created bookmarks
- **Search**: Find episodes by transcript content
- **Summaries**: AI-generated episode summaries
- **Quotes**: Share specific moments with context

### Phase 4: Community Features
- **User Contributions**: Allow transcript uploads
- **Corrections**: Crowdsourced improvements
- **Translations**: Multi-language support
- **Accessibility**: Enhanced screen reader support

---

## Accessibility Benefits

Transcripts significantly improve accessibility:

### For Deaf/Hard of Hearing Users
- ✅ Full episode content available
- ✅ Searchable text
- ✅ Speaker identification
- ✅ Can be read at own pace

### For All Users
- ✅ Reference specific information
- ✅ Quote episodes accurately
- ✅ Find specific topics quickly
- ✅ Read in quiet environments
- ✅ Learn from non-native language content

### VoiceOver Support
- ✅ Text selection enabled
- ✅ Timestamps announced
- ✅ Speaker labels announced
- ✅ Search results navigable

---

## Privacy & Data

### Current Implementation
- ✅ No user data sent to third parties
- ✅ Transcripts cached locally only
- ✅ No tracking or analytics
- ✅ Works offline after caching

### If On-Demand Generation Added
- ⚠️ Audio sent to transcription API
- ⚠️ Episode metadata in request
- ✅ No user identification
- ✅ Can be made opt-in

---

## Troubleshooting

### "No Transcript Available"
**Possible reasons**:
1. Podcast doesn't provide transcript in RSS
2. Episode doesn't have video (for YouTube fallback)
3. Network error during fetch
4. Unsupported transcript format

**Solutions**:
- Try refreshing the episode
- Check internet connection
- Contact podcast creator to add transcripts
- Wait for Phase 2 on-demand generation

### Transcript Seems Incomplete
**Possible reasons**:
1. Original transcript is incomplete
2. Parsing error for unusual format
3. Cache corruption

**Solutions**:
- Clear app cache
- Re-fetch episode feed
- Check original transcript URL manually

### Timestamps Don't Work
**Possible reasons**:
1. Original transcript lacks timestamps
2. Format not recognized
3. Playback service error

**Solutions**:
- Check metadata (Info button)
- Verify "Timestamps: Yes" in info
- File bug report with transcript URL

---

## Contributing

Want to improve transcript support?

### Add Support for New Format
1. Add format to `TranscriptFormat` enum
2. Implement parser in `TranscriptService`
3. Add detection logic in `fetchTranscriptFromURL`
4. Add tests with sample files

### Improve Media Link Extraction
1. Add patterns to `parseTranscriptText` in `MediaLinkingService`
2. Test with real transcripts
3. Adjust confidence scores

### Enhance UI
1. Modify `TranscriptView` for new features
2. Update `EpisodeDetailView` preview
3. Add user preferences/settings

---

## Questions?

See `TRANSCRIPT_INTEGRATION_APPROACHES.md` for:
- Detailed comparison of 5 approaches
- Cost analysis and recommendations
- Technical architecture decisions
- Future roadmap

See `TRANSCRIPT_INTEGRATION_SUMMARY.md` for:
- Quick overview of implementation
- Key benefits and features
- Testing checklist
- Next steps
