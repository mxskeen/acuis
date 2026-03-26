# Acuis

A cross-platform goal tracking app with visual progress feedback through wallpaper clarity.

## Concept

Acuis helps you track your goals and daily todos with a unique visual feedback system. As you complete tasks aligned with your goals, your wallpaper becomes progressively clearer - transforming from blurred to crystal clear as you make progress.

## Features

- **Goal Management**: Create short-term and long-term goals
- **Todo Tracking**: Daily task management linked to your goals
- **AI Alignment Analysis**: Automatically analyzes how well your todos align with your goals
- **Visual Progress**: Wallpaper blur decreases as you complete aligned tasks
- **Glassmorphism UI**: Beautiful, modern interface with blur effects
- **Cross-Platform**: Works on Android, Linux, and Windows

## Tech Stack

- **Framework**: Flutter 3.41.5
- **Language**: Dart 3.11.3
- **AI Integration**: OpenAI API for alignment analysis
- **Platforms**: Android, Linux, Windows

## Project Structure

```
lib/
├── core/                    # Core utilities
├── features/
│   ├── goals/              # Goal management screens
│   ├── todos/              # Todo management screens
│   └── wallpaper/          # Wallpaper feature
├── models/                 # Data models (Goal, Todo, UserSettings)
├── shared/
│   ├── services/           # AI alignment, wallpaper services
│   └── widgets/            # Reusable widgets
└── main.dart               # App entry point
```

## Setup

1. Get dependencies:
   ```bash
   flutter pub get
   ```

2. Run on your platform:
   ```bash
   # Android
   flutter run -d android

   # Linux
   flutter run -d linux

   # Windows
   flutter run -d windows
   ```

## How It Works

1. **Set Goals**: Define your short-term and long-term objectives
2. **Add Todos**: Create daily tasks and link them to goals
3. **AI Analysis**: The app analyzes alignment between todos and goals
4. **Visual Feedback**: Complete tasks to make your wallpaper clearer
5. **Track Progress**: See your overall alignment score

## Next Steps

- Add persistent storage (SQLite/Hive)
- Implement settings screen for API key configuration
- Add wallpaper selection feature
- Implement real-time progress tracking
- Add notifications and reminders
- Create onboarding flow
