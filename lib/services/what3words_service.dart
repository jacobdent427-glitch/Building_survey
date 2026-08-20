import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thin wrapper around the what3words autosuggest API. The what3words field
/// is always a plain text field the surveyor can type into directly (works
/// fully offline); this service only adds suggestions on top when a key is
/// configured and the device is online. Any failure is swallowed and yields
/// no suggestions rather than blocking data entry.
class What3WordsService {
  static const _endpoint = 'https://api.what3words.com/v3/autosuggest';

  Future<List<String>> suggest(String partialInput) async {
    if (!AppConfig.hasWhat3words || partialInput.trim().length < 3) return [];

    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'input': partialInput,
        'key': AppConfig.what3wordsApiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = body['suggestions'] as List? ?? [];
      return suggestions
          .map((s) => (s as Map<String, dynamic>)['words'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
