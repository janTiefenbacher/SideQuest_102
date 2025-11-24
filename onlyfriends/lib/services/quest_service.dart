import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quest.dart';
import 'quest_database_service.dart';

class QuestService {
  static const String _selectedQuestKey = 'selected_quest';
  static const String _questDateKey = 'quest_date';
  static const String _isConfirmedKey = 'is_confirmed';
  static const String _dailyQuestKey = 'daily_quest';
  static const String _flameStreakKey = 'flame_streak';
  static const String _lastPostDateKey = 'last_post_date';

  // Save selected quest for specific user
  static Future<void> saveSelectedQuest(Quest quest, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questJson = jsonEncode(quest.toJson());
    final today = DateTime.now().toIso8601String().split('T')[0]; // Only date part
    
    await prefs.setString('${_selectedQuestKey}_$userId', questJson);
    await prefs.setString('${_questDateKey}_$userId', today);
    await prefs.setBool('${_isConfirmedKey}_$userId', true);
  }

  // Get selected quest for today for specific user
  static Future<Quest?> getSelectedQuest(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questJson = prefs.getString('${_selectedQuestKey}_$userId');
    final questDate = prefs.getString('${_questDateKey}_$userId');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Check if quest is from today
    if (questDate != today || questJson == null) {
      return null;
    }
    
    try {
      final questMap = jsonDecode(questJson) as Map<String, dynamic>;
      return Quest.fromJson(questMap);
    } catch (e) {
      return null;
    }
  }

  // Check if quest is confirmed for specific user
  static Future<bool> isQuestConfirmed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questDate = prefs.getString('${_questDateKey}_$userId');
    final today = DateTime.now().toIso8601String().split('T')[0];
    final isConfirmed = prefs.getBool('${_isConfirmedKey}_$userId') ?? false;
    
    // Only return true if quest is from today and confirmed
    return questDate == today && isConfirmed;
  }

  // Check if user can select a new quest (after midnight)
  static Future<bool> canSelectNewQuest(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questDate = prefs.getString('${_questDateKey}_$userId');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Can select new quest if no quest for today or quest is from previous day
    return questDate != today;
  }

  // Clear quest data (for testing or reset)
  static Future<void> clearQuestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedQuestKey);
    await prefs.remove(_questDateKey);
    await prefs.remove(_isConfirmedKey);
  }

  // Get time until next quest (midnight)
  static Duration getTimeUntilNextQuest() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  // Check if it's a new day (after midnight)
  static bool isNewDay(String lastQuestDate) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return lastQuestDate != today;
  }

  // Get today's daily quests from database (same for all users)
  static Future<DailyQuest?> getTodaysDailyQuest(String userId) async {
    try {
      final today = DateTime.now();
      
      // Get or create daily quest that's the same for all users
      final dailyQuest = await QuestDatabaseService.getOrCreateDailyQuestForAllUsers(today);
      if (dailyQuest != null) {
        return dailyQuest;
      }
      
      // Fallback to deterministic generation if database fails
      return await QuestDatabaseService.generateRandomDailyQuest(userId);
    } catch (e) {
      print('Error getting today\'s daily quest: $e');
      // Fallback to local generation
      return QuestTemplates.generateDailyQuest();
    }
  }

  // Save user's selected quest for today
  static Future<void> saveSelectedQuestForToday(Quest quest, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questJson = jsonEncode(quest.toJson());
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    await prefs.setString('${_selectedQuestKey}_$userId', questJson);
    await prefs.setString('${_questDateKey}_$userId', today);
    await prefs.setBool('${_isConfirmedKey}_$userId', true);
  }

  // Get user's selected quest for today
  static Future<Quest?> getSelectedQuestForToday(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questJson = prefs.getString('${_selectedQuestKey}_$userId');
    final questDate = prefs.getString('${_questDateKey}_$userId');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Check if quest is from today
    if (questDate != today || questJson == null) {
      return null;
    }
    
    try {
      final questMap = jsonDecode(questJson) as Map<String, dynamic>;
      return Quest.fromJson(questMap);
    } catch (e) {
      return null;
    }
  }

  // Check if user has selected a quest for today
  static Future<bool> hasSelectedQuestForToday(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final questDate = prefs.getString('${_questDateKey}_$userId');
    final today = DateTime.now().toIso8601String().split('T')[0];
    final isConfirmed = prefs.getBool('${_isConfirmedKey}_$userId') ?? false;
    
    return questDate == today && isConfirmed;
  }

  // Clear old quest data (keep only today's)
  static Future<void> clearOldQuestData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Get all keys
    final keys = prefs.getKeys();
    
    // Remove old daily quest data (not from today)
    for (final key in keys) {
      if (key.startsWith('${_dailyQuestKey}_') && !key.endsWith('_$today')) {
        await prefs.remove(key);
      }
    }
  }

  // Database-based quest management methods
  
  // Select a quest for today using database
  static Future<bool> selectQuestForToday(String userId, String questId) async {
    try {
      // For now, use local storage as the primary method
      // This ensures quest selection works even if database is not set up
      print('Selecting quest locally: $questId for user: $userId');
      return await _selectQuestLocally(userId, questId);
    } catch (e) {
      print('Error selecting quest: $e');
      return false;
    }
  }

  // Fallback method to select quest locally
  static Future<bool> _selectQuestLocally(String userId, String questId) async {
    try {
      // Get today's daily quest
      final dailyQuest = await getTodaysDailyQuest(userId);
      if (dailyQuest == null) {
        print('No daily quest available for local selection');
        return false;
      }

      // Find the quest by ID
      Quest? selectedQuest;
      if (questId == dailyQuest.easyQuest.id) {
        selectedQuest = dailyQuest.easyQuest;
      } else if (questId == dailyQuest.mediumQuest.id) {
        selectedQuest = dailyQuest.mediumQuest;
      } else if (questId == dailyQuest.hardQuest.id) {
        selectedQuest = dailyQuest.hardQuest;
      }

      if (selectedQuest == null) {
        print('Quest not found in daily quest options');
        return false;
      }

      // Save locally
      await saveSelectedQuestForToday(selectedQuest, userId);
      return true;
    } catch (e) {
      print('Error in local quest selection: $e');
      return false;
    }
  }

  // Complete a quest using database
  static Future<bool> completeQuest(String userId, String questId, {String? completionNotes}) async {
    try {
      final today = DateTime.now();
      final dailyQuest = await QuestDatabaseService.getDailyQuestForUser(userId, today);
      
      if (dailyQuest == null) {
        print('No daily quest found for today');
        return false;
      }
      
      // Check if the quest is selected
      if (dailyQuest.selectedQuestId != questId) {
        print('Quest not selected for today');
        return false;
      }
      
      // Complete the quest in database
      final success = await QuestDatabaseService.completeQuest(
        userId, 
        dailyQuest.id, 
        questId,
        completionNotes: completionNotes
      );
      
      return success;
    } catch (e) {
      print('Error completing quest: $e');
      return false;
    }
  }

  // Check if user has completed quest today using database
  static Future<bool> hasCompletedQuestToday(String userId) async {
    try {
      return await QuestDatabaseService.hasCompletedQuestToday(userId);
    } catch (e) {
      print('Error checking quest completion: $e');
      return false;
    }
  }

  // Get user quest statistics from database
  static Future<UserQuestStats?> getUserQuestStats(String userId) async {
    try {
      return await QuestDatabaseService.getUserQuestStats(userId);
    } catch (e) {
      print('Error getting user quest stats: $e');
      return null;
    }
  }

  // Get quest completion history from database
  static Future<List<QuestCompletion>> getQuestCompletions(String userId, {int? limit}) async {
    try {
      return await QuestDatabaseService.getQuestCompletions(userId, limit: limit);
    } catch (e) {
      print('Error getting quest completions: $e');
      return [];
    }
  }

  // Evaluate yesterday's quest and award points if successful
  static Future<void> evaluateAndAwardQuestPoints(String userId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayString = yesterday.toIso8601String().split('T')[0];
      
      // Check if user had a quest yesterday
      final prefs = await SharedPreferences.getInstance();
      final questDate = prefs.getString('${_questDateKey}_$userId');
      
      // Only evaluate if user had a quest yesterday and hasn't been evaluated yet
      if (questDate != yesterdayString) {
        print('No quest found for yesterday: $yesterdayString');
        return;
      }
      
      // Check if already evaluated
      final evaluatedKey = 'quest_evaluated_${userId}_$yesterdayString';
      final alreadyEvaluated = prefs.getBool(evaluatedKey) ?? false;
      if (alreadyEvaluated) {
        print('Quest already evaluated for yesterday');
        return;
      }
      
      // Get yesterday's selected quest
      final questJson = prefs.getString('${_selectedQuestKey}_$userId');
      if (questJson == null) {
        print('No quest data found for yesterday');
        return;
      }
      
      final questMap = jsonDecode(questJson) as Map<String, dynamic>;
      final quest = Quest.fromJson(questMap);
      
      // Get user's posts from yesterday
      final posts = await _getUserPostsForDate(userId, yesterday);
      if (posts.isEmpty) {
        print('No posts found for yesterday - quest failed');
        await _markQuestEvaluated(evaluatedKey);
        return;
      }
      
      // Check if any post has more upvotes than downvotes
      bool questSuccessful = false;
      for (final post in posts) {
        if (post['upvotes'] > post['downvotes']) {
          questSuccessful = true;
          break;
        }
      }
      
      if (questSuccessful) {
        // Award points from quest difficulty
        await _awardQuestPoints(userId, quest);
        print('Quest successful! Awarded ${quest.points} points');
      } else {
        print('Quest failed - no posts with positive votes');
      }
      
      // Mark as evaluated to prevent double rewards
      await _markQuestEvaluated(evaluatedKey);
      
    } catch (e) {
      print('Error evaluating quest: $e');
    }
  }
  
  // Get user's posts for a specific date
  static Future<List<Map<String, dynamic>>> _getUserPostsForDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final response = await Supabase.instance.client
          .from('posts')
          .select('''
            id,
            post_likes(user_id),
            post_dislikes(user_id)
          ''')
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
      
      final posts = <Map<String, dynamic>>[];
      for (final post in response as List) {
        final likes = (post['post_likes'] as List<dynamic>? ?? []).length;
        final dislikes = (post['post_dislikes'] as List<dynamic>? ?? []).length;
        
        posts.add({
          'id': post['id'],
          'upvotes': likes,
          'downvotes': dislikes,
        });
      }
      
      return posts;
    } catch (e) {
      print('Error getting user posts for date: $e');
      return [];
    }
  }
  
  // Award points to user for successful quest completion
  static Future<void> _awardQuestPoints(String userId, Quest quest) async {
    try {
      final pointsToAward = _fixedPointsForQuest(quest);
      // Update user's total points in database
      await Supabase.instance.client.rpc('award_quest_points', params: {
        'p_user_id': userId,
        'p_points': pointsToAward,
        'p_quest_id': quest.id,
        'p_quest_title': quest.title,
      });
      
      print('Successfully awarded $pointsToAward points for quest: ${quest.title}');
    } catch (e) {
      print('Error awarding quest points: $e');
      // Fallback: store points locally if database function doesn't exist
      await _awardPointsLocally(userId, quest);
    }
  }
  
  // Fallback method to award points locally
  static Future<void> _awardPointsLocally(String userId, Quest quest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pointsKey = 'user_points_$userId';
      final currentPoints = prefs.getInt(pointsKey) ?? 0;
      final pointsToAward = _fixedPointsForQuest(quest);
      final newPoints = currentPoints + pointsToAward;
      
      await prefs.setInt(pointsKey, newPoints);
      
      // Store quest completion record
      final completionKey = 'quest_completion_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final completionData = {
        'quest_id': quest.id,
        'quest_title': quest.title,
        'points_awarded': pointsToAward,
        'completed_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(completionKey, jsonEncode(completionData));
      
      print('Awarded $pointsToAward points locally. Total: $newPoints');
    } catch (e) {
      print('Error awarding points locally: $e');
    }
  }

  // Fixed points mapping independent of database values
  static int _fixedPointsForQuest(Quest quest) {
    final diff = (quest.difficulty.label).toLowerCase();
    if (diff.contains('leicht') || diff.contains('easy')) return 10;
    if (diff.contains('mittel') || diff.contains('medium')) return 25;
    if (diff.contains('schwer') || diff.contains('hard')) return 50;
    return 10;
  }
  
  // Mark quest as evaluated to prevent double rewards
  static Future<void> _markQuestEvaluated(String evaluatedKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(evaluatedKey, true);
    } catch (e) {
      print('Error marking quest as evaluated: $e');
    }
  }
  
  // Get user's total points (from database or local storage)
  static Future<int> getUserTotalPoints(String userId) async {
    try {
      // Try to get from database first
      final stats = await QuestDatabaseService.getUserQuestStats(userId);
      if (stats != null) {
        return stats.totalPoints;
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_points_$userId') ?? 0;
    } catch (e) {
      print('Error getting user total points: $e');
      return 0;
    }
  }
  
  // Check and evaluate quests when getting today's quest
  static Future<DailyQuest?> getTodaysDailyQuestWithEvaluation(String userId) async {
    try {
      // First, evaluate yesterday's quest if applicable
      await evaluateAndAwardQuestPoints(userId);
      
      // Then get today's quest
      return await getTodaysDailyQuest(userId);
    } catch (e) {
      print('Error in getTodaysDailyQuestWithEvaluation: $e');
      return await getTodaysDailyQuest(userId);
    }
  }

  // =========================
  // Flames (Streak) Management
  // =========================
  // Returns current flame streak
  static Future<int> getFlameStreak(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_flameStreakKey}_$userId') ?? 0;
  }

  // Call this after a successful post creation to update streak
  static Future<void> incrementFlameStreakOnPost(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateTime.now().toIso8601String().split('T')[0];
    final lastPostDate = prefs.getString('${_lastPostDateKey}_$userId');
    int currentStreak = prefs.getInt('${_flameStreakKey}_$userId') ?? 0;

    if (lastPostDate == todayString) {
      // Already posted today; do not increment again
      return;
    }

    if (lastPostDate == null) {
      // First ever post → streak becomes 1
      currentStreak = 1;
    } else {
      // Compare with yesterday
      final last = DateTime.parse(lastPostDate);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final isYesterday = last.year == yesterday.year && last.month == yesterday.month && last.day == yesterday.day;
      if (isYesterday) {
        currentStreak += 1;
      } else {
        // Missed a day or more → reset to 1 (since user posted today)
        currentStreak = 1;
      }
    }

    await prefs.setInt('${_flameStreakKey}_$userId', currentStreak);
    await prefs.setString('${_lastPostDateKey}_$userId', todayString);
  }

  // Call this on app start/resume to reset streak to 0 if the user missed a day
  static Future<void> reconcileFlameStreakOnAppStart(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastPostDate = prefs.getString('${_lastPostDateKey}_$userId');
    if (lastPostDate == null) return; // No posts yet

    final last = DateTime.parse(lastPostDate);
    final today = DateTime.now();
    final lastDateOnly = DateTime(last.year, last.month, last.day);
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final diffDays = todayDateOnly.difference(lastDateOnly).inDays;

    if (diffDays > 1) {
      // Missed at least one full day → streak resets to 0
      await prefs.setInt('${_flameStreakKey}_$userId', 0);
    }
  }
}
