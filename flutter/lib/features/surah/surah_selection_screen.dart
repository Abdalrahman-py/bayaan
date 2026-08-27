import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import 'models/surah.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/router/app_router.dart';
import '../../services/quran_text.dart';

class SurahSelectionScreen extends StatefulWidget {
  const SurahSelectionScreen({super.key});

  @override
  State<SurahSelectionScreen> createState() => _SurahSelectionScreenState();
}

class _SurahSelectionScreenState extends State<SurahSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _filtersFade;

  // ponytail: Favorites/Recent are visual-only — no favorites/history backend yet.
  String _selectedFilter = 'All';

  /// The row entrance is a one-shot effect for when the list appears. Rows are
  /// inflated lazily, so without this a surah scrolled to later would replay
  /// the whole stagger and sit blank for about a second.
  bool _entranceDone = false;
  final TextEditingController _searchController = TextEditingController();
  late final List<Surah> _allSurahs;

  @override
  void initState() {
    super.initState();
    _allSurahs = QuranText.chapters.map(Surah.fromChapter).toList();
    // Longest row delay (capped at 12 steps) plus one row's fade.
    Future.delayed(const Duration(milliseconds: 12 * 60 + 400), () {
      if (mounted) setState(() => _entranceDone = true);
    });
    _searchController.addListener(() => setState(() {}));
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(_headerFade);
    _filtersFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allSurahs;
    return _allSurahs
        .where(
          (s) =>
              s.nameEnglish.toLowerCase().contains(q) ||
              s.nameArabic.contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final surahs = _filtered;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(),
                  _buildFilters(),
                  ...List.generate(surahs.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: StaggeredFadeSlide(
                        index: index,
                        animate: !_entranceDone,
                        child: _SurahRow(surah: surahs[index]),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a Surah',
                style: pjs(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF5F1E6)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: pjs(fontSize: 14, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: 'Search surah or ayah…',
                          hintStyle: pjs(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return FadeTransition(
      opacity: _filtersFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: _selectedFilter == 'All',
              onTap: () => setState(() => _selectedFilter = 'All'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Favorites',
              icon: Icons.favorite_border,
              isSelected: _selectedFilter == 'Favorites',
              onTap: () => setState(() => _selectedFilter = 'Favorites'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Recent',
              icon: Icons.access_time,
              isSelected: _selectedFilter == 'Recent',
              onTap: () => setState(() => _selectedFilter = 'Recent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealStart : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.tealStart : const Color(0xFFF5F1E6),
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: pjs(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final Surah surah;

  const _SurahRow({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final startPage = QuranText.pageFor(surah.number, 1) ?? 1;
          context.push(
            AppRoutes.ayahSelection,
            extra: AyahSelectionArgs(
              surahNumber: surah.number,
              surahNameEnglish: surah.nameEnglish,
              surahNameArabic: 'سُورَةُ ${surah.nameArabic}',
              initialPage: startPage,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF5F1E6)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  '${surah.number}',
                  style: pjs(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tealStart,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          surah.nameEnglish,
                          style: pjs(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          surah.nameArabic,
                          textDirection: TextDirection.rtl,
                          style: arabic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${surah.meaning} · ${surah.revelationType} · ${surah.ayahCount} ayahs · ~${surah.estimatedMinutes} min',
                      overflow: TextOverflow.ellipsis,
                      style: pjs(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
