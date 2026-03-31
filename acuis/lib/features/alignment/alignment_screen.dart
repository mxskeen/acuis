import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import 'widgets/impact_quadrant.dart';
import '../../shared/services/ai_alignment_service.dart';
import '../../shared/services/storage_service.dart';

class AlignmentScreen extends StatefulWidget {
  final List<Goal> goals;
  final List<Todo> todos;
  final VoidCallback onDataChanged;
  
  const AlignmentScreen({
    super.key,
    required this.goals,
    required this.todos,
    required this.onDataChanged,
  });

  @override
  State<AlignmentScreen> createState() => _AlignmentScreenState();
}

class _AlignmentScreenState extends State<AlignmentScreen> {
  final _storage = StorageService();
  bool _isAnalyzing = false;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = _storage.loadApiKeySync() ?? '';
  }

  Future<void> _analyze() async {
    if (_apiKey.isEmpty) {
      _showSettingsSheet(context);
      return;
    }

    setState(() => _isAnalyzing = true);
    
    try {
      final service = AIAlignmentService(apiKey: _apiKey);
      final results = await service.analyzeAll(widget.todos, widget.goals);
      
      // Update todos with new scores/explanations
      for (int i = 0; i < widget.todos.length; i++) {
        final todo = widget.todos[i];
        if (results.containsKey(todo.id)) {
          widget.todos[i] = todo.copyWith(
            alignmentScore: results[todo.id]!.score,
            alignmentExplanation: results[todo.id]!.explanation,
          );
        }
      }
      widget.onDataChanged(); // saves to storage
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedTodos = widget.todos.where((t) => t.goalId != null).toList();
    final scoredTodos = linkedTodos.where((t) => t.alignmentScore != null).toList();
    
    double overallScore = 0;
    if (scoredTodos.isNotEmpty) {
      overallScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.goals.isEmpty || widget.todos.isEmpty)
              _buildEmpty()
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _buildScoreCard(overallScore, scoredTodos.length, linkedTodos.length),
                    const SizedBox(height: 36),
                    ImpactQuadrant(todos: widget.todos),
                    const SizedBox(height: 36),
                    Text('Goals Breakdown',
                        style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 12),
                    ...widget.goals.map(_buildGoalStatsCard),
                    const SizedBox(height: 24),
                    _buildAnalyzeButton(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alignment',
                      style: GoogleFonts.comfortaa(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.1,
                      )),
                  const SizedBox(height: 3),
                  Text('How your work connects to your goals',
                      style: GoogleFonts.comfortaa(
                          fontSize: 12, color: AppColors.inkLight)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showSettingsSheet(context),
              icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics_outlined, size: 64, color: AppColors.border),
              const SizedBox(height: 20),
              Text('Not enough data',
                  style: GoogleFonts.comfortaa(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkLight,
                  )),
              const SizedBox(height: 4),
              Text('Add goals and link todos to see alignment',
                  style: GoogleFonts.comfortaa(
                      fontSize: 12, color: AppColors.inkFaint)),
            ],
          ),
        ),
      );

  Widget _buildScoreCard(double score, int scoredCount, int linkedCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.bg,
                  valueColor: const AlwaysStoppedAnimation(AppColors.ink),
                ),
                Center(
                  child: Text(
                    '${score.round()}%',
                    style: GoogleFonts.comfortaa(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Alignment',
                    style: GoogleFonts.comfortaa(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 6),
                Text('$scoredCount of $linkedCount linked todos analyzed',
                    style: GoogleFonts.comfortaa(
                        fontSize: 12, color: AppColors.inkFaint, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStatsCard(Goal goal) {
    final goalTodos = widget.todos.where((t) => t.goalId == goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;
    
    final scoredTodos = goalTodos.where((t) => t.alignmentScore != null).toList();
    double avgScore = 0;
    if (scoredTodos.isNotEmpty) {
      avgScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Text(goal.title,
                    style: GoogleFonts.comfortaa(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              if (scoredTodos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${avgScore.round()}% aligned',
                      style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkLight)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11, color: AppColors.inkFaint)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: goalTodos.isEmpty ? 0 : completed / goalTodos.length,
                        minHeight: 4,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.ink),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$completed of ${goalTodos.length} todos done',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkLight)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _analyze,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isAnalyzing ? AppColors.chip : AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _isAnalyzing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkLight),
                )
              : Text('Refresh Analysis',
                  style: GoogleFonts.comfortaa(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final keyCtrl = TextEditingController(text: _apiKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            Text('NVIDIA NIM Settings',
                style: GoogleFonts.comfortaa(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Enter your NVIDIA API key to enable AI alignment scoring using Mistral Fast (119B).',
                style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight, height: 1.4)),
            const SizedBox(height: 20),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'NVIDIA API Key (nvapi-...)',
                hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final key = keyCtrl.text.trim();
                await _storage.saveApiKey(key);
                setState(() => _apiKey = key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text('Save Key',
                      style: GoogleFonts.comfortaa(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
