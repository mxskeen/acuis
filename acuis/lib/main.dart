import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/today/today_view.dart';
import 'features/goals/goal_list_screen.dart';
import 'features/todos/todo_list_screen.dart';
import 'features/alignment/alignment_screen.dart';
import 'models/goal.dart';
import 'models/todo.dart';
import 'shared/services/storage_service.dart';
import 'shared/services/alignment_refresh_service.dart';
import 'shared/services/xp_tracking_service.dart';
import 'splash_screen.dart';

void main() async {
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
      home: const _AppEntry(),
    );
  }
}

// ── App Entry (Splash → Home) ──────────────────────────────
class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SplashScreen(
        onInit: () async {
          await StorageService.init();
        },
        onDone: () => setState(() => _ready = true),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: const HomeScreen(),
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
  final _refreshService = AlignmentRefreshService();
  final _xpTrackingService = XPTrackingService.init();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    goals = _storage.loadGoalsSync();
    todos = _storage.loadTodosSync();
    _userName = _storage.loadUserNameSync();
    if (_userName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNameDialog());
    }
  }

  void _onPageChanged(int i) {
    final wasOnAlignment = _idx == 3;
    setState(() => _idx = i);

    // Notify refresh service about screen visibility
    if (i == 3) {
      // Alignment screen is visible
      _refreshService.onScreenVisible();
    } else if (wasOnAlignment) {
      // Was on alignment screen, now leaving
      _refreshService.onScreenHidden();
    }
  }

  void _showNameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NameOnboardingDialog(
        onSave: (name) async {
          await _storage.saveUserName(name);
          setState(() => _userName = name);
        },
      ),
    );
  }

  void _saveData() {
    _storage.saveGoals(goals);
    _storage.saveTodos(todos);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _refreshService.dispose();
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
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          // Today - The daily command center (NEW FIRST TAB)
          TodayView(
            goals: goals,
            todos: todos,
            userName: _userName,
            onNavigateToGoals: () => _onTabTap(1),
            onNavigateToTodos: () => _onTabTap(2),
            onNavigateToAlignment: () => _onTabTap(3),
            onAddTodo: (t) {
              setState(() => todos = [...todos, t]);
              _saveData();
              _refreshService.onTodosChanged();
            },
            onToggleTodo: (i) async {
              final wasCompleted = todos[i].completed;
              setState(() {
                final updated = [...todos];
                updated[i] = updated[i].copyWith(completed: !updated[i].completed);
                todos = updated;
              });
              _saveData();
              _refreshService.onTodosChanged();
              if (wasCompleted) {
                final xpService = await _xpTrackingService;
                await xpService.unmarkTodoAsRewarded(todos[i].id);
              }
            },
          ),
          // Goals
          GoalListScreen(
            goals: goals,
            userName: _userName,
            onAdd: (g) {
              setState(() => goals = [...goals, g]);
              _saveData();
              _refreshService.onGoalsChanged();
            },
            onEdit: (index, g) {
              setState(() => goals = [...goals]..[index] = g);
              _saveData();
              _refreshService.onGoalsChanged();
            },
            onDelete: (index) {
              setState(() => goals = [...goals]..removeAt(index));
              _saveData();
              _refreshService.onGoalsChanged();
            },
            onAddTodos: (newTodos) {
              setState(() => todos = [...todos, ...newTodos]);
              _saveData();
              _refreshService.onTodosChanged();
            },
          ),
          // Todos
          TodoListScreen(
            goals: goals,
            todos: todos,
            userName: _userName,
            onAdd: (t) {
              setState(() => todos = [...todos, t]);
              _saveData();
              _refreshService.onTodosChanged();
            },
            onToggle: (i) async {
              final wasCompleted = todos[i].completed;
              setState(() {
                final updated = [...todos];
                updated[i] = updated[i].copyWith(completed: !updated[i].completed);
                todos = updated;
              });
              _saveData();
              _refreshService.onTodosChanged();
              if (wasCompleted) {
                final xpService = await _xpTrackingService;
                await xpService.unmarkTodoAsRewarded(todos[i].id);
              }
            },
            onEdit: (index, t) {
              setState(() => todos = [...todos]..[index] = t);
              _saveData();
              _refreshService.onTodosChanged();
            },
            onDelete: (index) {
              setState(() => todos = [...todos]..removeAt(index));
              _saveData();
              _refreshService.onTodosChanged();
            },
          ),
          // Alignment (USP)
          AlignmentScreen(
            goals: goals,
            todos: todos,
            refreshService: _refreshService,
            onDataChanged: (updatedTodos) {
              setState(() => todos = updatedTodos);
              _saveData();
            },
            onAddTodo: (t) {
              setState(() => todos = [...todos, t]);
              _saveData();
              _refreshService.onTodosChanged();
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
    _Tab(Icons.today_rounded, 'Today'),
    _Tab(Icons.outlined_flag_rounded, 'Goals'),
    _Tab(Icons.check_box_outline_blank_rounded, 'Steps'),
    _Tab(Icons.insights_rounded, 'Align'),
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

// ── Name Onboarding Dialog ─────────────────────────────────
class _NameOnboardingDialog extends StatefulWidget {
  final void Function(String) onSave;
  const _NameOnboardingDialog({required this.onSave});

  @override
  State<_NameOnboardingDialog> createState() => _NameOnboardingDialogState();
}

class _NameOnboardingDialogState extends State<_NameOnboardingDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/illustrations/girl-with-plant.svg',
            width: 120,
          ),
          const SizedBox(height: 20),
          Text('Hey there 👋',
              style: GoogleFonts.comfortaa(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          Text("What's your name?",
              style: GoogleFonts.comfortaa(
                  fontSize: 13, color: AppColors.inkLight)),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.comfortaa(fontSize: 15, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Your first name',
              hintStyle: GoogleFonts.comfortaa(
                  fontSize: 14, color: AppColors.inkFaint),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text("Let's go",
                    style: GoogleFonts.comfortaa(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      widget.onSave(name);
      Navigator.pop(context);
    }
  }
}
