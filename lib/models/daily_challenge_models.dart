import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class DailyChallengeStats {
  const DailyChallengeStats({
    required this.lastCompletedDate,
    required this.lastCorrectDate,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompleted,
    required this.totalCorrect,
    required this.totalAttempts,
  });

  final String lastCompletedDate; // yyyy-MM-dd or ''
  final String lastCorrectDate; // yyyy-MM-dd or ''
  final int currentStreak;
  final int bestStreak;
  final int totalCompleted;
  final int totalCorrect;
  final int totalAttempts;

  static const empty = DailyChallengeStats(
    lastCompletedDate: '',
    lastCorrectDate: '',
    currentStreak: 0,
    bestStreak: 0,
    totalCompleted: 0,
    totalCorrect: 0,
    totalAttempts: 0,
  );

  double get accuracy => totalAttempts <= 0 ? 0 : totalCorrect / totalAttempts;

  DailyChallengeStats copyWith({
    String? lastCompletedDate,
    String? lastCorrectDate,
    int? currentStreak,
    int? bestStreak,
    int? totalCompleted,
    int? totalCorrect,
    int? totalAttempts,
  }) {
    return DailyChallengeStats(
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      lastCorrectDate: lastCorrectDate ?? this.lastCorrectDate,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalAttempts: totalAttempts ?? this.totalAttempts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastCompletedDate': lastCompletedDate,
      'lastCorrectDate': lastCorrectDate,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompleted': totalCompleted,
      'totalCorrect': totalCorrect,
      'totalAttempts': totalAttempts,
    };
  }

  static DailyChallengeStats fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) => v is int ? v : int.tryParse('$v') ?? fallback;
    String asString(dynamic v) => v?.toString() ?? '';

    return DailyChallengeStats(
      lastCompletedDate: asString(json['lastCompletedDate']),
      lastCorrectDate: asString(json['lastCorrectDate']),
      currentStreak: asInt(json['currentStreak'], 0),
      bestStreak: asInt(json['bestStreak'], 0),
      totalCompleted: asInt(json['totalCompleted'], 0),
      totalCorrect: asInt(json['totalCorrect'], 0),
      totalAttempts: asInt(json['totalAttempts'], 0),
    );
  }

  static DailyChallengeStats? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return fromJson(Map<String, dynamic>.from(decoded));
      return null;
    } catch (_) {
      return null;
    }
  }
}

@immutable
class DailyChallengeResult {
  const DailyChallengeResult({
    required this.date,
    required this.problemId,
    required this.scenarioId,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.questionType,
    required this.correctAnswer,
    required this.userAnswer,
    required this.unit,
    required this.isCorrect,
    required this.attempts,
    required this.completedAt,
    required this.countsForStreak,
    required this.hasElevation,
    required this.hasApplianceLoss,
  });

  final String date; // yyyy-MM-dd
  final String problemId;
  final String scenarioId;
  final String title;
  final String category;
  final String difficulty;
  final String questionType;
  final double correctAnswer;
  final double userAnswer;
  final String unit;
  final bool isCorrect;
  final int attempts;
  final String completedAt; // ISO-8601
  final bool countsForStreak;

  /// Heuristic flags used for weak-area insights.
  ///
  /// These are intentionally simple + optional in JSON for backwards
  /// compatibility with older local data.
  final bool hasElevation;
  final bool hasApplianceLoss;

  DailyChallengeResult copyWith({
    String? date,
    String? problemId,
    String? scenarioId,
    String? title,
    String? category,
    String? difficulty,
    String? questionType,
    double? correctAnswer,
    double? userAnswer,
    String? unit,
    bool? isCorrect,
    int? attempts,
    String? completedAt,
    bool? countsForStreak,
    bool? hasElevation,
    bool? hasApplianceLoss,
  }) {
    return DailyChallengeResult(
      date: date ?? this.date,
      problemId: problemId ?? this.problemId,
      scenarioId: scenarioId ?? this.scenarioId,
      title: title ?? this.title,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      questionType: questionType ?? this.questionType,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      userAnswer: userAnswer ?? this.userAnswer,
      unit: unit ?? this.unit,
      isCorrect: isCorrect ?? this.isCorrect,
      attempts: attempts ?? this.attempts,
      completedAt: completedAt ?? this.completedAt,
      countsForStreak: countsForStreak ?? this.countsForStreak,
      hasElevation: hasElevation ?? this.hasElevation,
      hasApplianceLoss: hasApplianceLoss ?? this.hasApplianceLoss,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'problemId': problemId,
      'scenarioId': scenarioId,
      'title': title,
      'category': category,
      'difficulty': difficulty,
      'questionType': questionType,
      'correctAnswer': correctAnswer,
      'userAnswer': userAnswer,
      'unit': unit,
      'isCorrect': isCorrect,
      'attempts': attempts,
      'completedAt': completedAt,
      'countsForStreak': countsForStreak,
      'hasElevation': hasElevation,
      'hasApplianceLoss': hasApplianceLoss,
    };
  }

  static DailyChallengeResult fromJson(Map<String, dynamic> json) {
    String asString(dynamic v) => v?.toString() ?? '';
    double asDouble(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? fallback;
    }

    int asInt(dynamic v, int fallback) => v is int ? v : int.tryParse('$v') ?? fallback;

    bool asBool(dynamic v, bool fallback) {
      if (v is bool) return v;
      final s = (v ?? '').toString().toLowerCase().trim();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return fallback;
    }

    return DailyChallengeResult(
      date: asString(json['date']),
      problemId: asString(json['problemId']),
      scenarioId: asString(json['scenarioId']),
      title: asString(json['title']),
      category: asString(json['category']),
      difficulty: asString(json['difficulty']),
      questionType: asString(json['questionType']),
      correctAnswer: asDouble(json['correctAnswer'], 0),
      userAnswer: asDouble(json['userAnswer'], 0),
      unit: asString(json['unit']),
      isCorrect: asBool(json['isCorrect'], false),
      attempts: asInt(json['attempts'], 1),
      completedAt: asString(json['completedAt']),
      countsForStreak: asBool(json['countsForStreak'], false),
      hasElevation: asBool(json['hasElevation'], false),
      hasApplianceLoss: asBool(json['hasApplianceLoss'], false),
    );
  }
}
