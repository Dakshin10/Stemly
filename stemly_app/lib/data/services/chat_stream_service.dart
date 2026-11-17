import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/api_exceptions.dart';
import 'api_client.dart';

/// Enumeration of all discrete SSE event types in Streaming Protocol v2.
enum StreamEventType {
  meta,
  token,
  parameters,
  followups,
  error,
  usage,
  done,
  unknown,
}

/// Standardized event envelope payload for SSE frames in Streaming Protocol v2.
/// Schema: `{v: 1, id: String, seq: int, type: String, data: Map<String, dynamic>}`
class StreamEventEnvelope {
  final int version;
  final String id;
  final int sequence;
  final StreamEventType type;
  final Map<String, dynamic> data;

  const StreamEventEnvelope({
    required this.version,
    required this.id,
    required this.sequence,
    required this.type,
    required this.data,
  });

  /// Factory constructor to deserialize raw JSON into a typed envelope.
  /// Seamlessly bridges modern v2 payloads and v1 legacy aliases.
  factory StreamEventEnvelope.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'unknown';
    final eventType = _parseEventType(rawType);
    final rawData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    // Backward-compatibility: if root keys exist (e.g. content, updates, suggestions), populate into data
    final mergedData = Map<String, dynamic>.from(rawData);
    if (json.containsKey('content') && !mergedData.containsKey('delta')) {
      mergedData['delta'] = json['content'];
    }
    if (json.containsKey('updates') && !mergedData.containsKey('updates')) {
      mergedData['updates'] = json['updates'];
    }
    if (json.containsKey('suggestions') &&
        !mergedData.containsKey('suggestions')) {
      mergedData['suggestions'] = json['suggestions'];
    }

    return StreamEventEnvelope(
      version: json['v'] as int? ?? 1,
      id: json['id'] as String? ?? '',
      sequence: json['seq'] as int? ?? 0,
      type: eventType,
      data: mergedData,
    );
  }

  static StreamEventType _parseEventType(String type) {
    switch (type.toLowerCase()) {
      case 'meta':
        return StreamEventType.meta;
      case 'token':
        return StreamEventType.token;
      case 'parameters':
        return StreamEventType.parameters;
      case 'followups':
        return StreamEventType.followups;
      case 'error':
        return StreamEventType.error;
      case 'usage':
        return StreamEventType.usage;
      case 'done':
        return StreamEventType.done;
      default:
        return StreamEventType.unknown;
    }
  }

  // --- Convenience Getters ---

  /// Token delta text (e.g. " The", " velocity", " is")
  String? get tokenDelta {
    if (type != StreamEventType.token) return null;
    return (data['delta'] as String?) ?? (data['content'] as String?);
  }

  /// Clamped/validated physics simulation parameter updates
  Map<String, dynamic>? get parameterUpdates {
    if (type != StreamEventType.parameters) return null;
    final updates = data['updates'];
    if (updates is Map<String, dynamic>) return updates;
    return null;
  }

  /// Suggested pedagogical follow-up question chips
  List<String>? get followups {
    if (type != StreamEventType.followups) return null;
    final items = data['suggestions'];
    if (items is List) {
      return items.map((e) => e.toString()).toList();
    }
    return null;
  }

  /// Error code (e.g. RATE_LIMIT_EXCEEDED, UPSTREAM_TIMEOUT)
  String? get errorCode {
    if (type != StreamEventType.error) return null;
    return data['code'] as String?;
  }

  /// User-safe sanitized error message
  String? get errorMessage {
    if (type != StreamEventType.error) return null;
    return data['message'] as String?;
  }

  /// Whether the client is encouraged to retry this request
  bool get isRetryable {
    if (type != StreamEventType.error) return false;
    return data['retryable'] as bool? ?? false;
  }

  /// Active session ID returned in meta event
  String? get sessionId {
    if (type != StreamEventType.meta) return null;
    return data['session_id'] as String?;
  }

  /// Active inference model name returned in meta event
  String? get model {
    if (type != StreamEventType.meta) return null;
    return data['model'] as String?;
  }

  @override
  String toString() =>
      'StreamEventEnvelope(v: $version, seq: $sequence, type: $type, data: $data)';
}

/// Service managing bidirectional communication and SSE streaming
/// with the Stemly AI Tutor backend.
class ChatStreamService {
  final http.Client _httpClient;
  final String _baseUrl;
  final TokenProvider? _tokenProvider;

  ChatStreamService({
    http.Client? httpClient,
    String? baseUrl,
    TokenProvider? tokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.baseUrl,
       _tokenProvider = tokenProvider;

  /// Helper to generate client-side idempotency keys.
  static String generateIdempotencyKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Establishes an SSE stream to POST /chat/stream.
  /// Yields parsed [StreamEventEnvelope] instances as they arrive in real-time.
  ///
  /// Cancelling the returned [StreamSubscription] aborts the HTTP connection
  /// immediately, which triggers the backend's disconnect handler and cancels upstream LLM billing.
  Stream<StreamEventEnvelope> streamChat({
    required String userPrompt,
    required String topic,
    List<String>? variables,
    Map<String, dynamic>? currentParams,
    List<Map<String, String>>? history,
    String? sessionId,
    String? idempotencyKey,
  }) async* {
    final cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.parse('$cleanBase/chat/stream');

    final key = idempotencyKey ?? generateIdempotencyKey();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-Accel-Buffering': 'no',
      'Idempotency-Key': key,
    };

    if (sessionId != null && sessionId.isNotEmpty) {
      headers['X-Session-ID'] = sessionId;
    }

    final tokenProvider = _tokenProvider;
    if (tokenProvider != null) {
      try {
        final token = await tokenProvider();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        debugPrint('ChatStreamService: Failed to retrieve Firebase token: $e');
      }
    }

    final bodyPayload = jsonEncode({
      'user_prompt': userPrompt,
      'topic': topic,
      'variables': variables ?? <String>[],
      if (currentParams != null) 'current_params': currentParams,
      'history': history ?? <Map<String, String>>[],
    });

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = bodyPayload;

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(request);
    } catch (e) {
      throw NetworkException(
        message: 'Connection failed when initiating chat stream: $e',
      );
    }

    if (streamedResponse.statusCode >= 400) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw ApiException.fromResponse(streamedResponse.statusCode, errorBody);
    }

    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lineStream) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignore SSE heartbeat ping comments (: ping)
      if (line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();

        // Handle end-of-stream delimiter
        if (payload == '[DONE]') {
          yield StreamEventEnvelope(
            version: 1,
            id: 'done_${DateTime.now().millisecondsSinceEpoch}',
            sequence: 999999,
            type: StreamEventType.done,
            data: const {'finish_reason': 'stop'},
          );
          break;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            yield StreamEventEnvelope.fromJson(decoded);
          }
        } catch (e) {
          debugPrint('ChatStreamService: Failed to decode SSE frame: $e');
        }
      }
    }
  }

  /// High-level ergonomic convenience wrapper that executes a chat stream
  /// and dispatches typed callbacks to simplify Flutter UI state management.
  Future<void> sendTutorMessage({
    required String userPrompt,
    required String topic,
    List<String>? variables,
    Map<String, dynamic>? currentParams,
    List<Map<String, String>>? history,
    String? sessionId,
    void Function(String sessionId, String model)? onMeta,
    void Function(String delta)? onToken,
    void Function(Map<String, dynamic> updates)? onParameters,
    void Function(List<String> suggestions)? onFollowups,
    void Function(String code, String message, bool retryable)? onError,
    void Function()? onDone,
  }) async {
    try {
      final stream = streamChat(
        userPrompt: userPrompt,
        topic: topic,
        variables: variables,
        currentParams: currentParams,
        history: history,
        sessionId: sessionId,
      );

      await for (final event in stream) {
        switch (event.type) {
          case StreamEventType.meta:
            if (onMeta != null && event.sessionId != null) {
              onMeta(event.sessionId!, event.model ?? 'unknown');
            }
            break;
          case StreamEventType.token:
            if (onToken != null && event.tokenDelta != null) {
              onToken(event.tokenDelta!);
            }
            break;
          case StreamEventType.parameters:
            if (onParameters != null && event.parameterUpdates != null) {
              onParameters(event.parameterUpdates!);
            }
            break;
          case StreamEventType.followups:
            if (onFollowups != null && event.followups != null) {
              onFollowups(event.followups!);
            }
            break;
          case StreamEventType.error:
            if (onError != null) {
              onError(
                event.errorCode ?? 'UNKNOWN_ERROR',
                event.errorMessage ?? 'An unexpected error occurred.',
                event.isRetryable,
              );
            }
            break;
          case StreamEventType.usage:
          case StreamEventType.unknown:
            break;
          case StreamEventType.done:
            if (onDone != null) onDone();
            break;
        }
      }
    } catch (e) {
      if (onError != null) {
        onError('STREAM_EXCEPTION', e.toString(), true);
      }
    }
  }
}
