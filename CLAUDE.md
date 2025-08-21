# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tennis Trainer is a SwiftUI-based iOS application for tennis pose training. The project is currently in initial development with basic boilerplate code.

## Project Structure

- `Tennis Trainer/Tennis Trainer/` - Main app source code
  - `Tennis_TrainerApp.swift` - App entry point using SwiftUI App lifecycle
  - `ContentView.swift` - Main view (currently displays placeholder "Hello, world!")
  - `Assets.xcassets/` - App assets including app icon and accent colors
- `Tennis Trainer/Tennis TrainerTests/` - Unit tests using Swift Testing framework
- `Tennis Trainer/Tennis TrainerUITests/` - UI tests using XCTest/XCUITest

## Development Commands

### Building and Running
```bash
# Build the project
cd "Tennis Trainer" && xcodebuild -scheme "Tennis Trainer" -configuration Debug build

# Build for release
cd "Tennis Trainer" && xcodebuild -scheme "Tennis Trainer" -configuration Release build

# Clean build folder
cd "Tennis Trainer" && xcodebuild clean

# Run tests
cd "Tennis Trainer" && xcodebuild test -scheme "Tennis Trainer" -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Project Information
```bash
# List available schemes and targets
cd "Tennis Trainer" && xcodebuild -list
```

## Architecture Notes

- Uses SwiftUI with the modern App lifecycle (iOS 14+)
- Unit tests use Swift Testing framework (not XCTest)
- UI tests use traditional XCTest/XCUITest framework
- No external dependencies or Swift Package Manager packages currently configured
- Standard Xcode project structure with separate targets for app, unit tests, and UI tests

## Testing

- Unit tests: Located in `Tennis TrainerTests/` using Swift Testing framework
- UI tests: Located in `Tennis TrainerUITests/` using XCTest framework
- Run tests via Xcode or xcodebuild command line tools