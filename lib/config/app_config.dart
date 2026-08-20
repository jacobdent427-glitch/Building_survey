/// Build-time configuration. Secrets are supplied via --dart-define so they
/// never need to be hardcoded into source control, e.g.:
///   flutter run --dart-define=WHAT3WORDS_API_KEY=your-key-here
class AppConfig {
  static const what3wordsApiKey = String.fromEnvironment(
    'WHAT3WORDS_API_KEY',
    defaultValue: '',
  );

  static bool get hasWhat3words => what3wordsApiKey.isNotEmpty;
}
