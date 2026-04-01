import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart';
import '../../../models/todo.dart';
import '../../../models/goal.dart';
import '../../../shared/services/recommendation_engine.dart';

/// Recommendations Widget
///
/// Shows personalized recommendations based on velocity, alignment, and patterns
class RecommendationsWidget extends StatelessWidget {
  final List<Todo> todos;
  final List<Goal> goals;
  final int currentStreak;
  final double currentVelocity;
  final double previousVelocity;

  const RecommendationsWidget({
    super.key,
    required this.todos,
    required this.goals,
    required this.currentStreak,
    required this.currentVelocity,
    required this.previousVelocity,
  });

  @override
  Widget build(BuildContext context) {
    final topTodos = RecommendationEngine.getTopRecommendations(todos, goals, limit: 3);
    final weekdayPattern = RecommendationEngine.identifyWeekdayPattern(todos);
    final personalizedRec = RecommendationEngine.getPersonalizedRecommendation(
      todos,
      goals,
      currentStreak,
    );
    final velocityRec = RecommendationEngine.getVelocityRecommendation(
      currentVelocity,
      previousVelocity,
    );

    // If no recommendations, don't show widget
    if (topTodos.isEmpty && weekdayPattern == null && personalizedRec == null && velocityRec == null) {
      return const SizedBox.shrink();
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
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Smart Recommendations',
                style: GoogleFonts.comfortaa(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Personalized recommendation
          if (personalizedRec != null) ...[
            _buildRecommendationCard(
              icon: Icons.lightbulb_outline,
              iconColor: const Color(0xFFFFB700),
              message: personalizedRec,
            ),
            const SizedBox(height: 12),
          ],

          // Velocity recommendation
          if (velocityRec != null) ...[
            _buildRecommendationCard(
              icon: Icons.speed,
              iconColor: const Color(0xFF2196F3),
              message: velocityRec,
            ),
            const SizedBox(height: 12),
          ],

          // Weekday pattern
          if (weekdayPattern != null) ...[
            _buildRecommendationCard(
              icon: Icons.insights,
              iconColor: const Color(0xFF9C27B0),
              message: weekdayPattern,
            ),
            const SizedBox(height: 12),
          ],

          // Top todos to focus on
          if (topTodos.isNotEmpty) ...[
            Text(
              'Focus on these today:',
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.inkLight,
              ),
            ),
            const SizedBox(height: 8),
            ...topTodos.map((todo) => _buildTodoItem(todo, goals)),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Todo todo, List<Goal> goals) {
    final goal = goals.firstWhere(
      (g) => g.id == todo.goalId,
      orElse: () => goals.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  goal.title,
                  style: GoogleFonts.comfortaa(
                    fontSize: 10,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${todo.alignmentScore?.round()}%',
              style: GoogleFonts.comfortaa(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF43A047),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
