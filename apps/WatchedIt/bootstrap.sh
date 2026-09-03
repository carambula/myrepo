#!/bin/bash

# Bootstrap script to fetch Rewatchables episodes before building
# This is informational - the actual bootstrap happens on first app launch

echo "📡 Fetching Rewatchables episodes..."
swift bootstrap_movies.swift

echo ""
echo "✅ Bootstrap complete. The app will populate the database on first launch."

