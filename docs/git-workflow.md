# Git Repository Structure

## Branch Overview

The repository has been established with a modern Git-Flow strategy optimized for continuous integration and single-developer workflow.

### Main Branches

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Production-ready code, tagged releases | Protected, requires PR + CI |
| `develop` | Integration branch for next release | Protected, requires PR + CI |

### Feature Branches (Ready for Development)

| Branch | Task | Epic |
|--------|------|------|
| `feature/project-bootstrap` | Task 1.1 - Project structure and dependencies | Bootstrap Infrastructure |
| `feature/simulation-clock` | Task 1.2 - 15Hz deterministic clock system | Bootstrap Infrastructure |
| `feature/event-bus` | Task 1.3 - Event bus communication system | Bootstrap Infrastructure |
| `feature/world-grid-system` | Task 2.1 - World state and 64x64 grid | Core Simulation Engine |
| `feature/need-system` | Task 3.1 - Need decay and character foundation | Need System |
| `feature/pathfinding-engine` | Task 6.1 - A* pathfinding implementation | Pathfinding Engine |
| `feature/isometric-rendering` | Task 7.1 - Isometric tile rendering | Rendering System |

## Workflow Summary

### Daily Development
```bash
# Start work on a feature
git checkout develop
git pull origin develop
git checkout feature/simulation-clock

# Keep branch updated
git rebase develop

# Push work
git push -u origin feature/simulation-clock
```

### Integration Process
1. **Draft PR** - Open as soon as branch is pushed
2. **CI Checks** - flutter analyze && flutter test must pass
3. **Code Review** - Self-review or peer review
4. **Squash Merge** - Merge into develop with clean history

### Release Process
```bash
# When develop is ready for release
git checkout develop
git checkout -b release/1.0.0

# Stabilize and fix bugs only
# Then merge to main and tag
git checkout main
git merge --no-ff release/1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"
```

## CI/CD Pipeline

### Continuous Integration (`.github/workflows/ci.yml`)
- **Triggers**: Push to main/develop, PRs to main/develop
- **Jobs**: 
  - Code analysis (`flutter analyze`)
  - Unit tests (`flutter test --coverage`)
  - Web build (on develop branch)
  - Desktop builds (on tags)

### Release Pipeline (`.github/workflows/release.yml`)
- **Triggers**: Git tags matching `v*`
- **Outputs**: Cross-platform binaries (Windows, macOS, Linux)
- **Distribution**: GitHub Releases with downloadable assets

## Next Steps

1. **Start with Bootstrap** - Begin with `feature/project-bootstrap`
2. **Follow Task Order** - Implement tasks sequentially as defined in tasks.md
3. **Maintain Quality** - Ensure CI passes and maintain ≥80% test coverage
4. **Document Progress** - Update README.md with current development status

## Repository Status

✅ **Complete Setup**
- Git repository initialized
- Branch structure established
- CI/CD pipelines configured
- Documentation created
- Feature branches ready

🚀 **Ready for Development**
- All foundation branches created
- Implementation plan defined
- Quality gates established
- Development workflow documented

The repository is now fully prepared for implementing the Sims-like game according to the specification and task breakdown.