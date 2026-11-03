## Driver UI Revamp Roadmap (Sept 2025)

Phase 1 (DONE):
- Design tokens + `DriverDesign` ThemeExtension scaffold.
- Availability Orb (animated pulse) replacing offline pill.
- Command Rail (collapsible) replacing floating fab stack.
- Insight Panel placeholder for future carousel.
- Refactored `DriverHomeScreen` layering (map + rail + orb + bottom panel).

Phase 2 (Planned):
1. Insight Panel Carousel
   - Panels: Demand Forecast (hour bars), Earnings Pace, Availability Tools.
   - Horizontal pager + snap; small dot / segmented indicator.
   - Integrate orb tap -> jump to Availability panel.
2. Availability Orb Enhancements
   - Long press radial: Extend 30m / 1h / Custom / Go Offline.
   - Probability pulse ring (outer ripple: demand > threshold).
3. Metrics Micro Strip (top-right overlay or integrate into rail on expand)
   - Acceptance %, Active Time, Earnings Pace vs median.
4. Demand Bloom Layer
   - Soft radial gradients anchored to cluster centroids (mock algorithm initially).
   - Toggle via rail.
5. Map Interaction Polish
   - User pan sets camera lock icon state on orb; auto rearm countdown subtle arc.
6. Drawer Slimming / Replacement
   - Convert heavy drawer into overlay sheet with sections collapsed by default.

Phase 3 (Exploratory):
- Temporal Scrub (Now → +4h) animating demand bloom.
- Smart Recommendations: Zone shift card with delta % and travel time.
- Adaptive Theme shift (dawn/dusk ambient accent rotation).
- Offer Intake Non-Modal: mini sliding card near orb, expand on tap.

Engineering Notes:
- Consider lightweight state mgmt (Riverpod) to isolate map rebuild triggers.
- Orb + demand bloom should be RepaintBoundary isolated.
- Heat/bloom generation: start with deterministic seeded noise * demand scalar.

Telemetry To Add:
- orb_tap / orb_long_press
- rail_toggle_expand
- insight_panel_view (panel_id, from_auto_rotate?)
- demand_layer_toggle

Success Metrics:
- Map flicker remains zero (platform view recreation count stable).
- Reduced cognitive friction: < 2 taps to extend availability.
- Panel interaction: >= 60% of sessions view more than one panel.

### Polish Pass (Phase 1.1)
- CommandRail: gradient + translucency, expanded width tweak, circular icon gradients, improved toggle chevron container, spacing adjustments.
- AvailabilityOrb: reduced footprint (108→core 78), spectral rotating highlight, refined progress arc, animated builder for lower rebuild overhead, improved typography & subtle border.
- InsightPanel wrapper: visually elevated container preparing for carousel conversion.
- Debug overlay toggle: long-press orb to show/hide instrumentation.
- DesignTokens: added blur scales & panel / accent gradients for future reuse.

Next Micro-Polish Ideas:
- Add subtle entrance animation (fade/slide) for InsightPanel.
- Introduce mini metrics strip chip row (Acceptance %, Earnings Pace, Active Time) above panel when online.
- Replace Drawer with modal sheet styled by gradientPanel + grouped collapsibles.