import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/goals/goal_list_screen.dart';
import 'features/todos/todo_list_screen.dart';
import 'features/alignment/alignment_screen.dart';
import 'models/goal.dart';
import 'models/todo.dart';
import 'shared/services/storage_service.dart';

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
  List<Goal> goals = [];
  List<Todo> todos = [];
  late final PageController _pageCtrl;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadData();
  }

  Future<void> _loadData() async {
    final loadedGoals = await _storage.loadGoals();
    final loadedTodos = await _storage.loadTodos();
    setState(() {
      goals = loadedGoals;
      todos = loadedTodos;
    });
  }

  void _saveData() {
    _storage.saveGoals(goals);
    _storage.saveTodos(todos);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    setState(() => _idx = i);
    _pageCtrl.animateToPage(i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _idx = i),
        physics: const BouncingScrollPhysics(),
        children: [
          GoalListScreen(
            goals: goals,
            onAdd: (g) {
              setState(() => goals.add(g));
              _saveData();
            },
          ),
          TodoListScreen(
            goals: goals,
            todos: todos,
            onAdd: (t) {
              setState(() => todos.add(t));
              _saveData();
            },
            onToggle: (i) {
              setState(() {
                todos[i] = todos[i].copyWith(completed: !todos[i].completed);
              });
              _saveData();
            },
          ),
          AlignmentScreen(
            goals: goals,
            todos: todos,
            onDataChanged: () {
              setState(() {});
              _saveData();
            },
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        selected: _idx,
        onTap: _onTabTap,
      ),
    );
  }
}


// ── Dynamic Island pill nav ────────────────────────────────
class _NavBar extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _NavBar({required this.selected, required this.onTap});

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _anim;
  late final Animation<double> _curve;

  static const _tabs = [
    _Tab(Icons.outlined_flag_rounded, 'Goals'),
    _Tab(Icons.check_box_outline_blank_rounded, 'Todos'),
    _Tab(Icons.bar_chart_rounded, 'Align'),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when tab changes (e.g. from swipe)
    if (oldWidget.selected != widget.selected) {
      _collapse();
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  void _collapse() {
    if (_expanded) {
      setState(() => _expanded = false);
      _anim.reverse();
    }
  }

  void _selectTab(int i) {
    widget.onTap(i);
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final expandProgress = _curve.value;
        // Pill dimensions interpolation
        final pillHeight = 44.0 + (expandProgress * 56);  // 44 → 100
        final pillHPad = 4.0 + (expandProgress * 12);     // 4 → 16
        final pillRadius = 25.0 + (expandProgress * 8);   // 25 → 33

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dismiss barrier (invisible, catches taps outside)
            if (_expanded)
              GestureDetector(
                onTap: _collapse,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(height: 0),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: 6,
                bottom: bottomPad + 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _expanded ? null : _toggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      height: pillHeight,
                      padding: EdgeInsets.symmetric(horizontal: pillHPad),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(pillRadius),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(
                              alpha: 0.10 + (expandProgress * 0.15),
                            ),
                            blurRadius: 12 + (expandProgress * 16),
                            offset: Offset(0, 4 + (expandProgress * 4)),
                          ),
                        ],
                      ),
                      child: _expanded
                          ? _buildExpanded()
                          : _buildCollapsed(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCollapsed() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_tabs.length, (i) {
        final isSelected = i == widget.selected;
        return GestureDetector(
          onTap: () => _selectTab(i),
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
    );
  }

  Widget _buildExpanded() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_tabs.length, (i) {
            final isSelected = i == widget.selected;
            return GestureDetector(
              onTap: () => _selectTab(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surface
                      : AppColors.ink.withValues(alpha: 0.0),
                  borderRadius: BorderRadius.circular(22),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white12,
                          width: 1,
                        ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabs[i].icon,
                      size: 20,
                      color: isSelected ? AppColors.ink : Colors.white70,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tabs[i].label,
                      style: GoogleFonts.comfortaa(
                        color: isSelected ? AppColors.ink : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // Swipe indicator
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  const _Tab(this.icon, this.label);
}
