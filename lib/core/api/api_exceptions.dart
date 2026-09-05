import 'package:dio/dio.dart';

/// Base API exception with user-friendly message per DESIGN §46.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.host, this.port});

  final String message;
  final int? statusCode;
  final String? host;
  final int? port;

  @override
  String toString() => message;
}

/// 422 validation: field → list of messages.
class ValidationException extends ApiException {
  const ValidationException(super.message, {required this.fieldErrors, super.statusCode = 422});

  final Map<String, List<String>> fieldErrors;

  /// Parse FastAPI-style or generic 422 body into fieldErrors.
  factory ValidationException.fromResponse(Response<dynamic> response) {
    final data = response.data;
    final Map<String, List<String>> fields = <String, List<String>>{};

    if (data is Map<String, dynamic>) {
      if (data['detail'] is List) {
        for (final item in data['detail'] as List) {
          if (item is Map) {
            final loc = item['loc'];
            final msg = item['msg']?.toString() ?? 'Ungültiger Wert';
            String field = 'allgemein';
            if (loc is List && loc.isNotEmpty) {
              // FastAPI loc like ["body", "email"] → last segment is field.
              field = loc.last.toString();
            } else if (item['field'] != null) {
              field = item['field'].toString();
            }
            fields.putIfAbsent(field, () => <String>[]).add(msg);
          }
        }
      } else if (data['detail'] is String) {
        fields['allgemein'] = <String>[data['detail'] as String];
      } else if (data['detail'] is Map) {
        (data['detail'] as Map).forEach((k, v) {
          final key = k.toString();
          if (v is List) {
            fields[key] = v.map((e) => e.toString()).toList();
          } else {
            fields[key] = <String>[v.toString()];
          }
        });
      } else if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((k, v) {
          final key = k.toString();
          if (v is List) {
            fields[key] = v.map((e) => e.toString()).toList();
          } else {
            fields[key] = <String>[v.toString()];
          }
        });
      } else {
        // Generic field map at top level: { "email": ["..."], "name": "..." }
        var hasField = false;
        data.forEach((k, v) {
          if (k == 'message' || k == 'error' || k == 'statusCode') return;
          hasField = true;
          if (v is List) {
            fields[k.toString()] = v.map((e) => e.toString()).toList();
          } else {
            fields[k.toString()] = <String>[v.toString()];
          }
        });
        if (!hasField) {
          fields['allgemein'] = <String>[data['message']?.toString() ?? 'Validierung fehlgeschlagen'];
        }
      }
    } else if (data is List) {
      fields['allgemein'] = data.map((e) => e.toString()).toList();
    } else {
      fields['allgemein'] = <String>['Validierung fehlgeschlagen'];
    }

    final msg = fields.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('; ');
    return ValidationException(msg, fieldErrors: fields);
  }
}

/// Backend unreachable — connection refused / timeout after retries.
/// Message per spec: "Backend nicht erreichbar" with retry affordance.
class BackendUnreachableException extends ApiException {
  const BackendUnreachableException(super.message, {super.host, super.port, this.cause});

  final Object? cause;

  static bool isConnectionError(DioException e) {
    if (e.type == DioExceptionType.connectionError) return true;
    if (e.type == DioExceptionType.unknown) {
      final msg = '${e.error ?? ''} ${e.message ?? ''}'.toLowerCase();
      if (msg.contains('connection refused') ||
          msg.contains('connection reset') ||
          msg.contains('failed host lookup') ||
          msg.contains('network is unreachable') ||
          msg.contains('socketexception')) {
        return true;
      }
    }
    return false;
  }
}
