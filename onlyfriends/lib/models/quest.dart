import 'package:flutter/material.dart';
import '../services/quest_database_service.dart';

enum QuestDifficulty {
  easy('Leicht', Icons.star_outline, Color(0xFF4CAF50)),
  medium('Mittel', Icons.star_half, Color(0xFFFF9800)),
  hard('Schwer', Icons.star, Color(0xFFF44336));

  const QuestDifficulty(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Quest {
  final String id;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final int points;
  final String category;
  final DateTime createdAt;
  final bool isCompleted;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.points,
    required this.category,
    required this.createdAt,
    this.isCompleted = false,
  });

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    QuestDifficulty? difficulty,
    int? points,
    String? category,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
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
      'created_at': createdAt.toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: QuestDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => QuestDifficulty.easy,
      ),
      points: json['points'] as int,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  // Create Quest from QuestTemplate (for database integration)
  factory Quest.fromTemplate(QuestTemplate template) {
    return Quest(
      id: template.id,
      title: template.title,
      description: template.description,
      difficulty: template.difficulty,
      points: template.points,
      category: template.category,
      createdAt: template.createdAt ?? DateTime.now(),
      isCompleted: false,
    );
  }
}

class DailyQuest {
  final String id;
  final Quest easyQuest;
  final Quest mediumQuest;
  final Quest hardQuest;
  final DateTime date;
  final String? selectedQuestId;
  final bool isCompleted;

  const DailyQuest({
    required this.id,
    required this.easyQuest,
    required this.mediumQuest,
    required this.hardQuest,
    required this.date,
    this.selectedQuestId,
    this.isCompleted = false,
  });

  Quest? get selectedQuest {
    if (selectedQuestId == null) return null;
    if (selectedQuestId == easyQuest.id) return easyQuest;
    if (selectedQuestId == mediumQuest.id) return mediumQuest;
    if (selectedQuestId == hardQuest.id) return hardQuest;
    return null;
  }

  DailyQuest copyWith({
    String? id,
    Quest? easyQuest,
    Quest? mediumQuest,
    Quest? hardQuest,
    DateTime? date,
    String? selectedQuestId,
    bool? isCompleted,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      easyQuest: easyQuest ?? this.easyQuest,
      mediumQuest: mediumQuest ?? this.mediumQuest,
      hardQuest: hardQuest ?? this.hardQuest,
      date: date ?? this.date,
      selectedQuestId: selectedQuestId ?? this.selectedQuestId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'easy_quest': easyQuest.toJson(),
      'medium_quest': mediumQuest.toJson(),
      'hard_quest': hardQuest.toJson(),
      'date': date.toIso8601String().split('T')[0], // Only date part
      'selected_quest_id': selectedQuestId,
      'is_completed': isCompleted,
    };
  }

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String,
      easyQuest: Quest.fromJson(json['easy_quest'] as Map<String, dynamic>),
      mediumQuest: Quest.fromJson(json['medium_quest'] as Map<String, dynamic>),
      hardQuest: Quest.fromJson(json['hard_quest'] as Map<String, dynamic>),
      date: DateTime.parse(json['date'] as String),
      selectedQuestId: json['selected_quest_id'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  // Create DailyQuest from database response
  factory DailyQuest.fromDatabaseJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String,
      easyQuest: Quest.fromTemplate(QuestTemplate.fromJson(json['easy_quest'] as Map<String, dynamic>)),
      mediumQuest: Quest.fromTemplate(QuestTemplate.fromJson(json['medium_quest'] as Map<String, dynamic>)),
      hardQuest: Quest.fromTemplate(QuestTemplate.fromJson(json['hard_quest'] as Map<String, dynamic>)),
      date: DateTime.parse(json['quest_date'] as String),
      selectedQuestId: json['selected_quest_id'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}

// Predefined quest templates for each difficulty
class QuestTemplates {
  static final List<Quest> easyQuests = [
    Quest(
      id: 'easy_1',
      title: 'Morgengruß',
      description: 'Sage 3 Freunden "Guten Morgen"',
      difficulty: QuestDifficulty.easy,
      points: 10,
      category: 'Sozial',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_2',
      title: 'Gelbes Auto',
      description: 'Mache ein Foto von einem gelben Auto',
      difficulty: QuestDifficulty.easy,
      points: 15,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_3',
      title: 'Freundschaft',
      description: 'Reagiere auf 5 Posts deiner Freunde',
      difficulty: QuestDifficulty.easy,
      points: 12,
      category: 'Sozial',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_4',
      title: 'Rote Blume',
      description: 'Fotografiere eine rote Blume oder Pflanze',
      difficulty: QuestDifficulty.easy,
      points: 12,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_5',
      title: 'Frühstück',
      description: 'Teile ein Foto von deinem Frühstück',
      difficulty: QuestDifficulty.easy,
      points: 10,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_6',
      title: 'Wolken',
      description: 'Mache ein Foto von interessanten Wolken am Himmel',
      difficulty: QuestDifficulty.easy,
      points: 8,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'easy_7',
      title: 'Schuhe',
      description: 'Fotografiere deine Schuhe von heute',
      difficulty: QuestDifficulty.easy,
      points: 10,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
  ];

  static final List<Quest> mediumQuests = [
    Quest(
      id: 'medium_1',
      title: 'Gruppenaktivität',
      description: 'Organisiere eine Gruppenaktivität mit 3+ Freunden',
      difficulty: QuestDifficulty.medium,
      points: 25,
      category: 'Sozial',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_2',
      title: 'Sonnenuntergang',
      description: 'Fotografiere einen schönen Sonnenuntergang',
      difficulty: QuestDifficulty.medium,
      points: 30,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_3',
      title: 'Tagesrückblick',
      description: 'Teile einen ausführlichen Tagesrückblick mit deinen Freunden',
      difficulty: QuestDifficulty.medium,
      points: 20,
      category: 'Reflexion',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_4',
      title: 'Architektur',
      description: 'Mache ein Foto von einem interessanten Gebäude',
      difficulty: QuestDifficulty.medium,
      points: 25,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_5',
      title: 'Spiegel-Selfie',
      description: 'Erstelle ein kreatives Spiegel-Selfie',
      difficulty: QuestDifficulty.medium,
      points: 22,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_6',
      title: 'Street Art',
      description: 'Fotografiere ein Graffiti oder Street Art Kunstwerk',
      difficulty: QuestDifficulty.medium,
      points: 28,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'medium_7',
      title: 'Tier-Foto',
      description: 'Mache ein Foto von einem Tier (Hund, Katze, Vogel, etc.)',
      difficulty: QuestDifficulty.medium,
      points: 20,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
  ];

  static final List<Quest> hardQuests = [
    Quest(
      id: 'hard_1',
      title: 'Community Event',
      description: 'Organisiere ein größeres Event für deine Freundesgruppe',
      difficulty: QuestDifficulty.hard,
      points: 50,
      category: 'Führung',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_2',
      title: 'Foto-Serie',
      description: 'Erstelle eine 5-teilige Foto-Serie zu einem Thema',
      difficulty: QuestDifficulty.hard,
      points: 60,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_3',
      title: 'Freundschaftsbrücke',
      description: 'Verbinde zwei deiner Freunde, die sich noch nicht kennen',
      difficulty: QuestDifficulty.hard,
      points: 40,
      category: 'Sozial',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_4',
      title: 'Nacht-Fotografie',
      description: 'Mache ein beeindruckendes Foto bei Nacht oder in der Dämmerung',
      difficulty: QuestDifficulty.hard,
      points: 45,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_5',
      title: 'Portrait-Challenge',
      description: 'Fotografiere 3 verschiedene Menschen in kreativen Posen',
      difficulty: QuestDifficulty.hard,
      points: 55,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_6',
      title: 'Makro-Fotografie',
      description: 'Erstelle ein detailliertes Makro-Foto von etwas Kleinem',
      difficulty: QuestDifficulty.hard,
      points: 50,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
    Quest(
      id: 'hard_7',
      title: 'Action-Foto',
      description: 'Fotografiere eine Sport- oder Bewegungsaktivität',
      difficulty: QuestDifficulty.hard,
      points: 48,
      category: 'Foto',
      createdAt: DateTime.now(),
    ),
  ];

  static Quest getRandomEasyQuest() {
    final random = DateTime.now().millisecondsSinceEpoch % easyQuests.length;
    return easyQuests[random].copyWith(
      id: '${easyQuests[random].id}_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
  }

  static Quest getRandomMediumQuest() {
    final random = DateTime.now().millisecondsSinceEpoch % mediumQuests.length;
    return mediumQuests[random].copyWith(
      id: '${mediumQuests[random].id}_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
  }

  static Quest getRandomHardQuest() {
    final random = DateTime.now().millisecondsSinceEpoch % hardQuests.length;
    return hardQuests[random].copyWith(
      id: '${hardQuests[random].id}_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
    );
  }

  // Generate the same daily quests for ALL users based on the current date
  static DailyQuest generateDailyQuest() {
    final today = DateTime.now();
    final todayString = today.toIso8601String().split('T')[0];
    
    // Use the date as a seed to ensure all users get the same quests
    final seed = todayString.hashCode;
    
    // Generate quests based on the date seed (same for all users)
    final easyQuest = _getQuestBySeed(easyQuests, seed);
    final mediumQuest = _getQuestBySeed(mediumQuests, seed + 1);
    final hardQuest = _getQuestBySeed(hardQuests, seed + 2);
    
    return DailyQuest(
      id: 'daily_$todayString',
      easyQuest: easyQuest.copyWith(
        id: '${easyQuest.id}_$todayString',
        createdAt: today,
      ),
      mediumQuest: mediumQuest.copyWith(
        id: '${mediumQuest.id}_$todayString',
        createdAt: today,
      ),
      hardQuest: hardQuest.copyWith(
        id: '${hardQuest.id}_$todayString',
        createdAt: today,
      ),
      date: today,
    );
  }
  
  // Helper method to get a quest by seed (deterministic)
  static Quest _getQuestBySeed(List<Quest> quests, int seed) {
    final index = seed.abs() % quests.length;
    return quests[index];
  }
}
