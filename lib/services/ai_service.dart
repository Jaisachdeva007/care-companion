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
  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'nvidia/nemotron-nano-12b-v2-vl:free';

  Future<Map<String, String>?> scanMedicationImage(String base64Image,
      {String mimeType = 'image/jpeg'}) async {
    final prompt =
        '''You are a medical assistant. Look at this medication image and extract the medication details. Return ONLY a valid JSON object with these exact fields (no markdown, no explanation):
{"name": "medication name", "dosage": "dosage amount and form", "notes": "any special instructions or warnings"}
If you cannot determine a field, use an empty string. Return only the JSON.''';

    final result = await _callOpenRouter(
        base64Image: base64Image, prompt: prompt, mimeType: mimeType);
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

  Future<List<ScannedMedication>?> scanPrescriptionImage(String base64Image,
      {String mimeType = 'image/jpeg'}) async {
    final prompt =
        '''You are a medical assistant. Look at this prescription image and extract ALL medications listed. Return ONLY a valid JSON array (no markdown, no explanation) where each item has:
{"name": "medication name", "dosage": "dosage amount", "frequency": "how often e.g. twice daily", "notes": "special instructions", "duration": "e.g. 7 days or ongoing"}
If you cannot determine a field, use an empty string. Return only the JSON array.''';

    final result = await _callOpenRouter(
        base64Image: base64Image, prompt: prompt, mimeType: mimeType);
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

  Future<String?> _callOpenRouter({
    required String base64Image,
    required String prompt,
    String mimeType = 'image/jpeg',
  }) async {
    final key = AppConfig.geminiApiKey;
    if (key == 'YOUR_API_KEY_HERE' || key.isEmpty) {
      throw Exception('API key not configured. Please update lib/config/app_config.dart');
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'max_tokens': 1024,
      'temperature': 0.1,
    });

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://care-companion-43428.web.app',
        'X-Title': 'Care Companion',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('AI API error ${response.statusCode}: ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final text = (message?['content'] ?? '').toString().trim();

    if (text.startsWith('```')) {
      final lines = text.split('\n');
      return lines
          .skip(1)
          .takeWhile((l) => !l.startsWith('```'))
          .join('\n')
          .trim();
    }

    return text;
  }
}
