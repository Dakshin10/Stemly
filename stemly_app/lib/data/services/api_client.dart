import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/api_exceptions.dart';

/// Function signature for acquiring the Firebase ID token.
typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Unified Production API Client for Stemly Backend.
/// - Injects Firebase bearer tokens with automatic 401 refresh & replay.
/// - Configurable request timeouts.
/// - Automatic retry with exponential backoff for idempotent requests.
/// - Standardized typed exception mapping.
class ApiClient {
  final http.Client _httpClient;
  final String _baseUrl;
  final TokenProvider? _tokenProvider;

  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    TokenProvider? tokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.baseUrl,
       _tokenProvider = tokenProvider;

  String get baseUrl => _baseUrl;

  /// Helper to build URI from path and optional query parameters.
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    String cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    String cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParameters == null || queryParameters.isEmpty) {
      return Uri.parse(fullUrl);
    }

    final uri = Uri.parse(fullUrl);
    final queryMap = <String, String>{};
    queryParameters.forEach((key, val) {
      if (val != null) {
        queryMap[key] = val.toString();
      }
    });
    return uri.replace(queryParameters: queryMap);
  }

  /// Resolves authentication headers.
  Future<Map<String, String>> _getHeaders({
    Map<String, String>? customHeaders,
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_tokenProvider != null) {
      try {
        final token = await _tokenProvider(forceRefresh: forceRefresh);
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        debugPrint("ApiClient: Token acquisition error: $e");
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Core HTTP execution pipeline with retry and token refresh.
  Future<dynamic> _executeRequest({
    required String method,
    required Uri uri,
    Map<String, String>? customHeaders,
    dynamic body,
    Duration? timeout,
    bool isIdempotent = false,
  }) async {
    final effectiveTimeout = timeout ?? AppConfig.requestTimeout;
    int maxAttempts = isIdempotent ? 3 : 1;
    int attempt = 0;
    bool hasRefreshedToken = false;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final headers = await _getHeaders(
          customHeaders: customHeaders,
          forceRefresh: hasRefreshedToken,
        );

        http.Response response;
        final encodedBody = (body != null && body is! String)
            ? jsonEncode(body)
            : body;

        switch (method.toUpperCase()) {
          case 'GET':
            response = await _httpClient
                .get(uri, headers: headers)
                .timeout(effectiveTimeout);
            break;
          case 'POST':
            response = await _httpClient
                .post(uri, headers: headers, body: encodedBody)
                .timeout(effectiveTimeout);
            break;
          case 'PUT':
            response = await _httpClient
                .put(uri, headers: headers, body: encodedBody)
                .timeout(effectiveTimeout);
            break;
          case 'DELETE':
            response = await _httpClient
                .delete(uri, headers: headers, body: encodedBody)
                .timeout(effectiveTimeout);
            break;
          default:
            throw ArgumentError("Unsupported HTTP method: $method");
        }

        // Handle 401 Unauthorized token expiry with 1 retry
        if (response.statusCode == 401 &&
            _tokenProvider != null &&
            !hasRefreshedToken) {
          debugPrint(
            "ApiClient: 401 Unauthorized on $uri. Attempting token refresh and replay...",
          );
          hasRefreshedToken = true;
          // Loop will retry with refreshed token
          continue;
        }

        // Retry on transient server errors (502, 503, 504) for idempotent requests
        if (isIdempotent &&
            attempt < maxAttempts &&
            (response.statusCode >= 502 && response.statusCode <= 504)) {
          final backoffMs = attempt * 500;
          debugPrint(
            "ApiClient: Server ${response.statusCode} on $uri. Retrying in ${backoffMs}ms (attempt $attempt)...",
          );
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }

        // Parse Response
        return _handleResponse(response);
      } on SocketException catch (e) {
        if (isIdempotent && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: attempt * 500));
          continue;
        }
        throw NetworkException(message: "SocketException: ${e.message}");
      } on TimeoutException catch (e) {
        if (isIdempotent && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: attempt * 500));
          continue;
        }
        throw NetworkException(
          message:
              "Request timed out after ${effectiveTimeout.inSeconds}s: ${e.message}",
        );
      } on http.ClientException catch (e) {
        if (isIdempotent && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: attempt * 500));
          continue;
        }
        throw NetworkException(message: "ClientException: ${e.message}");
      }
    }

    throw const NetworkException(
      message: "Request failed after all retry attempts.",
    );
  }

  /// Parses the response body or throws typed ApiException.
  dynamic _handleResponse(http.Response response) {
    final requestId = response.headers['x-request-id'];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      requestId: requestId,
    );
  }

  // ---------------------------------------------------------------------------
  // Public HTTP Methods
  // ---------------------------------------------------------------------------

  /// GET request (idempotent, retried on network failures).
  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) {
    final uri = _buildUri(path, queryParameters);
    return _executeRequest(
      method: 'GET',
      uri: uri,
      customHeaders: headers,
      timeout: timeout,
      isIdempotent: true,
    );
  }

  /// POST request.
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) {
    final uri = _buildUri(path, queryParameters);
    return _executeRequest(
      method: 'POST',
      uri: uri,
      customHeaders: headers,
      body: body,
      timeout: timeout,
      isIdempotent: false,
    );
  }

  /// PUT request (idempotent).
  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final uri = _buildUri(path);
    return _executeRequest(
      method: 'PUT',
      uri: uri,
      customHeaders: headers,
      body: body,
      timeout: timeout,
      isIdempotent: true,
    );
  }

  /// DELETE request.
  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final uri = _buildUri(path);
    return _executeRequest(
      method: 'DELETE',
      uri: uri,
      customHeaders: headers,
      body: body,
      timeout: timeout,
      isIdempotent: false,
    );
  }

  /// Multipart file upload (e.g. Scan Upload).
  Future<dynamic> uploadFile(
    String path, {
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    String? mediaType,
    Map<String, String>? fields,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? AppConfig.uploadTimeout;
    final uri = _buildUri(path);

    try {
      final authHeaders = await _getHeaders(customHeaders: headers);
      // Remove content-type so multipart boundary can be set automatically
      authHeaders.remove('Content-Type');

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(authHeaders);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      MediaType? parsedContentType;
      if (mediaType != null) {
        final parts = mediaType.split('/');
        if (parts.length == 2) {
          parsedContentType = MediaType(parts[0], parts[1]);
        }
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename,
          contentType: parsedContentType ?? MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(effectiveTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(message: "SocketException: ${e.message}");
    } on TimeoutException catch (e) {
      throw NetworkException(
        message:
            "Upload timed out after ${effectiveTimeout.inSeconds}s: ${e.message}",
      );
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}
