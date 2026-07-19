import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'agent/agent_service.dart';
import 'design/theme/app_theme.dart';
import 'design/theme/kl_theme.dart';
import 'navigation/kl_bottom_navigation.dart';
import 'screens/home_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/agent_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FitnessAgentService.initialize();
  runApp(const KaiLianApp());
}

class KaiLianApp extends StatelessWidget {
  const KaiLianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '开练',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MainScreen(),
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        final colors = brightness == Brightness.dark
            ? KLColorScheme.dark
            : KLColorScheme.light;
        final typography = KLTypography.forScheme(colors);
        return KLTheme(colors: colors, typography: typography, child: child!);
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};

  final _homeKey = GlobalKey<HomeScreenState>();
  final _plansKey = GlobalKey<PlansScreenState>();
  final _progressKey = GlobalKey<ProgressScreenState>();
  final _chatKey = GlobalKey<AgentChatScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      PlansScreen(key: _plansKey),
      ProgressScreen(key: _progressKey),
      AgentChatScreen(key: _chatKey),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
    switch (index) {
      case 0:
        _homeKey.currentState?.refresh();
      case 1:
        _plansKey.currentState?.refresh();
      case 2:
        _progressKey.currentState?.refresh();
      case 3:
        _chatKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: context.klColors.systemBackground,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            for (int i = 0; i < _screens.length; i++)
              _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: KLBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}
