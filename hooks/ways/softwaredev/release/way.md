---
keywords: release|deploy|version|changelog|tag
---
# Release Way

## Semantic Versioning
- MAJOR: breaking changes
- MINOR: new features, backward compatible
- PATCH: bug fixes, backward compatible

## Before Release
- All tests passing
- Changelog updated
- Version bumped
- Dependencies reviewed

## Changelog Format
```
## [X.Y.Z] - YYYY-MM-DD
### Added
### Changed
### Fixed
### Removed
```

## Release Checklist
1. Create release branch or tag
2. Update version numbers
3. Update changelog
4. Build and test
5. Tag the release
6. Deploy
7. Announce if needed
