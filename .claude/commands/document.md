# Project Documentation Skill

Your job is to create or update the project documentation for this Flutter project. Follow these steps carefully and in order.

## Step 1 — Scan the project

Read the following files to understand the project:
- `pubspec.yaml` — app name, version, dependencies
- `lib/main.dart` — entry point, navigation structure
- All files under `lib/screens/` — each screen's purpose
- All files under `lib/models/` — data models
- All files under `lib/db/` or files named `*database*` — database schema and helpers
- All files under `lib/repositories/` — data access layer
- `lib/theme.dart` — design system colors and styles
- `lib/providers.dart` — state management providers (if exists)

## Step 2 — Check if documentation exists

Check whether `CLAUDE.md` exists at the project root.

- If `CLAUDE.md` **does not exist**, you will **create** it from scratch.
- If `CLAUDE.md` **exists**, you will **update** it — preserve any sections that are still accurate and rewrite sections that are outdated. Do not delete content that is still valid.

Also check `README.md`. If it still contains the Flutter boilerplate text ("A new Flutter project"), rewrite it with real project information.

## Step 3 — Write CLAUDE.md

Write (or update) `CLAUDE.md` with the following sections. Use the information you gathered in Step 1. Be specific — no placeholder text.

```
# <App Name> — Project Documentation

## Overview
One paragraph describing what the app does, who it is for, and its main value.

## Tech Stack
- Flutter version (from pubspec.yaml sdk constraint)
- State management: (e.g. Riverpod, Provider, Bloc)
- Local database: (e.g. sqflite)
- Key packages: list each with its purpose

## Project Structure
lib/
  main.dart          — <what it does>
  theme.dart         — <what it does>
  providers.dart     — <what it does, if present>
  models/            — <list each model and its fields>
  db/                — <database helper: tables, schema summary>
  repositories/      — <each repository and what data it manages>
  screens/           — <each screen: route name and purpose>

## Database Schema
For each table: name, columns, types, relationships.

## Navigation
Describe the bottom nav tabs and what index maps to which screen.

## Screens
For each screen file, write:
- **ScreenName** (`screens/screen_name.dart`) — what it shows, key interactions

## State Management
Describe how state is managed: which providers/notifiers exist, what data they hold.

## How to Run
Commands to run the app on each platform (Android, Windows, etc.)

## Known Warnings / Notes
List any known build warnings (e.g. deprecated Kotlin Gradle Plugin) or important caveats a developer should know.
```

## Step 4 — Update README.md

If `README.md` still has boilerplate content, replace it with:
- App name and one-line description
- How to install and run
- Link to `CLAUDE.md` for full developer documentation

## Step 5 — Report what you did

After writing the files, tell the user:
- Whether you **created** or **updated** each file
- A short summary of what changed
