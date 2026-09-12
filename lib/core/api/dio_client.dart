import 'dart:async';
import 'dart:io';
import 'dart:math';

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
  DioClient({Dio? dio, this.maxRetries = 3, this.baseHost = 'localhost', Set<String>? trustedHosts})
    : trustedHosts = Set<String>.unmodifiable(
        (trustedHosts ?? const <String>{'localhost', '127.0.0.1', '::1'}).map((host) => host.trim().toLowerCase()),
      ),
      dio = dio ?? Dio() {
    _configure();
  }

  final Dio dio;
  final int maxRetries;
  final String baseHost;
  final Set<String> trustedHosts;

  static const Duration timeout = Duration(seconds: 30);
  static const List<int> probePorts = <int>[8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8009, 8010];

  void _configure() {
    dio.options = BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      followRedirects: false,
      maxRedirects: 0,
      validateStatus: (status) => status != null && status < 400, // 422 and 5xx trigger error pipeline.
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (!_isTrustedUri(options.uri)) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: StateError('API-Endpunkt ist nicht freigegeben'),
                message: 'API-Endpunkt ist nicht freigegeben',
              ),
            );
          }
          handler.next(options);
        },
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

          // Retry first — connection errors respect retry count.
          final retries = (err.requestOptions.extra['retries'] as int?) ?? 0;
          final shouldRetry = _canRetry(err.requestOptions) && _shouldRetry(err);
          if (shouldRetry && retries < maxRetries) {
            final backoff = Duration(milliseconds: 200 * (1 << retries) + Random().nextInt(100));
            if (kDebugMode) {
              debugPrint(
                'DioClient retry ${retries + 1}/$maxRetries after $backoff for ${_redactedUri(err.requestOptions.uri)}',
              );
            }
            await Future<void>.delayed(backoff);
            final opts = err.requestOptions..extra['retries'] = retries + 1;
            try {
              final resp = await dio.fetch<dynamic>(opts);
              return handler.resolve(resp);
            } catch (e) {
              if (e is DioException) return handler.reject(e);
              return handler.reject(DioException(requestOptions: opts, error: e));
            }
          }

          // Connection refused → only after retries exhausted (retry block above respects count).
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
    if (err.type == DioExceptionType.unknown && err.error is SocketException) {
      return true;
    }
    if (BackendUnreachableException.isConnectionError(err)) return true;
    return false;
  }

  bool _canRetry(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') return true;
    final key = options.headers['Idempotency-Key'] ?? options.headers['idempotency-key'];
    return key is String && key.trim().isNotEmpty;
  }

  /// Probe ports 8000-8010 on [host] and return first responding base URI.
  /// Returns null if none respond — caller should show Backend nicht erreichbar.
  Future<Uri?> detectBackendPort({String? host, List<int>? ports}) async {
    final h = host ?? baseHost;
    if (!_isLoopbackHost(h)) {
      throw ArgumentError.value(h, 'host', 'Backend discovery is restricted to the local machine');
    }
    final list = ports ?? probePorts;
    if (list.any((port) => port < 1 || port > 65535)) {
      throw ArgumentError.value(list, 'ports', 'Ports must be between 1 and 65535');
    }
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 500),
        receiveTimeout: const Duration(milliseconds: 500),
        sendTimeout: const Duration(milliseconds: 500),
        followRedirects: false,
        maxRedirects: 0,
      ),
    );
    try {
      for (final port in list) {
        final uri = Uri.parse('http://${_hostForUri(h)}:$port/health');
        try {
          final resp = await probe.getUri<dynamic>(uri);
          if (resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300) {
            dio.options.baseUrl = 'http://${_hostForUri(h)}:$port';
            return Uri.parse('http://${_hostForUri(h)}:$port');
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } finally {
      probe.close();
    }
  }

  /// Simple health poll every 30s when backend unreachable — caller drives timer.
  static const Duration healthPollInterval = Duration(seconds: 30);

  Future<bool> checkHealth({String? baseUrl}) async {
    final url = baseUrl ?? dio.options.baseUrl;
    if (url.isEmpty) return false;
    try {
      final Uri? parsed = Uri.tryParse(url);
      if (parsed == null || !_isTrustedUri(parsed)) {
        return false;
      }
      final resp = await dio.get<dynamic>('$url/health');
      final status = resp.statusCode ?? 0;
      return status >= 200 && status < 300;
    } catch (_) {
      return false;
    }
  }

  static bool _isLoopbackHost(String host) {
    final String normalized = host.trim().toLowerCase();
    if (normalized == 'localhost') return true;
    final InternetAddress? address = InternetAddress.tryParse(normalized);
    return address != null && address.isLoopback;
  }

  /// ponytail: DNS/private-range guard — only loopback hosts are trusted for http;
  /// private ranges (10/8, 192.168/16, 172.16/12, fc00::/7) are not in trustedHosts
  /// by default → blocked. Even if added to trustedHosts, private IP literals
  /// are denied (DNS rebinding guard deferred — hostnames require DNS check).
  /// No production caller uses DioClient with external hosts — loopback only.
  bool _isTrustedUri(Uri uri) {
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return false;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.port < 0 || uri.port > 65535) return false;
    final host = uri.host.trim().toLowerCase();
    if (_isPrivateNetworkHost(host)) return false;
    if (!trustedHosts.contains(host)) return false;
    return _isLoopbackHost(host) || uri.scheme == 'https';
  }

  static bool _isPrivateNetworkHost(String host) {
    final address = InternetAddress.tryParse(host);
    if (address == null) return false; // hostname — DNS check deferred
    if (address.isLoopback) return false; // loopback allowed via _isLoopbackHost
    final raw = address.rawAddress;
    if (raw.length == 4) {
      // 10/8
      if (raw[0] == 10) return true;
      // 172.16/12
      if (raw[0] == 172 && raw[1] >= 16 && raw[1] <= 31) return true;
      // 192.168/16
      if (raw[0] == 192 && raw[1] == 168) return true;
      // 169.254/16 link-local
      if (raw[0] == 169 && raw[1] == 254) return true;
    }
    if (raw.length == 16) {
      // fc00::/7 unique local, fe80::/10 link-local
      if ((raw[0] & 0xfe) == 0xfc) return true;
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true;
    }
    return false;
  }

  Uri _redactedUri(Uri uri) => uri.replace(userInfo: '', query: '', fragment: '');

  static String _hostForUri(String host) => host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
}
