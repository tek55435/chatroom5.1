#!/bin/bash

# Build the Flutter web app with our changes
cd ./flutter_client

# Check if Flutter is available
if command -v flutter &> /dev/null; then
  echo "Building Flutter web app..."
  flutter build web
  
  # Copy to server directory for App Engine deployment
  mkdir -p ../server/public
  cp -r build/web/* ../server/public/
  echo "Web app built and copied to server/public/"
else
  echo "Flutter command not found, copying existing build..."
  # Copy the existing build if Flutter is not available
  mkdir -p ../server/public
  cp -r build/web/* ../server/public/
fi
