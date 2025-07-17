# Contributing to Sims-Like Game

## Branch Strategy

We use a modern Git-Flow approach optimized for continuous integration:

### Main Branches

- **`main`** - Production-ready code only. All releases are tagged from here.
- **`develop`** - Integration branch for features. Next release preparation happens here.

### Supporting Branches

- **`feature/*`** - New features, improvements, or experiments
- **`hotfix/*`** - Critical fixes that need to go directly to main
- **`release/*`** - Release preparation and stabilization
- **`chore/*`** - Non-code work (docs, CI, tooling)

## Workflow

### Starting New Work

```bash
# Always start from develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/simulation-clock
git checkout -b feature/pathfinding-engine
git checkout -b chore/ci-setup
```

### Daily Development

```bash
# Keep your branch up to date
git checkout develop
git pull origin develop
git checkout feature/your-branch
git rebase develop

# Push your work
git push -u origin feature/your-branch
```

### Pull Request Process

1. **Open Draft PR Early** - Create draft PR as soon as you push your branch
2. **CI Must Pass** - All checks (flutter analyze, flutter test) must pass
3. **Code Review** - At least one approval required
4. **Squash & Merge** - Use squash merge to keep history clean

### Release Process

```bash
# Create release branch from develop
git checkout develop
git checkout -b release/1.0.0

# Stabilize, fix bugs only
# When ready:
git checkout main
git merge --no-ff release/1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"
git checkout develop
git merge --no-ff release/1.0.0
git branch -d release/1.0.0
```

### Hotfix Process

```bash
# Create hotfix from main
git checkout main
git checkout -b hotfix/critical-bug-fix

# Fix the issue, test thoroughly
# When ready:
git checkout main
git merge --no-ff hotfix/critical-bug-fix
git tag -a v1.0.1 -m "Hotfix version 1.0.1"
git checkout develop
git merge --no-ff hotfix/critical-bug-fix
git branch -d hotfix/critical-bug-fix
```

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(ai): add distance-weighted scoring to decision maker
fix(pathfinding): resolve infinite loop when no route exists
chore(ci): add flutter analyze job to GitHub Actions
docs(readme): update installation instructions
test(simulation): add unit tests for need decay system
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `chore`: Maintenance tasks
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `perf`: Performance improvements

### Scopes
- `ai`: AI decision system
- `pathfinding`: Pathfinding engine
- `simulation`: Core simulation logic
- `rendering`: Isometric rendering system
- `ui`: User interface components
- `audio`: Audio system
- `config`: Configuration system
- `save`: Save/load system
- `ci`: Continuous integration

## Code Quality

### Before Committing
```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Run tests
flutter test

# Check test coverage (aim for ≥80% on lib/core/)
flutter test --coverage
```

### Development Setup
```bash
# Install dependencies
flutter pub get

# Start build runner in watch mode
dart run build_runner watch --delete-conflicting-outputs

# Run on desktop
flutter run -d windows

# Run on web
flutter run -d chrome
```

## Project Structure

Follow the established architecture:

```
lib/
├── core/           # Pure Dart simulation (no Flutter deps)
├── presentation/   # Flutter/Flame UI and rendering
├── infra/         # Cross-cutting concerns (events, serialization)
└── main.dart      # App entry point
```

### Key Principles
- Keep simulation logic in `lib/core/` as pure Dart
- Use event bus for communication between layers
- Write comprehensive unit tests for core simulation
- Follow the component-based object system design

## Testing

- **Unit Tests**: Focus on `lib/core/` simulation logic
- **Integration Tests**: Save/load, cross-platform compatibility
- **Performance Tests**: AI, pathfinding, rendering benchmarks

Target: ≥80% test coverage for core simulation logic.

## Documentation

- Update relevant docs when adding features
- Include code examples in complex systems
- Document breaking changes in PR descriptions
- Keep steering documents in `.kiro/steering/` updated