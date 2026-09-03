#!/bin/bash

# Script to enhance bootstrap data with movie metadata from APIs
# This fetches genres, RT scores, MPAA ratings, and release dates from TMDB and OMDb

echo "🔄 Enhancing bootstrap data with movie metadata..."
echo "📡 This will fetch data from TMDB and Rotten Tomatoes APIs"
echo "⏱️  This may take several minutes depending on the number of movies..."
echo ""

swift enhance_bootstrap.swift

echo ""
echo "✅ Bootstrap enhancement complete!"
echo "📦 Enhanced bootstrap_movies.json is ready to use"

