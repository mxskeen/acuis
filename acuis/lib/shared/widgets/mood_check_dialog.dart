import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/user_energy.dart';

/// Energy Check-in Dialog
///
/// ADHD-friendly mood/energy check-in:
/// - One-tap energy level selection
/// - Optional mood tags
/// - Can dismiss without selecting
/// - Encouraging copy, not demanding
class MoodCheckDialog extends StatefulWidget {
  final Function(EnergyLevel, MoodTag?) onEnergySelected;
  final VoidCallback? onDismiss;

  const MoodCheckDialog({
    super.key,
    required this.onEnergySelected,
    this.onDismiss,
  });

  /// Show the dialog with a nice animation
  static Future<void> show(
    BuildContext context, {
    required Function(EnergyLevel, MoodTag?) onEnergySelected,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MoodCheckDialog(
        onEnergySelected: onEnergySelected,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<MoodCheckDialog> createState() => _MoodCheckDialogState();
}

class _MoodCheckDialogState extends State<MoodCheckDialog> {
  EnergyLevel? _selectedEnergy;
  MoodTag? _selectedMood;

  static const _energyOptions = [
    _EnergyOption(
      level: EnergyLevel.low,
      label: 'Low',
      emoji: '😴',
      color: Color(0xFF90CAF9),
      description: 'Rest is ok',
    ),
    _EnergyOption(
      level: EnergyLevel.medium,
      label: 'Medium',
      emoji: '😊',
      color: Color(0xFFFFF59D),
      description: 'Steady pace',
    ),
    _EnergyOption(
      level: EnergyLevel.high,
      label: 'High',
      emoji: '⚡',
      color: Color(0xFFA5D6A7),
      description: 'Let\'s go!',
    ),
  ];

  static const _moodOptions = [
    _MoodOption(tag: MoodTag.sick, label: 'Sick', emoji: '🤒'),
    _MoodOption(tag: MoodTag.stressed, label: 'Stressed', emoji: '😰'),
    _MoodOption(tag: MoodTag.tired, label: 'Tired', emoji: '😮‍💨'),
    _MoodOption(tag: MoodTag.focused, label: 'Focused', emoji: '🎯'),
    _MoodOption(tag: MoodTag.great, label: 'Great', emoji: '🤩'),
  ];

  void _selectEnergy(EnergyLevel level) {
    setState(() {
      _selectedEnergy = level;
    });

    // Auto-submit after energy selection (ADHD-friendly: reduce friction)
    // But allow mood selection if they want
    if (_selectedMood != null) {
      _submit();
    }
  }

  void _selectMood(MoodTag tag) {
    setState(() {
      _selectedMood = tag;
    });
  }

  void _submit() {
    if (_selectedEnergy != null) {
      widget.onEnergySelected(_selectedEnergy!, _selectedMood);
      Navigator.of(context).pop();
    }
  }

  void _dismiss() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'How are you feeling?',
              style: GoogleFonts.comfortaa(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This helps me suggest the right tasks for you',
              textAlign: TextAlign.center,
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                color: AppColors.inkFaint,
              ),
            ),
            const SizedBox(height: 24),

            // Energy selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _energyOptions.map((option) {
                final isSelected = _selectedEnergy == option.level;
                return _EnergyButton(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => _selectEnergy(option.level),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Mood tags (optional)
            Text(
              'Optional: What\'s going on?',
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                color: AppColors.inkFaint,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _moodOptions.map((option) {
                final isSelected = _selectedMood == option.tag;
                return _MoodChip(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => _selectMood(option.tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                // Skip button
                TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkFaint,
                  ),
                  child: Text(
                    'Not now',
                    style: GoogleFonts.comfortaa(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Submit button
                FilledButton(
                  onPressed: _selectedEnergy != null ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.comfortaa(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyOption {
  final EnergyLevel level;
  final String label;
  final String emoji;
  final Color color;
  final String description;

  const _EnergyOption({
    required this.level,
    required this.label,
    required this.emoji,
    required this.color,
    required this.description,
  });
}

class _EnergyButton extends StatelessWidget {
  final _EnergyOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _EnergyButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? option.color.withValues(alpha: 0.3) : AppColors.chip,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? option.color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.comfortaa(
                fontSize: 10,
                color: AppColors.ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodOption {
  final MoodTag tag;
  final String label;
  final String emoji;

  const _MoodOption({
    required this.tag,
    required this.label,
    required this.emoji,
  });
}

class _MoodChip extends StatelessWidget {
  final _MoodOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.chip,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Energy summary widget for displaying current energy state
class EnergySummary extends StatelessWidget {
  final UserEnergy? energy;

  const EnergySummary({super.key, this.energy});

  @override
  Widget build(BuildContext context) {
    if (energy == null) {
      return GestureDetector(
        onTap: () {
          // Trigger check-in
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_outlined,
                  size: 16, color: AppColors.ink.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'Check in',
                style: GoogleFonts.comfortaa(
                  fontSize: 12,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (emoji, color) = _getEnergyDisplay(energy!.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            energy!.mood?.name ?? energy!.level.name,
            style: GoogleFonts.comfortaa(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _getEnergyDisplay(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.low:
        return ('😴', const Color(0xFF90CAF9));
      case EnergyLevel.medium:
        return ('😊', const Color(0xFFFFF59D));
      case EnergyLevel.high:
        return ('⚡', const Color(0xFFA5D6A7));
    }
  }
}
