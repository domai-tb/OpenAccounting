---
name: fvm
description: Use Flutter Version Manager (FVM) to configure, inspect, and run Flutter/Dart projects with reproducible per-project Flutter SDK versions.
---

# Flutter Version Manager Skill

## Purpose

Use this skill whenever a Flutter project uses, should use, or might need Flutter Version Manager (FVM). FVM pins the Flutter SDK version per project so builds, tests, IDE behavior, CI jobs, and developer environments use the same Flutter SDK.

This skill covers FVM usage inside application repositories. It does not cover converting Flutter projects, choosing Flutter architecture, or changing app code unless SDK version management affects the task.

## Core Concept

FVM is a CLI wrapper and cache manager for Flutter SDK versions. A project normally declares its desired Flutter SDK in `.fvmrc`. FVM then creates project-local links under `.fvm/` and routes `flutter` and `dart` commands through the configured SDK.

Important project files:

```text
.fvmrc                 # Commit this. Project SDK configuration.
.fvm/                  # Usually ignored. Local symlinks/cache metadata.
.fvm/flutter_sdk       # Symlink to the resolved Flutter SDK.
.vscode/settings.json  # May be auto-updated with dart.flutterSdkPath.
melos.yaml             # May be auto-updated with sdkPath in monorepos.