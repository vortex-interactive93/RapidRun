# Changelog

## [Unreleased]
### Added
- Runtime health gating (connectivity + location) with `RuntimeStatusBanner`.
- Stage Sheet architecture (`DriverStageController`, `DriverStageSheet`) for offer lifecycle.
- Legacy multi-offer queue reintroduced behind `enableLegacyOfferQueue` flag (badge, overlay, bottom sheet).
- Accessibility semantics for availability and command palette controls.
- Performance instrumentation (rebuild counters) for Driver Home and Stage Sheet.
- Release process documentation (`RELEASE_CHECKLIST.md`).

### Changed
- Clean rebuild of `DriverHomeScreen` after legacy corruption; minimized baseline structure.

### Fixed
- Gating prevents accepting/declining offers while offline or missing permissions.

### Safeguards
- Assertion + warning when both `enableStageSheet` and `enableLegacyOfferQueue` are true (Stage Sheet precedence).

---

## Template for Future Releases
### Added
- 
### Changed
- 
### Fixed
- 
### Removed
- 
### Security
- 
