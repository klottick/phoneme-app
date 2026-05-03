class MinimalPair {
  const MinimalPair({
    required this.id,
    required this.wordA,
    required this.wordB,
    required this.phonemeA,
    required this.phonemeB,
  });

  final String id;
  final String wordA;
  final String wordB;
  final String phonemeA;
  final String phonemeB;

  factory MinimalPair.fromJson(Map<String, dynamic> json) {
    return MinimalPair(
      id: json['id'] as String,
      wordA: json['word_a'] as String? ?? '',
      wordB: json['word_b'] as String? ?? '',
      phonemeA: json['phoneme_a']?['ipa_symbol'] as String? ?? '',
      phonemeB: json['phoneme_b']?['ipa_symbol'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word_a': wordA,
        'word_b': wordB,
        'phoneme_a': phonemeA,
        'phoneme_b': phonemeB,
      };
}
