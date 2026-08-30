import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:openaccounting/core/api/api_exceptions.dart';

/// Dio client with retry, timeout 30s, 422 parsing, connection-refused handling,
/// and port detection 8000-8010 per DESIGN §46 and specs/app API Client.
///
/// ponytail: single Dio instance + interceptors — no wrapper class explosion.
/// ponytail: port scan loop is naive linear scan — good enough for 11 ports,
/// upgrade to parallel probe if startup latency matters.
class DioClient {
  DioClient({Dio? dio, this.maxRetries = 3, this.baseHost = 'localhost'}) : dio = dio ?? Dio() {
    _configure();
  }

  final Dio dio;
  final int maxRetries;
  final String baseHost;

  static const Duration timeout = Duration(seconds: 30);
  static const List<int> probePorts = <int>[8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8009, 8010];

  void _configure() {
    dio.options = BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      validateStatus: (status) => status != null && status < 400, // 422 and 5xx trigger error pipeline.
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          // 422 → parse detail fields.
          if (err.response?.statusCode == 422) {
            final ex = ValidationException.fromResponse(err.response!);
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                response: err.response,
                type: err.type,
                error: ex,
                message: ex.message,
              ),
            );
          }

          // Connection refused → user-friendly.
          if (BackendUnreachableException.isConnectionError(err)) {
            final host = err.requestOptions.uri.host;
            final port = err.requestOptions.uri.port;
            final ex = BackendUnreachableException(
              'Backend nicht erreichbar',
              host: host,
              port: port == 0 ? null : port,
              cause: err.error,
            );
            return handler.reject(
              DioException(requestOptions: err.requestOptions, type: err.type, error: ex, message: ex.message),
            );
          }

          // Retry for 5xx or transient timeouts.
          final retries = (err.requestOptions.extra['retries'] as int?) ?? 0;
          final shouldRetry = _shouldRetry(err);
          if (shouldRetry && retries < maxRetries) {
            final backoff = Duration(milliseconds: 200 * (1 << retries));
            if (kDebugMode) {
              debugPrint('DioClient retry ${retries + 1}/$maxRetries after $backoff for ${err.requestOptions.uri}');
            }
            await Future<void>.delayed(backoff);
            final opts = err.requestOptions..extra['retries'] = retries + 1;
            try {
              final resp = await dio.fetch<dynamic>(opts);
              return handler.resolve(resp);
            } catch (e) {
              if (e is DioException) return handler.reject(e);
              return handler.reject(DioException(requestOptions: opts, error: e, type: DioExceptionType.unknown));
            }
          }

          // Exhausted → if was 5xx, wrap as BackendUnreachable for UI.
          if (err.response != null && (err.response!.statusCode ?? 0) >= 500) {
            // Keep original but UI can detect 5xx after retries.
          }

          return handler.next(err);
        },
      ),
    );
  }

  bool _shouldRetry(DioException err) {
    final code = err.response?.statusCode;
    if (code != null && code >= 500 && code < 600) return true;
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }
    if (err.type == DioExceptionType.unknown && err.error is SocketException) return true;
    if (BackendUnreachableException.isConnectionError(err)) return true;
    return false;
  }

  /// Probe ports 8000-8010 on [host] and return first responding base URI.
  /// Returns null if none respond — caller should show Backend nicht erreichbar.
  Future<Uri?> detectBackendPort({String? host, List<int>? ports}) async {
    final h = host ?? baseHost;
    final list = ports ?? probePorts;
    for (final port in list) {
      final uri = Uri.parse('http://$h:$port/health');
      try {
        final probe = Dio(
          BaseOptions(
            connectTimeout: const Duration(milliseconds: 500),
            receiveTimeout: const Duration(milliseconds: 500),
            sendTimeout: const Duration(milliseconds: 500),
          ),
        );
        final resp = await probe.getUri<dynamic>(uri);
        if (resp.statusCode != null && resp.statusCode! < 500) {
          dio.options.baseUrl = 'http://$h:$port';
          return Uri.parse('http://$h:$port');
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Simple health poll every 30s when backend unreachable — caller drives timer.
  static const Duration healthPollInterval = Duration(seconds: 30);

  Future<bool> checkHealth({String? baseUrl}) async {
    final url = baseUrl ?? dio.options.baseUrl;
    if (url.isEmpty) return false;
    try {
      final resp = await dio.get<dynamic>('$url/health');
      return (resp.statusCode ?? 500) < 500;
    } catch (_) {
      return false;
    }
  }
}
