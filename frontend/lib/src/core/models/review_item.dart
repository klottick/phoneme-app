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
    // Handle both nested (API) and flat (local) formats
    final phoneme = json['phonemes'] as Map<String, dynamic>? ?? json;
    final language = phoneme['languages'] as Map<String, dynamic>? ?? json;

    return ReviewItem(
      queueId: json['id'] as String? ?? json['queueId'] as String? ?? '',
      phonemeId: phoneme['id'] as String? ?? json['phonemeId'] as String? ?? '',
      ipaSymbol: phoneme['ipa_symbol'] as String? ?? json['ipaSymbol'] as String? ?? phoneme['ipaSymbol'] as String? ?? '',
      descriptor: phoneme['descriptor'] as String? ?? json['descriptor'] as String? ?? phoneme['descriptor'] as String? ?? '',
      languageCode: language['code'] as String? ?? json['languageCode'] as String? ?? json['language_code'] as String? ?? '',
      dueAt: DateTime.tryParse(json['due_at'] as String? ?? json['dueAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
