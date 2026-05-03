import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_item.dart';

class ProgressRepository {
  ProgressRepository(this._client);

  final SupabaseClient _client;

  Future<List<ReviewItem>> getDueReviews() async {
    try {
      final response = await _client.functions.invoke(
        'next-review',
        method: HttpMethod.post,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(ReviewItem.fromJson)
          .toList();

      return items;
    } catch (_) {
      return const <ReviewItem>[];
    }
  }

  Future<void> submitAttempt({
    required String lessonId,
    required String phonemeId,
    required bool isCorrect,
    String? minimalPairId,
    int? responseTimeMs,
  }) async {
    try {
      await _client.functions.invoke(
        'submit-attempt',
        method: HttpMethod.post,
        body: <String, dynamic>{
          'lesson_id': lessonId,
          'phoneme_id': phonemeId,
          'minimal_pair_id': minimalPairId,
          'is_correct': isCorrect,
          'response_time_ms': responseTimeMs,
        },
      );
    } catch (_) {
      await _client.from('learning_events').insert(
        <String, dynamic>{
          'event_name': 'local_attempt_not_synced',
          'payload': <String, dynamic>{
            'lesson_id': lessonId,
            'phoneme_id': phonemeId,
            'is_correct': isCorrect,
},
        },
      );
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    return {
      'totalAttempts': 0,
      'accuracy': 0.0,
      'correctToday': 0,
      'totalToday': 0,
      'currentStreak': 0,
      'longestStreak': 0,
    };
  }
}
