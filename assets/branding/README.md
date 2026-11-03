Branding Assets
===============

Files:
- logo_mark.svg – Primary symbol (wing + bolt) with gradient.
- logo_mark_monochrome.svg – Single-color glyph for small sizes / notification contexts.
- logo_lockup_dark.svg – Horizontal lockup (mark + wordmark) for splash/marketing.
- icon_background.svg – Adaptive icon background gradient (Android).

Next Steps:
1. Export icon_foreground.png from logo_mark.svg at 432x432 (transparent) and place alongside these files as icon_foreground.png.
2. (Optional) Export iOS marketing icon 1024x1024 from the same.
3. Run:
   flutter pub get
   flutter pub run flutter_launcher_icons

Header Integration:
Use flutter_svg to render `logo_mark.svg` or `logo_lockup_dark.svg` in app.
