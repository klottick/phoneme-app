class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'en', label: 'English'),
  SupportedLanguage(code: 'fr', label: 'French'),
  SupportedLanguage(code: 'ja', label: 'Japanese'),
];
