import 'api_client.dart';

/// High-level API Service mapping backend domain endpoints to typed payloads.
class StemlyApiService {
  final ApiClient _client;

  StemlyApiService({required ApiClient client}) : _client = client;

  ApiClient get client => _client;

  /// Uploads a STEM worksheet/problem image for analysis and OCR.
  Future<Map<String, dynamic>> uploadScan({
    required List<int> imageBytes,
    required String filename,
    String? ocrText,
  }) async {
    final response = await _client.uploadFile(
      '/scan/upload',
      fileField: 'file',
      fileBytes: imageBytes,
      filename: filename,
      fields: (ocrText != null && ocrText.isNotEmpty)
          ? {'ocr_text': ocrText}
          : null,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw FormatException("Unexpected scan response format: $response");
  }

  /// Generates structured STEM notes and formulas for a topic.
  Future<Map<String, dynamic>> generateNotes({
    required String topic,
    required List<String> variables,
    String? imagePath,
    String? historyId,
    String? ocrText,
  }) async {
    final response = await _client.post(
      '/notes/generate',
      body: {
        'topic': topic,
        'variables': variables,
        'image_path': imagePath ?? '',
        'history_id': historyId,
        'ocr_text': ocrText ?? '',
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw FormatException("Unexpected notes response format: $response");
  }

  /// Generates a customized multiple-choice quiz for the topic.
  Future<Map<String, dynamic>> generateQuiz({
    required String topic,
    int count = 5,
  }) async {
    final response = await _client.get(
      '/quiz/generate',
      queryParameters: {'topic': topic, 'count': count},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw FormatException("Unexpected quiz response format: $response");
  }

  /// Submits quiz results to track learning mastery.
  Future<Map<String, dynamic>> submitQuiz({
    required String topic,
    required int score,
    required int total,
  }) async {
    final response = await _client.post(
      '/quiz/submit',
      body: {'topic': topic, 'score': score, 'total': total},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'status': 'success'};
  }

  /// Natural language interaction with STEM AI Tutor (backend only).
  Future<Map<String, dynamic>> askTutor({
    required String message,
    String? topic,
    List<Map<String, String>>? history,
  }) async {
    final response = await _client.post(
      '/chat/ask',
      body: {'message': message, 'topic': topic, 'history': history ?? []},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw FormatException("Unexpected chat response format: $response");
  }

  /// Natural language parameter adjustment for interactive physics visualiser.
  Future<Map<String, dynamic>> updateVisualiser({
    required String templateId,
    required Map<String, dynamic> parameters,
    required String userPrompt,
    String? historyId,
  }) async {
    final response = await _client.post(
      '/visualiser/update',
      body: {
        'template_id': templateId,
        'parameters': parameters,
        'user_prompt': userPrompt,
        'history_id': historyId,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw FormatException("Unexpected visualiser update format: $response");
  }

  /// Retrieves user scan history from the backend with pagination.
  Future<Map<String, dynamic>> fetchHistory({
    int limit = 20,
    int skip = 0,
  }) async {
    final response = await _client.get(
      '/scan/history',
      queryParameters: {'limit': limit, 'skip': skip},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'history': []};
  }

  /// Deletes all user data from the server (GDPR / Privacy).
  Future<Map<String, dynamic>> deleteMyData() async {
    final response = await _client.delete('/auth/me/data');
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'status': 'success'};
  }
}
