# PodLink Performance Checklist

Use this checklist before and after performance-focused changes.

## Baseline Capture

- Record a Time Profiler trace while scrolling:
  - Main feed grid and list.
  - Podcast detail episode list.
  - Search results and offline/history lists.
- Record Core Animation FPS and hitching while:
  - Audio playback is active.
  - Download states are changing.
  - Drag/reorder is active on the main grid.
- Verify touch latency on:
  - Main screen controls.
  - Row taps in list-heavy screens.
  - Search open/close and sheet transitions.

## Hot-Path Rules

- No disk reads in row/body computed properties.
- No per-cell geometry preference work unless drag mode is active.
- No full-list remap/reload from broad notifications.
- No expensive image decode at original source size for thumbnails.
- No synchronous iCloud sync in drag/scroll interaction paths.

## Regression Smoke Tests

- Reorder podcasts and relaunch: order persists.
- Playback progress continues to update and resume works.
- Download state updates still appear correctly in rows.
- Auto-queue still rebuilds with expected behavior.
- Pull-to-dismiss controls still function correctly in sheets.

