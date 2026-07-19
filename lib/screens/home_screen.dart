import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/agent_service.dart';
import '../design/components/kl_card.dart';
import '../design/theme/kl_theme.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';
import 'agent_chat_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_list_screen.dart';
import 'plans_screen.dart';
import 'quick_workout_screen.dart';

/// 首页只回答一件事：用户现在最值得做的下一步是什么。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _categories = [
    _Category('chest', '胸部', Icons.accessibility_new_rounded),
    _Category('back', '背部', Icons.airline_seat_flat_rounded),
    _Category('shoulders', '肩部', Icons.pan_tool_outlined),
    _Category('upper legs', '腿部', Icons.directions_run_rounded),
  ];

  List<Exercise> _exercises = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;
  late final AnimationController _entryController;

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _load();
  }

  Future<void> _load() async {
    final exercises = await ExerciseService.loadExercises();
    DatabaseService.invalidateFavoritesCache();
    final favorites = await DatabaseService.getFavoriteIds();
    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _favoriteIds = favorites;
      _loading = false;
    });
    _entryController.forward(from: 0);
  }

  void _open(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  int _countFor(String category) =>
      _exercises.where((e) => e.category.toLowerCase() == category).length;

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    if (_loading) return _HomeSkeleton(color: colors.tertiarySystemBackground);

    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryController,
            curve: Curves.easeOut,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(colors, typography)),
              SliverToBoxAdapter(child: _buildCoachCard(colors, typography)),
              SliverToBoxAdapter(child: _buildQuickActions()),
              if (_favoriteIds.isNotEmpty)
                SliverToBoxAdapter(child: _buildFavorites(colors, typography)),
              SliverToBoxAdapter(child: _buildBrowse(colors, typography)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((_, index) {
                    final category = _categories[index];
                    return _CategoryTile(
                      category: category,
                      count: _countFor(category.key),
                      onTap: () => _open(
                        ExerciseListScreen(
                          initialCategory: category.key,
                          categoryLabel: category.label,
                        ),
                      ),
                    );
                  }, childCount: _categories.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(KLColorScheme colors, KLTypography typography) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开练 / 今天',
                  style: typography.caption1.copyWith(
                    color: colors.primaryAccent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text('今天，先做一件小事。', style: typography.largeTitle),
                const SizedBox(height: 5),
                Text(
                  '告诉教练你的状态，下一步会更清楚。',
                  style: typography.subhead.copyWith(
                    color: colors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          _IconAction(
            icon: Icons.auto_awesome_rounded,
            label: '打开 AI 教练',
            onTap: () => _open(const AgentChatScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(KLColorScheme colors, KLTypography typography) {
    final onAccent = colors.brightness == Brightness.dark
        ? colors.label
        : Colors.white;
    final usingApi = FitnessAgentService.instance.isUsingApi;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: ScaleOnPress(
        onTap: () => _open(const AgentChatScreen()),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 17, 17),
          decoration: BoxDecoration(
            color: colors.label,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AI 今日建议',
                      style: typography.caption2.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: colors.systemBackground.withValues(alpha: 0.65),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '今天交给教练',
                style: typography.title1.copyWith(
                  color: colors.systemBackground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '告诉我你有多少时间、想练哪里，以及今天的状态。',
                style: typography.footnote.copyWith(
                  color: colors.systemBackground.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _MetaText(
                    icon: Icons.auto_awesome_rounded,
                    text: usingApi ? '在线 Agent' : '离线 Agent',
                    color: colors.systemBackground.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 16),
                  _MetaText(
                    icon: Icons.tune_rounded,
                    text: '个性化建议',
                    color: colors.systemBackground.withValues(alpha: 0.7),
                  ),
                  const Spacer(),
                  Text(
                    '问教练',
                    style: typography.subhead.copyWith(
                      color: colors.primaryAccentLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.play_arrow_rounded,
              label: '开始训练',
              detail: '现在就动起来',
              onTap: () => _open(const QuickWorkoutScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.view_agenda_outlined,
              label: '查看计划',
              detail: '安排下一次训练',
              onTap: () => _open(const PlansScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavorites(KLColorScheme colors, KLTypography typography) {
    final favorites = _favoriteIds
        .map((id) => ExerciseService.findById(id))
        .whereType<Exercise>()
        .take(8)
        .toList();
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: '继续练', action: '已收藏'),
          const SizedBox(height: 11),
          SizedBox(
            height: 118,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (_, index) => _FavoriteExercise(
                exercise: favorites[index],
                onTap: () =>
                    _open(ExerciseDetailScreen(exercise: favorites[index])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowse(KLColorScheme colors, KLTypography typography) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
          child: Row(
            children: [
              Text('找一个动作', style: typography.title3),
              const Spacer(),
              GestureDetector(
                onTap: () => _open(const ExerciseListScreen()),
                child: Text(
                  '查看全部',
                  style: typography.footnote.copyWith(
                    color: colors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ScaleOnPress(
            onTap: () => _open(const ExerciseListScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                color: colors.tertiarySystemBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: colors.secondaryLabel,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '搜索动作、部位或器材',
                    style: typography.subhead.copyWith(
                      color: colors.placeholder,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    color: colors.tertiaryLabel,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Category {
  final String key;
  final String label;
  final IconData icon;
  const _Category(this.key, this.label, this.icon);
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.secondarySystemBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.separator, width: 0.5),
          ),
          child: Icon(icon, color: colors.primaryAccent, size: 19),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetaText({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primaryAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: typography.subhead.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String action;
  const _SectionHeading({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(title, style: typography.title3),
          const Spacer(),
          Text(
            action,
            style: typography.caption1.copyWith(color: colors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _FavoriteExercise extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _FavoriteExercise({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        width: 132,
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: double.infinity,
              child: Image.asset(
                exercise.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colors.tertiarySystemBackground,
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: colors.tertiaryLabel,
                    size: 18,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Text(
                  exercise.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final _Category category;
  final int count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(category.icon, color: colors.label, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.label,
                style: typography.subhead.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: typography.caption1.copyWith(color: colors.tertiaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  final Color color;
  const _HomeSkeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            _SkeletonBlock(width: 140, height: 14),
            const SizedBox(height: 14),
            _SkeletonBlock(width: 220, height: 34),
            const SizedBox(height: 28),
            _SkeletonBlock(width: double.infinity, height: 190),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBlock({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.klColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
