# acuis

acuis is a cross-platform goal tracking app built with Flutter. You set goals, break them down into todos, and track how well your daily work actually connects to what you are trying to achieve.

Core features:

- Create short-term and long-term goals
- Manage todos and link them to specific goals
- AI-generated task suggestions based on your goals (powered by NVIDIA NIM / Mistral)
- Alignment scoring that shows how well your todos map to your goals
- Streak tracking to keep momentum
- Persistent local storage, no account required

## Requirements

- Flutter SDK (Dart ^3.11.3)
- For Android: Android SDK, min SDK 21
- For Windows: Visual Studio with the "Desktop development with C++" workload
- For Linux: standard build tools (clang, cmake, ninja, libgtk-3-dev)
- An NVIDIA NIM API key if you want AI alignment scoring and task generation

## Setup

Clone the repo and install dependencies:

```
cd acuis
flutter pub get
```

## Running on each platform

### Android

Connect a device or start an emulator, then:

```
flutter run -d android
```

Build a release APK:

```
flutter build apk
```

### Windows

```
flutter run -d windows
```

Build a release executable:

```
flutter build windows
```

### Linux

```
flutter run -d linux
```

Build a release binary:

```
flutter build linux
```

### Other platforms

iOS and macOS are not currently configured in this project.

## AI features setup

The alignment scoring and task generation use the NVIDIA NIM API with Mistral Small (119B). To enable them:

1. Get an API key from [https://build.nvidia.com](https://build.nvidia.com)
2. Open the app, go to the Alignment tab, tap the settings icon, and paste your key

The key is stored locally on device only.

## Project structure

```
lib/
  features/
    goals/        goal list and detail screens
    todos/        todo list screen
    alignment/    alignment screen and impact quadrant
  models/         data models (Goal, Todo)
  shared/
    services/     storage, streak, AI task generation, AI alignment
  main.dart       app entry, theme, navigation
  splash_screen.dart
assets/
  illustrations/  SVG assets
  icon.png
  splash_screen.png
  empty_state.png
```

## Contributing

1. Fork the repository and create a branch from `main`:

```
git checkout -b your-feature-name
```

2. Make your changes. Keep commits focused and descriptive.

3. Run the linter before opening a PR:

```
flutter analyze
```

4. Open a pull request against `main` with a clear description of what changed and why.

Keep PRs small and scoped to a single concern. If you are adding a new feature, discuss it in an issue first.
