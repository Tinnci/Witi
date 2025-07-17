# Project Structure

## Root Directory Layout
```
lib/
├── main.dart                 # Flutter app entry point
├── game/                     # Core game logic
│   ├── game.dart            # Main game class
│   ├── components/          # Flame components
│   ├── systems/             # Game systems (AI, pathfinding, etc.)
│   └── world/               # World representation
├── simulation/              # Pure Dart simulation engine
│   ├── sim.dart            # Sim character logic
│   ├── needs.dart          # Need system
│   ├── objects.dart        # Interactive objects
│   └── ai/                 # AI and decision making
├── ui/                     # Flutter UI components
│   ├── hud/                # In-game HUD
│   └── menus/              # Game menus
└── utils/                  # Shared utilities

assets/
├── images/                 # Sprites and textures
│   ├── tiles/              # Isometric floor/wall tiles
│   ├── objects/            # Furniture and interactive objects
│   └── characters/         # Character sprites and animations
├── data/                   # JSON configuration files
│   ├── objects.json        # Object definitions and behaviors
│   ├── needs.json          # Need types and parameters
│   └── maps/               # Level/lot definitions
└── audio/                  # Sound effects and music

test/
├── simulation_test.dart    # Unit tests for simulation logic
├── pathfinding_test.dart   # Pathfinding algorithm tests
└── integration_test/       # Integration tests
```

## Key Architectural Principles

### Simulation Engine Separation
- Keep core simulation logic in `lib/simulation/` as pure Dart
- No Flutter/Flame dependencies in simulation layer
- Enables easy testing and potential engine migration

### Component-Based Game Objects
- Use Flame's component system for visual game objects
- Each interactive object has both a visual component and simulation data
- Components handle rendering, simulation handles logic

### Data-Driven Configuration
- Object behaviors defined in JSON files under `assets/data/`
- Hot-reloadable configurations for rapid iteration
- Separate data from code for easier content creation

### Isometric Rendering
- 45-degree isometric view using Flame's rendering capabilities
- Tile-based world with fixed grid positioning
- Layered rendering for proper depth sorting