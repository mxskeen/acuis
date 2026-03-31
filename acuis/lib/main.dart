import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/goals/goal_list_screen.dart';
import 'features/todos/todo_list_screen.dart';
import 'features/alignment/alignment_screen.dart';
import 'models/goal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF5F5F0),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const AcuisApp());
}

// ── Design tokens ──────────────────────────────────────────
class AppColors {
  static const bg       = Color(0xFFF7F7F2);   // warm off-white, Notion paper
  static const surface  = Color(0xFFFFFFFF);
  static const ink      = Color(0xFF111111);   // near-black, sharper
  static const inkLight = Color(0xFF444444);   // darkened for accessibility
  static const inkFaint = Color(0xFF666666);   // darkened for accessibility
  static const border   = Color(0xFFE4E4DF);   // subtle divider
  static const chip     = Color(0xFFEEEEE9);   // tag background
}

class AcuisApp extends StatelessWidget {
  const AcuisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.comfortaaTextTheme(ThemeData.light().textTheme);
    return MaterialApp(
      title: 'Acuis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.ink,
          surface: AppColors.surface,
        ),
        textTheme: base.copyWith(
          displayLarge: base.displayLarge?.copyWith(
              color: AppColors.ink, fontWeight: FontWeight.w700),
          bodyMedium: base.bodyMedium?.copyWith(color: AppColors.ink),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        dividerColor: AppColors.border,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  final List<Goal> goals = [];

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodoListScreen(goals: goals),
      GoalListScreen(),
      const AlignmentScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(key: ValueKey(_idx), child: screens[_idx]),
      ),
      bottomNavigationBar: _NavBar(
        selected: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ── Floating pill nav ──────────────────────────────────────
class _NavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _NavBar({required this.selected, required this.onTap});

  static const _tabs = [
    _Tab(Icons.check_box_outline_blank_rounded, 'Todos'),
    _Tab(Icons.outlined_flag_rounded, 'Goals'),
    _Tab(Icons.bar_chart_rounded, 'Align'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_tabs.length, (i) {
            final isSelected = i == selected;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 14 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabs[i].icon,
                      size: 15,
                      color: isSelected ? AppColors.ink : Colors.white54,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 5),
                      Text(
                        _tabs[i].label,
                        style: GoogleFonts.comfortaa(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      )],
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  const _Tab(this.icon, this.label);
}
