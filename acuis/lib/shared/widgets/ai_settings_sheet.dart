import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/ai_config.dart';
import '../services/storage_service.dart';

/// AI Provider Settings Sheet
///
/// A reusable bottom sheet for configuring AI provider settings.
/// Can be shown from any screen in the app.
class AISettingsSheet extends StatefulWidget {
  final AIConfig initialConfig;
  final void Function(AIConfig)? onSaved;

  const AISettingsSheet({
    super.key,
    required this.initialConfig,
    this.onSaved,
  });

  /// Show the settings sheet from any context
  static Future<void> show(BuildContext context, {AIConfig? initialConfig, void Function(AIConfig)? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AISettingsSheet(
        initialConfig: initialConfig ?? StorageService().loadAIConfigSync(),
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AISettingsSheet> createState() => _AISettingsSheetState();
}

class _AISettingsSheetState extends State<AISettingsSheet> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _modelCtrl;
  late bool _useCustom;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.initialConfig.customApiKey ?? '');
    _urlCtrl = TextEditingController(text: widget.initialConfig.customApiUrl ?? AIConfig.defaultApiUrl);
    _modelCtrl = TextEditingController(text: widget.initialConfig.customModel ?? AIConfig.defaultModel);
    _useCustom = widget.initialConfig.useCustomProvider;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final config = AIConfig(
      customApiKey: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
      customApiUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      customModel: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      useCustomProvider: _useCustom,
    );
    await StorageService().saveAIConfig(config);
    widget.onSaved?.call(config);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: SingleChildScrollView(
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
            Text('AI Provider Settings',
                style: GoogleFonts.comfortaa(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Use the built-in AI or configure your own OpenAI-compatible API.',
                style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight, height: 1.4)),
            const SizedBox(height: 20),

            // Use custom provider toggle
            Row(
              children: [
                Checkbox(
                  value: _useCustom,
                  onChanged: (v) => setState(() => _useCustom = v ?? false),
                  activeColor: AppColors.ink,
                ),
                Expanded(
                  child: Text('Use custom API provider',
                      style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_useCustom) ...[
              // API Key
              Text('API Key', style: GoogleFonts.comfortaa(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkLight)),
              const SizedBox(height: 6),
              TextField(
                controller: _keyCtrl,
                obscureText: true,
                style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Enter API Key',
                  hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // API URL
              Text('API Base URL', style: GoogleFonts.comfortaa(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkLight)),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'https://api.openai.com/v1/chat/completions',
                  hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Model
              Text('Model ID', style: GoogleFonts.comfortaa(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkLight)),
              const SizedBox(height: 6),
              TextField(
                controller: _modelCtrl,
                style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'gpt-4o-mini, llama-3.1-70b, etc.',
                  hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Built-in info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: const Color(0xFF43A047), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AIConfig.builtInApiKey != null
                          ? 'Using built-in AI (no setup needed)'
                          : 'Built-in AI not available. Add your own API key.',
                        style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            GestureDetector(
              onTap: _saveSettings,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text('Save Settings',
                      style: GoogleFonts.comfortaa(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// A reusable settings icon button that opens the AI settings sheet
class SettingsIconButton extends StatelessWidget {
  final Color? color;
  final AIConfig? currentConfig;
  final VoidCallback? onSettingsChanged;

  const SettingsIconButton({
    super.key,
    this.color,
    this.currentConfig,
    this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => AISettingsSheet.show(
        context,
        initialConfig: currentConfig,
        onSaved: (_) => onSettingsChanged?.call(),
      ),
      icon: Icon(Icons.settings_outlined, color: color ?? AppColors.ink),
    );
  }
}
