class Phoneme {
  const Phoneme({
    required this.id,
    required this.languageCode,
    required this.ipaSymbol,
    required this.descriptor,
    required this.difficultyLevel,
  });

  final String id;
  final String languageCode;
  final String ipaSymbol;
  final String descriptor;
  final int difficultyLevel;

  factory Phoneme.fromJson(Map<String, dynamic> json) {
    return Phoneme(
      id: json['id'] as String,
      languageCode: json['languages']?['code'] as String? ?? '',
      ipaSymbol: json['ipa_symbol'] as String? ?? '',
      descriptor: json['descriptor'] as String? ?? '',
      difficultyLevel: json['difficulty_level'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'languageCode': languageCode,
        'ipa_symbol': ipaSymbol,
        'descriptor': descriptor,
        'difficulty_level': difficultyLevel,
      };
}
