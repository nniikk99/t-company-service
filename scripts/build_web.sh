#!/bin/bash

# Flutter Web Build Script for Vercel
echo "🚀 Starting Flutter web build for Vercel..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Copy supabase config
echo "🔧 Setting up Supabase configuration..."
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart

# Build for web
echo "🏗️ Building Flutter web application..."
flutter build web --release --base-href /

# Copy built files to root for Vercel
echo "📁 Copying built files to root directory..."
cp -r build/web/* .

# Create 404.html for SPA routing
echo "🔄 Creating 404.html for SPA routing..."
cp index.html 404.html

echo "✅ Build completed successfully!"
echo "📁 Files ready for Vercel deployment"
