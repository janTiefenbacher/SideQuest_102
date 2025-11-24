import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quest.dart';

class QuestDatabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active quest templates from database
  static Future<List<QuestTemplate>> getQuestTemplates() async {
    try {
      final response = await _supabase
          .from('quest_templates')
          .select()
          .order('difficulty', ascending: true);

      return (response as List)
          .map((json) => QuestTemplate.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching quest templates: $e');
      return [];
    }
  }

  // Get quest templates by difficulty
  static Future<List<QuestTemplate>> getQuestTemplatesByDifficulty(QuestDifficulty difficulty) async {
    try {
      final response = await _supabase
          .from('quest_templates')
          .select()
          .eq('difficulty', difficulty.name);

      return (response as List)
          .map((json) => QuestTemplate.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching quest templates by difficulty: $e');
      return [];
    }
  }

  // Create daily quest for user using database function
  static Future<String?> createDailyQuestForUser(String userId, DateTime questDate) async {
    try {
      final response = await _supabase.rpc('create_daily_quest_for_user', params: {
        'p_user_id': userId,
        'p_quest_date': questDate.toIso8601String().split('T')[0], // Only date part
      });

      return response as String?;
    } catch (e) {
      print('Error creating daily quest: $e');
      return null;
    }
  }

  // Get or create daily quest for all users (same quests for everyone)
  static Future<DailyQuest?> getOrCreateDailyQuestForAllUsers(DateTime questDate) async {
    try {
      final dateString = questDate.toIso8601String().split('T')[0];
      
      // First, try to get existing daily quest for this date
      final response = await _supabase
          .from('daily_quests')
          .select('''
            id,
            quest_date,
            selected_quest_id,
            is_completed,
            completed_at,
            easy_quest:quest_templates!easy_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            ),
            medium_quest:quest_templates!medium_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            ),
            hard_quest:quest_templates!hard_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            )
          ''')
          .eq('quest_date', dateString)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return DailyQuest.fromDatabaseJson(response);
      }

      // If no daily quest exists for this date, create one using deterministic selection
      final dailyQuest = await _createDeterministicDailyQuest(questDate);
      return dailyQuest;
    } catch (e) {
      print('Error getting or creating daily quest: $e');
      return null;
    }
  }

  // Create deterministic daily quest based on date (same for all users)
  static Future<DailyQuest?> _createDeterministicDailyQuest(DateTime questDate) async {
    try {
      final easyQuests = await getQuestTemplatesByDifficulty(QuestDifficulty.easy);
      final mediumQuests = await getQuestTemplatesByDifficulty(QuestDifficulty.medium);
      final hardQuests = await getQuestTemplatesByDifficulty(QuestDifficulty.hard);

      if (easyQuests.isEmpty || mediumQuests.isEmpty || hardQuests.isEmpty) {
        return null;
      }

      // Use date as seed for deterministic selection
      final dateString = questDate.toIso8601String().split('T')[0];
      final seed = dateString.hashCode;

      final easyQuest = easyQuests[seed.abs() % easyQuests.length];
      final mediumQuest = mediumQuests[(seed + 1).abs() % mediumQuests.length];
      final hardQuest = hardQuests[(seed + 2).abs() % hardQuests.length];

      return DailyQuest(
        id: 'daily_$dateString',
        easyQuest: Quest.fromTemplate(easyQuest),
        mediumQuest: Quest.fromTemplate(mediumQuest),
        hardQuest: Quest.fromTemplate(hardQuest),
        date: questDate,
      );
    } catch (e) {
      print('Error creating deterministic daily quest: $e');
      return null;
    }
  }

  // Get daily quest for user and date
  static Future<DailyQuest?> getDailyQuestForUser(String userId, DateTime questDate) async {
    try {
      final response = await _supabase
          .from('daily_quests')
          .select('''
            id,
            quest_date,
            selected_quest_id,
            is_completed,
            completed_at,
            easy_quest:quest_templates!easy_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            ),
            medium_quest:quest_templates!medium_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            ),
            hard_quest:quest_templates!hard_quest_id(
              id,
              title,
              description,
              difficulty,
              points,
              category
            )
          ''')
          .eq('user_id', userId)
          .eq('quest_date', questDate.toIso8601String().split('T')[0])
          .maybeSingle();

      if (response == null) return null;

      return DailyQuest.fromDatabaseJson(response);
    } catch (e) {
      print('Error fetching daily quest: $e');
      return null;
    }
  }

  // Select a quest for the daily quest
  static Future<bool> selectQuestForDailyQuest(String dailyQuestId, String questTemplateId) async {
    try {
      print('Selecting quest: dailyQuestId=$dailyQuestId, questTemplateId=$questTemplateId');
      
      final response = await _supabase
          .from('daily_quests')
          .update({'selected_quest_id': questTemplateId})
          .eq('id', dailyQuestId);

      print('Quest selection response: $response');
      return true;
    } catch (e) {
      print('Error selecting quest: $e');
      return false;
    }
  }

  // Complete a quest
  static Future<bool> completeQuest(String userId, String dailyQuestId, String questTemplateId, {String? completionNotes}) async {
    try {
      final response = await _supabase.rpc('complete_quest', params: {
        'p_user_id': userId,
        'p_daily_quest_id': dailyQuestId,
        'p_quest_template_id': questTemplateId,
        'p_completion_notes': completionNotes,
      });

      return response as bool;
    } catch (e) {
      print('Error completing quest: $e');
      return false;
    }
  }

  // Get user quest statistics
  static Future<UserQuestStats?> getUserQuestStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_quest_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserQuestStats.fromJson(response);
    } catch (e) {
      print('Error fetching user quest stats: $e');
      return null;
    }
  }

  // Get quest completion history for user
  static Future<List<QuestCompletion>> getQuestCompletions(String userId, {int? limit}) async {
    try {
      var query = _supabase
          .from('quest_completions')
          .select('''
            id,
            completed_at,
            points_earned,
            completion_notes,
            quest_template:quest_templates(
              id,
              title,
              description,
              difficulty,
              points,
              category
            )
          ''')
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((json) => QuestCompletion.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching quest completions: $e');
      return [];
    }
  }

  // Check if user has completed quest today
  static Future<bool> hasCompletedQuestToday(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('daily_quests')
          .select('is_completed')
          .eq('user_id', userId)
          .eq('quest_date', today)
          .eq('is_completed', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking quest completion: $e');
      return false;
    }
  }

  // Get deterministic quest templates for each difficulty (for fallback)
  static Future<DailyQuest?> generateRandomDailyQuest(String userId) async {
    try {
      final today = DateTime.now();
      return await _createDeterministicDailyQuest(today);
    } catch (e) {
      print('Error generating daily quest: $e');
      return null;
    }
  }
}

// Additional model classes for database integration
class QuestTemplate {
  final String id;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final int points;
  final String category;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuestTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.points,
    required this.category,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory QuestTemplate.fromJson(Map<String, dynamic> json) {
    return QuestTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: QuestDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => QuestDifficulty.easy,
      ),
      points: json['points'] as int? ?? 10, // Default points if not provided
      category: json['category'] as String? ?? 'Allgemein', // Default category if not provided
      isActive: json['is_active'] as bool? ?? true, // Default to true if not provided
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty.name,
      'points': points,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class UserQuestStats {
  final String id;
  final String userId;
  final int totalPoints;
  final int totalQuestsCompleted;
  final int easyQuestsCompleted;
  final int mediumQuestsCompleted;
  final int hardQuestsCompleted;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastQuestDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserQuestStats({
    required this.id,
    required this.userId,
    required this.totalPoints,
    required this.totalQuestsCompleted,
    required this.easyQuestsCompleted,
    required this.mediumQuestsCompleted,
    required this.hardQuestsCompleted,
    required this.currentStreak,
    required this.longestStreak,
    this.lastQuestDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserQuestStats.fromJson(Map<String, dynamic> json) {
    return UserQuestStats(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalPoints: json['total_points'] as int,
      totalQuestsCompleted: json['total_quests_completed'] as int,
      easyQuestsCompleted: json['easy_quests_completed'] as int,
      mediumQuestsCompleted: json['medium_quests_completed'] as int,
      hardQuestsCompleted: json['hard_quests_completed'] as int,
      currentStreak: json['current_streak'] as int,
      longestStreak: json['longest_streak'] as int,
      lastQuestDate: json['last_quest_date'] != null 
          ? DateTime.parse(json['last_quest_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class QuestCompletion {
  final String id;
  final String userId;
  final String dailyQuestId;
  final String questTemplateId;
  final DateTime completedAt;
  final int pointsEarned;
  final String? completionNotes;
  final QuestTemplate questTemplate;

  const QuestCompletion({
    required this.id,
    required this.userId,
    required this.dailyQuestId,
    required this.questTemplateId,
    required this.completedAt,
    required this.pointsEarned,
    this.completionNotes,
    required this.questTemplate,
  });

  factory QuestCompletion.fromJson(Map<String, dynamic> json) {
    return QuestCompletion(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dailyQuestId: json['daily_quest_id'] as String,
      questTemplateId: json['quest_template_id'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      pointsEarned: json['points_earned'] as int,
      completionNotes: json['completion_notes'] as String?,
      questTemplate: QuestTemplate.fromJson(json['quest_template'] as Map<String, dynamic>),
    );
  }
}
