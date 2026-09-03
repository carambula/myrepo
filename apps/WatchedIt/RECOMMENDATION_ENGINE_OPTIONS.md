# On-Device Recommendation Engine Options for WatchedIt

This document outlines various approaches for building a local, on-device recommendation engine for your movie app.

## Overview

Your app has rich data available for recommendations:
- **Movie metadata**: Genres, directors, cast, year, MPAA rating
- **External signals**: RT scores (when available), podcast presence (Rewatchables)
- **User behavior**: `isRewatched`, `isListened`, `isSaved`
- **Streaming availability**: Which services have the movie

## Option 1: Content-Based Filtering (✅ Implemented)

**Status**: Basic implementation created in `MovieRecommendationService.swift`

### How It Works
- Builds a user profile from watched movies (genres, directors, cast, years, etc.)
- Scores candidate movies based on similarity to user profile
- Uses weighted scoring across multiple features

### Pros
- ✅ Works immediately with any amount of data
- ✅ No training required
- ✅ Privacy-friendly (all on-device)
- ✅ Interpretable (can show reasons for recommendations)
- ✅ Fast and lightweight
- ✅ Easy to customize weights

### Cons
- ⚠️ Doesn't learn from user feedback automatically
- ⚠️ May recommend similar movies (less diversity)
- ⚠️ Requires manual tuning of weights

### Implementation Details
The service calculates similarity scores based on:
- **Genre overlap** (Jaccard similarity)
- **Director matches** (weighted by frequency)
- **Cast member matches** (weighted by position and frequency)
- **Year preference** (decay function for era similarity)
- **MPAA rating preference**
- **Podcast presence** (boost if user listens to podcasts)
- **Streaming availability** (boost if on user's preferred services)

### Usage Example
```swift
let recommendations = await MovieRecommendationService.shared.generateRecommendations(
    modelContext: modelContext,
    maxResults: 20
)
```

### Customization
You can adjust weights to emphasize different features:
```swift
var weights = RecommendationWeights()
weights.directorWeight = 4.0  // Emphasize director matches
weights.genreWeight = 1.5     // Reduce genre importance
weights.podcastPresenceWeight = 3.0  // Boost podcast movies

let recommendations = generateRecommendations(
    watchedMovies: watched,
    candidateMovies: candidates,
    weights: weights
)
```

---

## Option 2: Core ML / Create ML

### How It Works
- Train a machine learning model (neural network, tree ensemble, etc.) using Create ML
- Export model to Core ML format
- Run inference on-device using Core ML framework

### Pros
- ✅ Can learn complex patterns
- ✅ Can improve with more training data
- ✅ Apple-optimized for iOS devices
- ✅ Supports on-device training (iOS 15+)

### Cons
- ⚠️ Requires training data (may need to bootstrap)
- ⚠️ Model size considerations (10-50MB typical)
- ⚠️ More complex to implement
- ⚠️ Harder to debug/interpret

### Implementation Approach
1. **Collect training data**: Use your bootstrap dataset or aggregate user data
2. **Feature engineering**: Extract features from movies (genres, cast, etc.)
3. **Train model**: Use Create ML to train a recommendation model
4. **Export to Core ML**: Convert model for on-device use
5. **Integrate**: Use Core ML framework to run predictions

### Training Data Format
You'd need examples like:
```swift
struct TrainingExample {
    let movieFeatures: [Double]  // Genre one-hot, director ID, cast IDs, etc.
    let userFeatures: [Double]   // User's genre preferences, etc.
    let label: Double            // 1.0 if user watched, 0.0 if not
}
```

### Model Types
- **Neural Network**: Good for complex patterns, but larger model size
- **Tree Ensemble**: Interpretable, smaller, good for structured data
- **Linear/Logistic Regression**: Simple, fast, small

---

## Option 3: Vector Similarity / Embeddings

### How It Works
- Generate embeddings (dense vectors) for movies based on their features
- Use cosine similarity to find movies with similar embeddings
- Can use pre-trained embeddings or generate your own

### Pros
- ✅ Captures semantic similarity well
- ✅ Efficient similarity search
- ✅ Can combine multiple signals into single vector
- ✅ Works well with large candidate sets

### Cons
- ⚠️ Requires embedding generation/storage
- ⚠️ Less interpretable than content-based
- ⚠️ May need external libraries or custom implementation

### Implementation Approaches

#### A. Simple Feature Embedding
Convert movie features to a normalized vector:
```swift
func movieToEmbedding(movie: Movie) -> [Double] {
    var embedding: [Double] = []
    
    // Genre one-hot encoding (normalized)
    let allGenres = getAllGenres()
    for genre in allGenres {
        embedding.append(movie.genres.contains(genre) ? 1.0 : 0.0)
    }
    
    // Director ID (one-hot)
    // Cast member IDs (one-hot)
    // Year (normalized)
    // RT score (normalized)
    
    return normalize(embedding)
}
```

#### B. Pre-trained Embeddings
Use embeddings from:
- **TMDB**: If they provide movie embeddings
- **Word2Vec/Glove**: For text-based similarity (overview, title)
- **Custom training**: Train embeddings on your data

#### C. Hybrid Approach
Combine content-based scoring with vector similarity for best results.

---

## Option 4: Hybrid Recommendation System

### How It Works
Combine multiple approaches:
1. **Content-based** (primary) - What we implemented
2. **Collaborative signals** - Podcast co-occurrence, trending movies
3. **User behavior** - Weight by `isRewatched` (user really liked it)
4. **Diversity boost** - Ensure variety in recommendations

### Implementation Strategy
```swift
func hybridRecommendation(movie: Movie, userProfile: UserProfile) -> Double {
    var score = 0.0
    
    // Content-based (70% weight)
    score += calculateContentScore(movie, userProfile) * 0.7
    
    // Collaborative signals (20% weight)
    score += calculateCollaborativeScore(movie, userProfile) * 0.2
    
    // Diversity boost (10% weight)
    score += calculateDiversityScore(movie, recentRecommendations) * 0.1
    
    return score
}
```

### Collaborative Signals You Could Use
- **Podcast co-occurrence**: Movies often discussed together in podcasts
- **Director filmography**: Other movies by same director
- **Cast filmography**: Other movies with same cast members
- **Genre clusters**: Movies that share multiple genres

---

## Option 5: Rule-Based / Heuristic System

### How It Works
Simple if-then rules based on user preferences:
- "If user watched 3+ action movies, recommend action movies"
- "If user listened to podcast about movie, recommend that movie"
- "If user saved movie, recommend similar movies"

### Pros
- ✅ Very simple to implement
- ✅ Easy to understand and debug
- ✅ Fast
- ✅ Good starting point

### Cons
- ⚠️ Limited sophistication
- ⚠️ Doesn't scale well with complexity
- ⚠️ Requires manual rule creation

### Example Implementation
```swift
func ruleBasedRecommendations(userMovies: [Movie]) -> [Movie] {
    var recommendations: [Movie] = []
    
    // Rule 1: If user listened to podcast, recommend that movie
    for movie in userMovies where movie.isListened {
        // Find similar movies
        recommendations.append(contentsOf: findSimilar(movie))
    }
    
    // Rule 2: If user watched 3+ movies by director, recommend other movies
    let directorCounts = countDirectors(userMovies)
    for (director, count) in directorCounts where count >= 3 {
        recommendations.append(contentsOf: getOtherMoviesByDirector(director))
    }
    
    return recommendations
}
```

---

## Option 6: Matrix Factorization (Advanced)

### How It Works
- Factorize user-movie interaction matrix
- Learn latent factors for users and movies
- Predict ratings/relevance for unseen movies

### Pros
- ✅ Can discover hidden patterns
- ✅ Good for sparse data
- ✅ Well-studied approach

### Cons
- ⚠️ Requires significant training data
- ⚠️ More complex to implement
- ⚠️ May need external libraries (Accelerate framework)
- ⚠️ Harder to run on-device efficiently

### Implementation
Would likely need:
- Custom matrix factorization implementation
- Or use Core ML with a trained model
- Or use Accelerate framework for linear algebra

---

## Recommendation: Start with Content-Based, Evolve to Hybrid

### Phase 1: Content-Based (Current)
✅ Implemented in `MovieRecommendationService.swift`
- Fast to implement
- Works with your existing data
- Good baseline

### Phase 2: Add Collaborative Signals
- Podcast co-occurrence matrix
- Director/cast filmography recommendations
- Genre cluster recommendations

### Phase 3: Add User Feedback Loop
- Track which recommendations users actually watch
- Adjust weights based on user behavior
- Learn user preferences over time

### Phase 4: Consider ML Model (Optional)
- If you have enough training data
- If content-based isn't sufficient
- Use Create ML to train a model

---

## Implementation Considerations

### Performance
- **Caching**: Cache user profile to avoid recalculating
- **Background processing**: Generate recommendations in background
- **Incremental updates**: Only recalculate when user watches new movie

### Privacy
- ✅ All processing on-device
- ✅ No data sent to servers
- ✅ User data stays private

### Data Requirements
- **Minimum**: 5-10 watched movies for decent recommendations
- **Optimal**: 20+ watched movies
- **Bootstrap**: Use your bootstrap dataset to seed recommendations

### User Experience
- Show **reasons** for recommendations (already implemented)
- Allow users to **dismiss** recommendations
- **Refresh** recommendations periodically
- **Diversity**: Ensure variety in recommendations

---

## Next Steps

1. **Test the current implementation** with your data
2. **Tune weights** based on what users actually watch
3. **Add collaborative signals** (podcast co-occurrence, etc.)
4. **Consider ML model** if you have enough training data
5. **Add user feedback** to improve over time

---

## Resources

- **Create ML**: https://developer.apple.com/machine-learning/create-ml/
- **Core ML**: https://developer.apple.com/machine-learning/core-ml/
- **Accelerate Framework**: For matrix operations
- **Natural Language Framework**: For text-based similarity

---

## Example: Adding RT Score Support

Currently RT scores aren't stored in the Movie model. To add them:

1. **Add RT score to Movie model**:
```swift
struct Movie {
    // ... existing fields
    let rtScore: Int? // Rotten Tomatoes score (0-100)
}
```

2. **Update recommendation service** to use RT scores:
```swift
// In calculateSimilarityScore:
if let rtScore = movie.rtScore, rtScore >= weights.rtScoreThreshold {
    let rtBoost = Double(rtScore) / 100.0
    score += rtBoost * weights.rtScoreWeight
}
```

3. **Fetch RT scores** when enriching movie data (if API available)

---

## Example: Adding Podcast Co-occurrence

Track which movies appear together in podcasts:

```swift
struct PodcastCoOccurrence {
    let movieId1: String
    let movieId2: String
    let coOccurrenceCount: Int // How many times they appear together
}

// In recommendation service:
func calculatePodcastCoOccurrenceScore(
    movie: Movie,
    watchedMovies: [Movie]
) -> Double {
    var score = 0.0
    for watched in watchedMovies {
        if let coOccurrence = getCoOccurrence(movie.id, watched.id) {
            score += Double(coOccurrence.coOccurrenceCount) * 0.5
        }
    }
    return score
}
```

This would boost movies that are often discussed together in podcasts the user listens to.





