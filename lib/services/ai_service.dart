import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ScannedMedication {
  final String name;
  final String dosage;
  final String frequency;
  final String notes;
  final String duration;

  ScannedMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.notes,
    required this.duration,
  });

  factory ScannedMedication.fromMap(Map<String, dynamic> map) {
    return ScannedMedication(
      name: (map['name'] ?? '').toString().trim(),
      dosage: (map['dosage'] ?? '').toString().trim(),
      frequency: (map['frequency'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      duration: (map['duration'] ?? '').toString().trim(),
    );
  }
}

class AiService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<Map<String, String>?> scanMedicationImage(String base64Image) async {
    final prompt = '''You are a medical assistant. Look at this medication
image and extract the medication details. Return ONLY a valid JSON object
with these exact fields (no markdown, no explanation):
{"name": "medication name", "dosage": "dosage amount and form", "notes": "any special instructions or warnings"}
If you cannot determine a field, use an empty string. Return only the JSON.''';

    final result = await _callGemini(base64Image: base64Image, prompt: prompt);
    if (result == null) return null;

    try {
      final json = jsonDecode(result) as Map<String, dynamic>;
      return {
        'name': (json['name'] ?? '').toString(),
        'dosage': (json['dosage'] ?? '').toString(),
        'notes': (json['notes'] ?? '').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<ScannedMedication>?> scanPrescriptionImage(
      String base64Image) async {
    final prompt = '''You are a medical assistant. Look at this prescription
image and extract ALL medications listed. Return ONLY a valid JSON array
(no markdown, no explanation) where each item has:
{"name": "medication name", "dosage": "dosage amount", "frequency": "how often e.g. twice daily", "notes": "special instructions", "duration": "e.g. 7 days or ongoing"}
If you cannot determine a field, use an empty string. Return only the JSON array.''';

    final result = await _callGemini(base64Image: base64Image, prompt: prompt);
    if (result == null) return null;

    try {
      final json = jsonDecode(result);
      if (json is! List) return null;
      return json
          .map((item) =>
              ScannedMedication.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((med) => med.name.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _callGemini({
    required String base64Image,
    required String prompt,
  }) async {
    final key = AppConfig.geminiApiKey;
    if (key == 'YOUR_GEMINI_API_KEY_HERE' || key.isEmpty) {
      throw Exception('Gemini API key not configured. Please update lib/config/app_config.dart');
    }

    final url = Uri.parse('$_baseUrl?key=$key');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseJson['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    final text = (parts[0]['text'] ?? '').toString().trim();

    // Strip markdown code blocks if present
    if (text.startsWith('```')) {
      final lines = text.split('\n');
      final cleaned = lines
          .skip(1)
          .takeWhile((l) => !l.startsWith('```'))
          .join('\n')
          .trim();
      return cleaned;
    }

    return text;
  }
}
