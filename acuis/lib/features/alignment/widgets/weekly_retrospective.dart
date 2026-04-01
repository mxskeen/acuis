import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/todo.dart';
import '../../models/goal.dart';

/// Weekly Retrospective Widget
///
/// Shows weekly summary with completed todos, alignment percentage, and trends
class WeeklyRetrospective extends StatelessWidget {
  final List<Todo> todos;
  final List<Goal> goals;

  const WeeklyRetrospective({
    super.key,
    required this.todos,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weekTodos = todos.where((t) {
      return t.createdAt.isAfter(weekStart) && t.createdAt.isBefore(weekEnd);
    }).toList();

    final completedThisWeek = weekTodos.where((t) => t.completed).length;
    final linkedTodos = weekTodos.where((t) => t.goalId != null).toList();
    final scoredTodos = linkedTodos.where((t) => t.alignmentScore != null).toList();

    double avgAlignment = 0;
    if (scoredTodos.isNotEmpty) {
      avgAlignment = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

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
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'This Week',
                style: GoogleFonts.comfortaa(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getWeekRange(weekStart, weekEnd),
                  style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Completed',
                  value: '$completedThisWeek',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Alignment',
                  value: '${avgAlignment.round()}%',
                  icon: Icons.track_changes,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Total Tasks',
                  value: '${weekTodos.length}',
                  icon: Icons.list_alt,
                  color: const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Completion',
                  value: weekTodos.isEmpty ? '0%' : '${((completedThisWeek / weekTodos.length) * 100).round()}%',
                  icon: Icons.trending_up,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),

          if (completedThisWeek > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getEncouragementMessage(completedThisWeek),
                      style: GoogleFonts.comfortaa(
                        fontSize: 12,
                        color: const Color(0xFF2E7D32),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.comfortaa(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.comfortaa(
              fontSize: 10,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekRange(DateTime start, DateTime end) {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[start.month]} ${start.day} - ${months[end.month]} ${end.day}';
  }

  String _getEncouragementMessage(int completed) {
    if (completed >= 20) return 'Incredible week! You\'re crushing your goals 🚀';
    if (completed >= 10) return 'Great week! Keep up the momentum';
    if (completed >= 5) return 'Solid progress this week!';
    return 'Good start! Keep building momentum';
  }
}
