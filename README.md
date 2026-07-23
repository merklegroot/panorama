# Panorama

A respectable file explorer — Windows Explorer–inspired browsing for the desktop.

![Screenshot](img/screenshot.png)

## Flutter desktop (current)

The app lives in [`flutter_app/`](flutter_app/) and targets **macOS**, **Windows**, and **Linux**.

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

Release build:

```bash
cd flutter_app
flutter build macos
# → flutter_app/build/macos/Build/Products/Release/Panorama.app
```

Notes are still stored at `notes/improvements.json` in the repo root (same path the Cursor improvement-notes skill expects).

Spotlight launcher (`npm run install:mac`) opens the Flutter build at `flutter_app/build/macos/Build/Products/Release/Panorama.app` (falls back to Debug). Re-run install after changing the launcher script.

### Feature parity

- Dual-pane browsing, list/grid views, Quick Access locations
- Cut / copy / paste, rename, new folder, trash
- Open, Open with… (macOS), Show in Finder
- Drag-and-drop import from Finder
- Notes panel backed by `notes/improvements.json`
- Hidden title bar via `window_manager`

## Electron (legacy)

The original Electron + React app remains at the repo root (`npm run dev`). Prefer the Flutter app for ongoing work.
