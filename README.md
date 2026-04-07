# Acuis

Acuis is a cross-platform goal tracking app built with Flutter. You set goals, break them down into todos, and track how well your daily work actually connects to what you are trying to achieve.

## Core Features

- **Goal Management** - Create short-term (1-3 months) and long-term (6-12 months) goals with target dates and milestones
- **Task Tracking** - Manage todos and link them to specific goals with effort estimates
- **AI-Powered Task Generation** - Get smart task suggestions based on your goals using SMART criteria and BJ Fogg's Tiny Habits methodology (powered by NVIDIA NIM / Mistral)
- **Science-Backed Alignment Scoring** - See how well your todos map to your goals using established behavioral science frameworks
- **Eisenhower Matrix** - Prioritize tasks by urgency and importance with the proven time-management system
- **Velocity Tracking** - Track your completion rate and get realistic predictions for goal completion
- **Streak Tracking** - Maintain momentum with daily completion streaks
- **Achievements & Celebrations** - Earn points, level up, and unlock achievements as you progress
- **Persistent Local Storage** - No account required, your data stays on your device

## Scientific Foundations

Acuis is built on established behavioral science and productivity research:

### SMART Goals Framework
Every task is evaluated against SMART criteria:
- **S**pecific - Clear, action-oriented objectives
- **M**easurable - Quantifiable progress indicators
- **A**chievable - Realistic given your constraints
- **R**elevant - Directly contributes to your goals
- **T**ime-bound - Has a clear timeframe

### Eisenhower Matrix
Tasks are classified into four quadrants based on urgency and importance:
1. **Do Now** - Urgent and Important (handle immediately)
2. **Schedule** - Not Urgent but Important (strategic planning)
3. **Delegate** - Urgent but Not Important (can be delegated)
4. **Eliminate** - Not Urgent and Not Important (consider dropping)

### Velocity-Based Forecasting
Inspired by Agile/Scrum methodology:
- Track your historical completion rate (tasks/day)
- Get rolling average predictions
- See confidence intervals (best/worst case scenarios)

### Goal Setting Theory (Locke & Latham)
Based on research showing that specific, challenging goals with feedback lead to higher performance:
- Clear progress visualization
- Regular feedback on alignment
- Commitment tracking

### Behavioral Psychology
Designed with evidence-based motivation principles:
- **Progress Visualization** - See your growth over time
- **Loss Aversion** - Streak tracking to maintain momentum
- **Variable Rewards** - Celebrations for achievements
- **Tiny Habits** - Start small, build momentum (BJ Fogg)

## Requirements

- Flutter SDK (Dart ^3.11.3)
- For Android: Android SDK, min SDK 21
- For Windows: Visual Studio with the "Desktop development with C++" workload
- For Linux: standard build tools (clang, cmake, ninja, libgtk-3-dev)
- An NVIDIA NIM API key for AI alignment scoring and task generation

## Setup

Clone the repo and install dependencies:

```
cd acuis
flutter pub get
```

## Running on Each Platform

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

### Other Platforms

iOS and macOS are not currently configured in this project.

## AI Features Setup

The alignment scoring and task generation use the NVIDIA NIM API with Mistral Small (119B). To enable them:

1. Get an API key from [https://build.nvidia.com](https://build.nvidia.com)
2. Open the app, go to the Alignment tab, tap the settings icon, and paste your key

The key is stored locally on device only.

## Project Structure

```
lib/
  features/
    goals/           goal list and detail screens
    todos/           todo list screen
    alignment/       alignment screen, Eisenhower quadrant, growth charts
  models/            data models (Goal, Todo, SMARTScores, VelocityPrediction)
  shared/
    services/
      scoring/       AI-powered alignment scoring with SMART criteria
      ai_alignment_service.dart
      ai_task_generator_service.dart
      velocity_service.dart      completion rate tracking
      gamification_service.dart  achievements and celebrations
      streak_service.dart
      storage_service.dart
    widgets/
      celebration_overlay.dart   animations for achievements
  main.dart          app entry, theme, navigation
  splash_screen.dart
assets/
  illustrations/     SVG assets
  icon.png
  splash_screen.png
  empty_state.png
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/smart_scores.dart` | SMART criteria scoring model |
| `lib/models/velocity_prediction.dart` | Completion prediction with confidence |
| `lib/shared/services/scoring/alignment_scorer.dart` | AI-powered SMART-based scoring |
| `lib/shared/services/velocity_service.dart` | Agile-style velocity tracking |
| `lib/features/alignment/widgets/eisenhower_quadrant.dart` | Eisenhower Matrix visualization |
| `lib/features/alignment/widgets/science_backed_growth_chart.dart` | Velocity-based progress chart |
| `lib/features/alignment/widgets/smart_radar_chart.dart` | SMART criteria radar visualization |
| `lib/shared/services/gamification_service.dart` | Achievements, points, celebrations |

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

## License

MIT License - see LICENSE file for details..
