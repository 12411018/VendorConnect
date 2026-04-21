import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BusinessAiService {
  // Provided by user for local development.
  static const String _embeddedMistralApiKey =
      'qvrQzPSAiVkzWh9Vh6QtrjphPOj9J1Eh';
  static const String _envMistralApiKey = String.fromEnvironment(
    'MISTRAL_API_KEY',
  );
  static const String _mistralModel = 'mistral-small-latest';

  // Optional embedded key for local testing. Prefer dart-define in production.
  static const String _embeddedGeminiApiKey = '';
  static const String _envGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const String _envGoogleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
  );
  static const String _geminiModel = 'gemini-2.5-flash';

  String get _mistralApiKey {
    final embedded = _embeddedMistralApiKey.trim();
    if (embedded.isNotEmpty) {
      return embedded;
    }
    return _envMistralApiKey.trim();
  }

  String get _geminiApiKey {
    final embedded = _embeddedGeminiApiKey.trim();
    if (embedded.isNotEmpty) {
      return embedded;
    }

    final gemini = _envGeminiApiKey.trim();
    if (gemini.isNotEmpty) {
      return gemini;
    }

    return _envGoogleApiKey.trim();
  }

  Future<String> generateNextSteps({required String businessSummary}) async {
    return _generateText(
      prompt:
          'You are an inventory and sales advisor for a wholesale business. '
          'Based on this summary, provide 5 short, practical next actions. '
          'Keep output concise, numbered, and operational. '
          'Return plain text only. Do not use markdown, bold text, bullets like -, *, or headings. '
          'Use one relevant emoji at the start of each numbered point. '
          'Summary: $businessSummary',
      fallback: _localFallback(businessSummary),
    );
  }

  Future<String> generateStockPlan({required String stockSummary}) async {
    return _generateText(
      prompt:
          'You are a stock planning assistant for a wholesale business. '
          'Use the data to identify low-stock items, high-stock items, slow-moving items, '
          'and give a practical next-week plan. Be explicit about what to restock more, '
          'what to keep lower, and what to promote. Output 5 concise numbered points. '
          'Return plain text only. Do not use markdown, bold text, bullets like -, *, or headings. '
          'Use one relevant emoji at the start of each numbered point. '
          'Stock data: $stockSummary',
      fallback: _stockFallback(stockSummary),
    );
  }

  Future<String> _generateText({
    required String prompt,
    required String fallback,
  }) async {
    final mistralText = await _generateWithMistral(prompt: prompt);
    if (mistralText.isNotEmpty) {
      return _formatForUi(mistralText);
    }

    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      return _formatForUi(fallback);
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$apiKey',
      );

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 280},
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractGeneratedText(body);
        if (text.isNotEmpty) {
          return _formatForUi(text);
        }
      } else if (kDebugMode) {
        debugPrint(
          '[BusinessAiService][Gemini] ${response.statusCode}: ${response.body}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BusinessAiService][Gemini][Exception] $error');
      }
    }

    return _formatForUi(fallback);
  }

  String _formatForUi(String rawText) {
    final lines = rawText
        .replaceAll('**', '')
        .replaceAll('```', '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final cleaned = <String>[];
    for (final line in lines) {
      var text = line;
      text = text.replaceFirst(RegExp(r'^[-*•]+\s*'), '');
      text = text.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
      text = text.replaceFirst(
        RegExp(r"^(here's|heres)\b[^:]*:\s*", caseSensitive: false),
        '',
      );
      text = text.trim();
      if (text.isNotEmpty) {
        cleaned.add(text);
      }
    }

    if (cleaned.isEmpty) {
      return rawText.trim();
    }

    final points = cleaned.take(5).toList(growable: false);
    final buffer = StringBuffer();
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        buffer.writeln();
      }
      buffer.write('${i + 1}. ${points[i]}');
    }
    return buffer.toString();
  }

  Future<String> _generateWithMistral({required String prompt}) async {
    final apiKey = _mistralApiKey;
    if (apiKey.isEmpty) {
      return '';
    }

    try {
      final uri = Uri.parse('https://api.mistral.ai/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _mistralModel,
          'temperature': 0.4,
          'max_tokens': 300,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = body['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            if (message is Map<String, dynamic>) {
              final content = (message['content'] ?? '').toString().trim();
              if (content.isNotEmpty) {
                return content;
              }
            }
          }
        }
      } else if (kDebugMode) {
        debugPrint(
          '[BusinessAiService][Mistral] ${response.statusCode}: ${response.body}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BusinessAiService][Mistral][Exception] $error');
      }
    }

    return '';
  }

  String _extractGeneratedText(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) {
        continue;
      }

      final content = candidate['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }

      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        continue;
      }

      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          final text = (part['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
            }
            buffer.write(text);
          }
        }
      }

      final generated = buffer.toString().trim();
      if (generated.isNotEmpty) {
        return generated;
      }
    }

    return '';
  }

  String _localFallback(String summary) {
    return '1. Increase stock for top 3 frequently bought products this week.\n'
        '2. Offer a volume discount to the most active retailers to boost repeat orders.\n'
        '3. Reduce slow-moving inventory by running a limited-time bundle offer.\n'
        '4. Keep dispatch SLA under 24h for all pending orders to improve completion rate.\n'
        '5. Review ratings and fix issues for products below 4.0 to reduce churn.\n\n';
  }

  String _stockFallback(String summary) {
    return '1. Restock low-stock items first so you do not miss quick sales.\n'
        '2. Keep low-selling items in smaller quantities next week to reduce dead stock.\n'
        '3. Increase stock only for items with strong demand and fast turnover.\n'
        '4. Promote high-stock slow movers with bundles or discounts.\n'
        '5. Review this summary again after one week and reorder based on actual movement.\n\n';
  }
}
