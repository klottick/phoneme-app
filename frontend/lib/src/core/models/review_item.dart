class ReviewItem {
  const ReviewItem({
    required this.queueId,
    required this.phonemeId,
    required this.ipaSymbol,
    required this.descriptor,
    required this.languageCode,
    required this.dueAt,
  });

  final String queueId;
  final String phonemeId;
  final String ipaSymbol;
  final String descriptor;
  final String languageCode;
  final DateTime dueAt;

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final phoneme = (json['phonemes'] as Map<String, dynamic>? ?? {});
    final language =
        (phoneme['languages'] as Map<String, dynamic>? ?? <String, dynamic>{});

    return ReviewItem(
      queueId: json['id'] as String,
      phonemeId: phoneme['id'] as String? ?? '',
      ipaSymbol: phoneme['ipa_symbol'] as String? ?? '',
      descriptor: phoneme['descriptor'] as String? ?? '',
      languageCode: language['code'] as String? ?? '',
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
