import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme/kl_theme.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';
import 'agent_chat_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_list_screen.dart';
import 'plans_screen.dart';
import 'quick_workout_screen.dart';

/// 首页只保留一个问题：用户现在想做什么。
///
/// The prompt is the single AI entry point. Everything else is a direct,
/// predictable route into training, plans, or exercise browsing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const _categories = [
    _Category('chest', '胸部', Icons.accessibility_new_rounded),
    _Category('back', '背部', Icons.airline_seat_flat_rounded),
    _Category('shoulders', '肩部', Icons.pan_tool_outlined),
    _Category('upper legs', '腿部', Icons.directions_run_rounded),
  ];

  final _promptController = TextEditingController();
  List<Exercise> _exercises = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
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
  }

  void _open(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _askCoach() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    _promptController.clear();
    _open(AgentChatScreen(initialPrompt: prompt));
  }

  int _countFor(String category) =>
      _exercises.where((e) => e.category.toLowerCase() == category).length;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    if (_loading) return _HomeSkeleton(color: colors.tertiarySystemBackground);

    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildPrompt()),
            SliverToBoxAdapter(child: _buildQuickActions()),
            if (_favoriteIds.isNotEmpty)
              SliverToBoxAdapter(child: _buildFavorites()),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final typography = context.klTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text('开练', style: typography.title1),
    );
  }

  Widget _buildPrompt() {
    final colors = context.klColors;
    final typography = context.klTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今天练什么？', style: typography.title2),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.secondarySystemBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.7),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _askCoach(),
                    decoration: InputDecoration(
                      hintText: '问教练，或描述你的目标',
                      hintStyle: typography.subhead.copyWith(
                        color: colors.placeholder,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: '发送给教练',
                  onPressed: _askCoach,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('开始训练'),
            onPressed: () => _open(const QuickWorkoutScreen()),
          ),
          ActionChip(
            avatar: const Icon(Icons.view_agenda_outlined, size: 18),
            label: const Text('我的计划'),
            onPressed: () => _open(const PlansScreen()),
          ),
          ActionChip(
            avatar: const Icon(Icons.search_rounded, size: 18),
            label: const Text('找动作'),
            onPressed: () => _open(const ExerciseListScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildFavorites() {
    final favorites = _favoriteIds
        .map((id) => ExerciseService.findById(id))
        .whereType<Exercise>()
        .take(4)
        .toList();
    if (favorites.isEmpty) return const SizedBox.shrink();

    final typography = context.klTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('继续训练', style: typography.title3),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final exercise = favorites[index];
                return _FavoriteExercise(
                  exercise: exercise,
                  onTap: () => _open(ExerciseDetailScreen(exercise: exercise)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final colors = context.klColors;
    final typography = context.klTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('按部位浏览', style: typography.title3),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.secondarySystemBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int index = 0; index < _categories.length; index++) ...[
                  _CategoryRow(
                    category: _categories[index],
                    count: _countFor(_categories[index].key),
                    onTap: () => _open(
                      ExerciseListScreen(
                        initialCategory: _categories[index].key,
                        categoryLabel: _categories[index].label,
                      ),
                    ),
                  ),
                  if (index != _categories.length - 1)
                    Divider(
                      height: 1,
                      indent: 68,
                      color: colors.separator.withValues(alpha: 0.55),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String key;
  final String label;
  final IconData icon;

  const _Category(this.key, this.label, this.icon);
}

class _FavoriteExercise extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _FavoriteExercise({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return SizedBox(
      width: 180,
      child: Material(
        color: colors.secondarySystemBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  child: SizedBox(
                    width: 64,
                    height: 76,
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _Category category;
  final int count;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(category.icon, color: colors.label, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.label,
                  style: typography.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$count 个动作',
                style: typography.footnote.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.tertiaryLabel),
              const SizedBox(width: 12),
            ],
          ),
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBlock(width: 100, height: 28, color: color),
            const SizedBox(height: 44),
            _SkeletonBlock(width: 150, height: 24, color: color),
            const SizedBox(height: 12),
            _SkeletonBlock(width: double.infinity, height: 68, color: color),
            const SizedBox(height: 24),
            _SkeletonBlock(width: double.infinity, height: 236, color: color),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
