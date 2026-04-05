import 'dart:convert';

import 'package:http/http.dart' as http;

class BusinessAiService {
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _geminiModel = 'gemini-2.5-flash';

  Future<String> generateNextSteps({required String businessSummary}) async {
    return _generateText(
      prompt:
          'You are an inventory and sales advisor for a wholesale business. '
          'Based on this summary, provide 5 short, practical next actions. '
          'Keep output concise, numbered, and operational. Summary: $businessSummary',
      fallback: _localFallback(businessSummary),
    );
  }

  Future<String> generateStockPlan({required String stockSummary}) async {
    return _generateText(
      prompt:
          'You are a stock planning assistant for a wholesale business. '
          'Use the data to identify low-stock items, high-stock items, slow-moving items, '
          'and give a practical next-week plan. Be explicit about what to restock more, '
          'what to keep lower, and what to promote. Output 5 concise bullet points. '
          'Stock data: $stockSummary',
      fallback: _stockFallback(stockSummary),
    );
  }

  Future<String> _generateText({
    required String prompt,
    required String fallback,
  }) async {
    if (_geminiApiKey.trim().isEmpty) {
      return fallback;
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey',
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
        final candidates = body['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, dynamic>) {
            final content = first['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                final text = (parts.first as Map<String, dynamic>)['text']
                    .toString()
                    .trim();
                if (text.isNotEmpty) {
                  return text;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Fall through to local strategy.
    }

    return fallback;
  }

  String _localFallback(String summary) {
    return '1. Increase stock for top 3 frequently bought products this week.\n'
        '2. Offer a volume discount to the most active retailers to boost repeat orders.\n'
        '3. Reduce slow-moving inventory by running a limited-time bundle offer.\n'
        '4. Keep dispatch SLA under 24h for all pending orders to improve completion rate.\n'
        '5. Review ratings and fix issues for products below 4.0 to reduce churn.\n\n'
        'Summary used: $summary';
  }

  String _stockFallback(String summary) {
    return '1. Restock low-stock items first so you do not miss quick sales.\n'
        '2. Keep low-selling items in smaller quantities next week to reduce dead stock.\n'
        '3. Increase stock only for items with strong demand and fast turnover.\n'
        '4. Promote high-stock slow movers with bundles or discounts.\n'
        '5. Review this summary again after one week and reorder based on actual movement.\n\n'
        'Summary used: $summary';
  }
}
