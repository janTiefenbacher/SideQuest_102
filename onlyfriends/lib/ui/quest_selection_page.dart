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
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Tägliche Quest wählen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
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
                        Text(
                          'Wähle deine Quest für heute:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Quest cards
                        Expanded(
                          child: ListView(
                            children: [
                              _QuestCard(
                                quest: dailyQuest!.easyQuest,
                                isSelected: selectedQuest?.id == dailyQuest!.easyQuest.id,
                                onTap: () => _selectQuest(dailyQuest!.easyQuest),
                              ),
                              const SizedBox(height: 12),
                              _QuestCard(
                                quest: dailyQuest!.mediumQuest,
                                isSelected: selectedQuest?.id == dailyQuest!.mediumQuest.id,
                                onTap: () => _selectQuest(dailyQuest!.mediumQuest),
                              ),
                              const SizedBox(height: 12),
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
    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected
            ? BorderSide(color: quest.difficulty.color, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with difficulty and points
              Row(
                children: [
                  Icon(
                    quest.difficulty.icon,
                    color: quest.difficulty.color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    quest.difficulty.label,
                    style: TextStyle(
                      color: quest.difficulty.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: quest.difficulty.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${quest.points} Punkte',
                      style: TextStyle(
                        color: quest.difficulty.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title - visible
              Text(
                quest.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Description - beautiful blur effect
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey.withValues(alpha: 0.1),
                      Colors.grey.withValues(alpha: 0.3),
                      Colors.grey.withValues(alpha: 0.1),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 90,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 65,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 50,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 75,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 60,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 45,
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withValues(alpha: 0.4),
                                Colors.grey.withValues(alpha: 0.6),
                                Colors.grey.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Category
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kSky,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quest.category,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: quest.difficulty.color,
                      size: 24,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
