import 'dart:convert';

/// Base class for all Stemly API exceptions.
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String friendlyMessage;
  final String? requestId;

  const ApiException({
    required this.message,
    this.statusCode,
    required this.friendlyMessage,
    this.requestId,
  });

  @override
  String toString() =>
      '$runtimeType: $message (status: $statusCode, req: $requestId)';

  /// Factory to parse an HTTP response into a typed exception
  factory ApiException.fromResponse(
    int statusCode,
    String body, {
    String? requestId,
  }) {
    String detail = "Unknown error occurred.";
    String? serverRequestId = requestId;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey("error") && decoded["error"] is Map) {
          final err = decoded["error"] as Map;
          detail = err["message"]?.toString() ?? detail;
          serverRequestId ??= err["request_id"]?.toString();
        } else if (decoded.containsKey("detail")) {
          final d = decoded["detail"];
          if (d is String) {
            detail = d;
          } else if (d is List && d.isNotEmpty) {
            detail = d
                .map((e) => e is Map ? e["msg"] : e.toString())
                .join(", ");
          }
        } else if (decoded.containsKey("message")) {
          detail = decoded["message"].toString();
        }
      }
    } catch (_) {
      detail = body.isNotEmpty ? body : "HTTP $statusCode";
    }

    switch (statusCode) {
      case 401:
        return UnauthorizedException(
          message: detail,
          statusCode: 401,
          requestId: serverRequestId,
        );
      case 403:
        return ForbiddenException(
          message: detail,
          statusCode: 403,
          requestId: serverRequestId,
        );
      case 404:
        return NotFoundException(
          message: detail,
          statusCode: 404,
          requestId: serverRequestId,
        );
      case 413:
        return ValidationException(
          message: detail,
          statusCode: 413,
          friendlyMessage:
              "Image is too large (max 5 MB). Please choose a smaller image.",
          requestId: serverRequestId,
        );
      case 429:
        if (detail.toLowerCase().contains("quota") ||
            detail.toLowerCase().contains("daily")) {
          return QuotaExceededException(
            message: detail,
            statusCode: 429,
            requestId: serverRequestId,
          );
        }
        return RateLimitException(
          message: detail,
          statusCode: 429,
          requestId: serverRequestId,
        );
      case 400:
      case 422:
        return ValidationException(
          message: detail,
          statusCode: statusCode,
          friendlyMessage: detail,
          requestId: serverRequestId,
        );
      default:
        if (statusCode >= 500) {
          return ServerException(
            message: detail,
            statusCode: statusCode,
            requestId: serverRequestId,
          );
        }
        return GenericApiException(
          message: detail,
          statusCode: statusCode,
          friendlyMessage: detail,
          requestId: serverRequestId,
        );
    }
  }
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = "Unauthorized access",
    super.statusCode = 401,
    super.requestId,
  }) : super(
         friendlyMessage: "Your session has expired. Please sign in again.",
       );
}

class ForbiddenException extends ApiException {
  const ForbiddenException({
    super.message = "Forbidden",
    super.statusCode = 403,
    super.requestId,
  }) : super(
         friendlyMessage: "You do not have permission to access this resource.",
       );
}

class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = "Not found",
    super.statusCode = 404,
    super.requestId,
  }) : super(friendlyMessage: "The requested resource was not found.");
}

class RateLimitException extends ApiException {
  const RateLimitException({
    super.message = "Rate limit exceeded",
    super.statusCode = 429,
    super.requestId,
  }) : super(
         friendlyMessage:
             "Too many requests. Please wait a moment and try again.",
       );
}

class QuotaExceededException extends ApiException {
  const QuotaExceededException({
    super.message = "Daily quota exceeded",
    super.statusCode = 429,
    super.requestId,
  }) : super(
         friendlyMessage:
             "Daily AI generation limit reached (50 requests/day). Quota resets at 00:00 UTC.",
       );
}

class ServerException extends ApiException {
  const ServerException({
    super.message = "Server error",
    super.statusCode = 500,
    super.requestId,
  }) : super(
         friendlyMessage:
             "STEMLY AI service is temporarily unavailable. Please try again shortly.",
       );
}

class NetworkException extends ApiException {
  const NetworkException({
    super.message = "Network connection failed",
    super.statusCode,
    super.requestId,
  }) : super(
         friendlyMessage:
             "Unable to reach the server. Please check your internet connection.",
       );
}

class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    super.statusCode = 422,
    required super.friendlyMessage,
    super.requestId,
  });
}

class GenericApiException extends ApiException {
  const GenericApiException({
    required super.message,
    super.statusCode,
    required super.friendlyMessage,
    super.requestId,
  });
}
