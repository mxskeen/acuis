/// Task Status Enum
///
/// Extends beyond boolean completed to track the full task lifecycle.
/// ADHD-friendly: Rewards initiation (inProgress) not just completion.
enum TaskStatus {
  pending, // Not started
  inProgress, // User tapped "Start" or spent >30s on task
  completed, // Done
  abandoned, // Explicitly gave up (for stats)
}

/// Extension to get display names and colors
extension TaskStatusExtension on TaskStatus {
  String get displayName => switch (this) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
        TaskStatus.abandoned => 'Abandoned',
      };

  /// Check if task is considered "done" (completed or abandoned)
  bool get isDone => this == TaskStatus.completed || this == TaskStatus.abandoned;

  /// Check if task is active (in progress)
  bool get isActive => this == TaskStatus.inProgress;

  /// Check if task can be started
  bool get canStart => this == TaskStatus.pending;

  /// Check if task can be completed
  bool get canComplete => this == TaskStatus.inProgress || this == TaskStatus.pending;
}

/// Conversion helpers for backward compatibility
class TaskStatusConverter {
  /// Convert boolean completed to TaskStatus
  static TaskStatus fromCompleted(bool completed) {
    return completed ? TaskStatus.completed : TaskStatus.pending;
  }

  /// Convert TaskStatus to boolean (for backward compatibility)
  static bool toCompleted(TaskStatus status) {
    return status == TaskStatus.completed;
  }
}
