import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart';
import '../../../models/todo.dart';
import '../../../shared/services/velocity_service.dart';

/// Velocity Insights Widget
///
/// Shows velocity comparisons and productivity insights
class VelocityInsights extends StatelessWidget {
  final List<Todo> todos;
  final VelocityService velocityService;

  const VelocityInsights({
    super.key,
    required this.todos,
    required this.velocityService,
  });

  @override
  Widget build(BuildContext context) {
    final thisWeekVelocity = velocityService.getVelocity(7);
    final lastWeekVelocity = velocityService.getVelocity(14) - thisWeekVelocity;

    double percentChange = 0;
    if (lastWeekVelocity > 0) {
      percentChange = ((thisWeekVelocity - lastWeekVelocity) / lastWeekVelocity) * 100;
    }

    final isImproving = percentChange > 0;
    final bestDay = _getBestDay();
    final bestTime = _getBestTimeOfDay();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Velocity Insights',
            style: GoogleFonts.comfortaa(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),

          // Week over week comparison
          _buildInsightRow(
            icon: isImproving ? Icons.trending_up : Icons.trending_down,
            iconColor: isImproving ? const Color(0xFF43A047) : const Color(0xFFE53935),
            title: 'This week vs last week',
            value: '${percentChange.abs().toStringAsFixed(0)}% ${isImproving ? 'faster' : 'slower'}',
          ),

          const SizedBox(height: 12),

          // Best day
          if (bestDay != null)
            _buildInsightRow(
              icon: Icons.calendar_today,
              iconColor: const Color(0xFF2196F3),
              title: 'Your best day',
              value: bestDay,
            ),

          const SizedBox(height: 12),

          // Best time
          if (bestTime != null)
            _buildInsightRow(
              icon: Icons.access_time,
              iconColor: const Color(0xFF9C27B0),
              title: 'Peak productivity',
              value: bestTime,
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.comfortaa(
                  fontSize: 11,
                  color: AppColors.inkFaint,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.comfortaa(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _getBestDay() {
    final dayCompletions = <String, int>{};
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (final todo in todos.where((t) => t.completed)) {
      final dayIndex = todo.createdAt.weekday - 1;
      final dayName = days[dayIndex];
      dayCompletions[dayName] = (dayCompletions[dayName] ?? 0) + 1;
    }

    if (dayCompletions.isEmpty) return null;

    final bestEntry = dayCompletions.entries.reduce((a, b) => a.value > b.value ? a : b);
    return bestEntry.key;
  }

  String? _getBestTimeOfDay() {
    final timeCompletions = <String, int>{
      'Morning (6am-12pm)': 0,
      'Afternoon (12pm-6pm)': 0,
      'Evening (6pm-12am)': 0,
      'Night (12am-6am)': 0,
    };

    for (final todo in todos.where((t) => t.completed)) {
      final hour = todo.createdAt.hour;
      if (hour >= 6 && hour < 12) {
        timeCompletions['Morning (6am-12pm)'] = timeCompletions['Morning (6am-12pm)']! + 1;
      } else if (hour >= 12 && hour < 18) {
        timeCompletions['Afternoon (12pm-6pm)'] = timeCompletions['Afternoon (12pm-6pm)']! + 1;
      } else if (hour >= 18 && hour < 24) {
        timeCompletions['Evening (6pm-12am)'] = timeCompletions['Evening (6pm-12am)']! + 1;
      } else {
        timeCompletions['Night (12am-6am)'] = timeCompletions['Night (12am-6am)']! + 1;
      }
    }

    final bestEntry = timeCompletions.entries.reduce((a, b) => a.value > b.value ? a : b);
    return bestEntry.value > 0 ? bestEntry.key : null;
  }
}
