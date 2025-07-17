# Technology Stack

## Core Technologies
- **Language**: Dart
- **Framework**: Flutter (cross-platform UI)
- **Game Engine**: Flame (2D game framework)
- **Build System**: Flutter SDK build tools
- **Package Manager**: pub (Dart's package manager)

## Key Dependencies
```yaml
dependencies:
  flame: ^1.17.0           # 2D game framework
  flame_forge2d: ^0.14.0   # Physics (optional)
  pathfinding: ^0.3.1      # A* pathfinding implementation
```

## Development Commands
```bash
# Install dependencies
flutter pub get

# Run on desktop (Windows)
flutter run -d windows

# Run on web with hot reload
flutter run -d chrome

# Build for release
flutter build windows
flutter build web

# Run tests
flutter test

# Format code
dart format .

# Analyze code
flutter analyze
```

## Architecture Patterns
- **Separation of Concerns**: Keep simulation logic separate from rendering
- **Component-Based**: Use Flame's component system for game objects
- **Data-Driven**: JSON configuration for objects, needs, and behaviors
- **Hot Reload**: Structure code to support Flutter's hot reload

## Performance Considerations
- Use Isolates for heavy AI computations
- Implement object pooling for frequently created/destroyed objects
- Optimize sprite batching for isometric tiles
- Consider LOD (Level of Detail) for distant objects