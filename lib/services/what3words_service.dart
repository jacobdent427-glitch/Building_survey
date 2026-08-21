import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thrown by [What3WordsService.wordsForCoordinates] with a message that's
/// safe to show directly to the surveyor.
class What3WordsException implements Exception {
  final String message;
  What3WordsException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around the what3words API. The what3words field is always a
/// plain text field the surveyor can type into directly (works fully
/// offline); this service only adds two things on top when a key is
/// configured and the device is online: typeahead suggestions, and
/// converting a GPS position into its 3-word address.
class What3WordsService {
  static const _autosuggestEndpoint = 'https://api.what3words.com/v3/autosuggest';
  static const _convertEndpoint = 'https://api.what3words.com/v3/convert-to-3wa';

  /// Suggestions as the surveyor types. Any failure is swallowed and yields
  /// no suggestions rather than blocking data entry.
  Future<List<String>> suggest(String partialInput) async {
    if (!AppConfig.hasWhat3words || partialInput.trim().length < 3) return [];

    try {
      final uri = Uri.parse(_autosuggestEndpoint).replace(
        queryParameters: {'input': partialInput, 'key': AppConfig.what3wordsApiKey},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = body['suggestions'] as List? ?? [];
      return suggestions.map((s) => (s as Map<String, dynamic>)['words'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  /// Converts a GPS position into its what3words address. Unlike [suggest],
  /// this is triggered by an explicit "use my location" tap, so failures are
  /// surfaced (as [What3WordsException]) rather than silently swallowed -
  /// the surveyor is waiting on a result, not typing ahead.
  Future<String> wordsForCoordinates(double latitude, double longitude) async {
    if (!AppConfig.hasWhat3words) {
      throw What3WordsException('No what3words API key is configured for this build.');
    }

    http.Response response;
    try {
      final uri = Uri.parse(_convertEndpoint).replace(
        queryParameters: {
          'coordinates': '$latitude,$longitude',
          'key': AppConfig.what3wordsApiKey,
        },
      );
      response = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      throw What3WordsException('Could not reach what3words - check your connection.');
    }

    if (response.statusCode != 200) {
      throw What3WordsException(_describeError(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final words = body['words'] as String?;
    if (words == null) {
      throw What3WordsException('what3words did not return an address for this location.');
    }
    return words;
  }

  /// Turns a non-200 response into a message that explains what actually
  /// went wrong, using what3words' own error body
  /// (`{"error": {"code": ..., "message": ...}}`) when present. HTTP 402
  /// specifically means the API key has exceeded its plan's request quota -
  /// that's an account/billing issue on what3words' side, not something the
  /// app itself can retry its way out of.
  String _describeError(http.Response response) {
    String? apiMessage;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      apiMessage = (body['error'] as Map<String, dynamic>?)?['message'] as String?;
    } catch (_) {
      // Response body wasn't JSON, or didn't have the expected shape.
    }

    if (response.statusCode == 402) {
      return apiMessage != null
          ? 'what3words: $apiMessage - this API key has hit its usage quota. Check the plan at what3words.com/select-plan.'
          : 'This what3words API key has hit its usage quota (HTTP 402). Check the plan at what3words.com/select-plan.';
    }

    return apiMessage != null
        ? 'what3words: $apiMessage'
        : 'what3words lookup failed (HTTP ${response.statusCode}).';
  }
}
