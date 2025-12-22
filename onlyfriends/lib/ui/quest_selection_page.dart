import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quest.dart';
import '../services/quest_service.dart';
import '../theme.dart';

class QuestSelectionPage extends StatefulWidget {
  const QuestSelectionPage({super.key});

  static const String route = '/quest-selection';

  @override
  State<QuestSelectionPage> createState() => _QuestSelectionPageState();
}

class _QuestSelectionPageState extends State<QuestSelectionPage> {
  Quest? selectedQuest;
  DailyQuest? dailyQuest;

  @override
  void initState() {
    super.initState();
    _loadDailyQuest();
  }

  Future<void> _loadDailyQuest() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('No user ID available');
        return;
      }

      // Use the new method that evaluates yesterday's quest and awards points
      final quest = await QuestService.getTodaysDailyQuestWithEvaluation(userId);
      if (mounted) {
        setState(() {
          dailyQuest = quest;
          selectedQuest = quest?.selectedQuest;
        });
      }
    } catch (e) {
      print('Error loading daily quest: $e');
      // Fallback to generating a new quest
      if (mounted) {
        setState(() {
          dailyQuest = QuestTemplates.generateDailyQuest();
        });
      }
    }
  }

  void _selectQuest(Quest quest) {
    setState(() {
      selectedQuest = quest;
    });
  }

  Future<void> _confirmQuest() async {
    if (selectedQuest == null || dailyQuest == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bitte melde dich an, um eine Quest auszuwählen'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Select the quest using local storage (guaranteed to work)
      print('Attempting to select quest: ${selectedQuest!.id}');
      
      try {
        // Save the selected quest locally
        await QuestService.saveSelectedQuestForToday(selectedQuest!, userId);
        
        // Update the daily quest with the selected quest
        final updatedDailyQuest = dailyQuest!.copyWith(
          selectedQuestId: selectedQuest!.id,
        );

        setState(() {
          dailyQuest = updatedDailyQuest;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quest "${selectedQuest!.title}" ausgewählt!'),
              backgroundColor: kBrightBlue,
            ),
          );
          // Pop with a flag to force a full reload by the caller
          Navigator.of(context).pop({'selected': selectedQuest!.id, 'forceReload': true});
        }
      } catch (e) {
        print('Error selecting quest: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Auswählen der Quest: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving selected quest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern der Quest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final date = dailyQuest?.date ?? DateTime.now();
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                _HeaderIconButton(
                  onTap: () => Navigator.of(context).pop(),
                  icon: Icons.arrow_back_ios_new,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Daily Quest',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$formattedDate • Bleib im Flow',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedQuestPreview(BuildContext context) {
    final theme = Theme.of(context);
    final quest = selectedQuest ?? dailyQuest?.selectedQuest;
    final bool hasSelection = quest != null;
    final Color accent = quest?.difficulty.color ?? kBrightBlue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutQuad,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasSelection
              ? [
                  accent.withOpacity(0.9),
                  accent.withOpacity(0.7),
                ]
              : [
                  theme.colorScheme.primary.withOpacity(0.08),
                  theme.colorScheme.primary.withOpacity(0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(hasSelection ? 0.4 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(hasSelection ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: hasSelection
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      quest!.difficulty.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        quest.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(
                      icon: Icons.emoji_events,
                      label: '${quest.points} P',
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  quest.difficulty.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _CensoredDescriptionPreview(
                  accent: Colors.white.withOpacity(0.75),
                  background: Colors.white.withOpacity(0.15),
                  message: 'Details werden nach Bestätigung sichtbar',
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.touch_app,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Noch keine Quest gewählt',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tippe eine Karte unten an, um Details zu sehen und zu bestätigen.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (dailyQuest == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [kSky, kBrightBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSelectedQuestPreview(context),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Column(
                            children: [
                              _QuestCard(
                                quest: dailyQuest!.easyQuest,
                                isSelected: selectedQuest?.id == dailyQuest!.easyQuest.id,
                                onTap: () => _selectQuest(dailyQuest!.easyQuest),
                              ),
                              const SizedBox(height: 10),
                              _QuestCard(
                                quest: dailyQuest!.mediumQuest,
                                isSelected: selectedQuest?.id == dailyQuest!.mediumQuest.id,
                                onTap: () => _selectQuest(dailyQuest!.mediumQuest),
                              ),
                              const SizedBox(height: 10),
                              _QuestCard(
                                quest: dailyQuest!.hardQuest,
                                isSelected: selectedQuest?.id == dailyQuest!.hardQuest.id,
                                onTap: () => _selectQuest(dailyQuest!.hardQuest),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Confirm button
                        FilledButton(
                          onPressed: selectedQuest != null ? _confirmQuest : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrightBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            selectedQuest != null
                                ? 'Quest bestätigen'
                                : 'Wähle eine Quest aus',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.isSelected,
    required this.onTap,
  });

  final Quest quest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent = quest.difficulty.color;

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isSelected ? 1.02 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    accent.withOpacity(0.15),
                    accent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withOpacity(isSelected ? 0.4 : 0.15),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isSelected ? 0.25 : 0.08),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      quest.difficulty.icon,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.difficulty.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    quest.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  quest.difficulty == QuestDifficulty.easy
                                      ? Icons.filter_1
                                      : quest.difficulty == QuestDifficulty.medium
                                          ? Icons.filter_2
                                          : Icons.filter_3,
                                  color: accent.withOpacity(0.6),
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _InfoPill(
                        icon: Icons.emoji_events,
                        label: '${quest.points} P',
                        foregroundColor: accent,
                        backgroundColor: accent.withOpacity(0.12),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 110,
                        child: _CensoredDescriptionPreview(
                          accent: theme.colorScheme.onSurface.withOpacity(0.45),
                          background: theme.colorScheme.onSurface
                              .withOpacity(0.05),
                          message: '',
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CensoredDescriptionPreview extends StatelessWidget {
  const _CensoredDescriptionPreview({
    required this.accent,
    required this.background,
    required this.message,
    this.compact = false,
  });

  final Color accent;
  final Color background;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color glassStart =
        (isDark ? kBrightBlue : kSky).withOpacity(0.45);
    final Color glassEnd = kBrightBlue.withOpacity(isDark ? 0.6 : 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              compact ? 2 : 3,
              (index) => Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                child: Container(
                  height: compact ? 8 : 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
