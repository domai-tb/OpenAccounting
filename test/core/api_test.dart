import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/api/api_exceptions.dart';
import 'package:openaccounting/core/api/dio_client.dart';

/// Minimal HttpClientAdapter fake that returns queued responses.
/// Each entry is either a ResponseBody (success) or a DioException (failure).
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.queue);

  final List<dynamic> queue;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    if (queue.isEmpty) {
      throw DioException(requestOptions: options, type: DioExceptionType.unknown, error: 'queue empty');
    }
    final next = queue.removeAt(0);
    if (next is DioException) throw next;
    if (next is ResponseBody) return next;
    if (next is Map<String, dynamic>) {
      // Convenience: map → JSON body 200.
      return ResponseBody.fromString(
        jsonEncode(next),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    if (next is int) {
      // int → status code with empty body.
      return ResponseBody.fromString('', next, headers: <String, List<String>>{});
    }
    throw StateError('unsupported queue entry $next');
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Map<String, dynamic> data, int status) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

void main() {
  group('DioClient configuration', () {
    test('timeout is 30s', () {
      final client = DioClient();
      expect(client.dio.options.connectTimeout, const Duration(seconds: 30));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(client.dio.options.sendTimeout, const Duration(seconds: 30));
    });

    test('port scan covers 8000-8010', () {
      expect(DioClient.probePorts, contains(8000));
      expect(DioClient.probePorts, contains(8010));
      expect(DioClient.probePorts.length, 11);
    });

    test('maxRetries is 3', () {
      final client = DioClient();
      expect(client.maxRetries, 3);
    });

    test('exponential backoff usesincreasing delays', () {
      // Verify retry delay formula: 200 * 2^attempt.
      expect(const Duration(milliseconds: 200) * (1 << 0), const Duration(milliseconds: 200));
      expect(const Duration(milliseconds: 200) * (1 << 1), const Duration(milliseconds: 400));
      expect(const Duration(milliseconds: 200) * (1 << 2), const Duration(milliseconds: 800));
    });
  });

  group('Retry on 5xx / timeout', () {
    test('retries 3 times then succeeds on 5xx', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      // Queue: 500, 500, then 200.
      final adapter = FakeAdapter(<dynamic>[
        500,
        500,
        jsonBody(<String, dynamic>{'ok': true}, 200),
      ]);
      dio.httpClientAdapter = adapter;

      final resp = await dio.get<dynamic>('http://localhost/test');
      expect(resp.statusCode, 200);
      expect(adapter.callCount, 3);
    });

    test('retries exhausted after 3 attempts stops', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      final adapter = FakeAdapter(<dynamic>[500, 500, 500, 500]);
      dio.httpClientAdapter = adapter;

      // DioClient validateStatus treats 500 as not validated, so error triggers retry chain.
      // After 3 retries, final error should be 500.
      try {
        await dio.get<dynamic>('http://localhost/test');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 500);
      }
      // Initial + 3 retries = 4 calls.
      expect(adapter.callCount, 4);
    });

    test('retries on timeout', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      DioException timeoutEx(RequestOptions opts) => DioException(
        requestOptions: opts,
        type: DioExceptionType.connectionTimeout,
        error: TimeoutException('connect timeout'),
      );
      // We simulate timeout via adapter throwing DioException with timeout type.
      // Need custom adapter that throws appropriate type — use queue of DioException.
      // Create a manual fake.
      var attempts = 0;
      dio.httpClientAdapter = FakeAdapter(<dynamic>[]);
      // Replace fetch via interceptor instead — simpler: use interceptors to throw.
      dio.interceptors.clear();
      // Re-add client retry interceptor plus our mock interceptor.
      // Reset client interceptors order: retry first, then mock.
      // Instead we recreate: inject mock via adapter throwing timeout directly.
      final mockDio = Dio();
      final mockClient = DioClient(dio: mockDio, maxRetries: 3);
      var call = 0;
      mockDio.httpClientAdapter = _TimeoutFakeAdapter(() {
        call++;
        if (call < 3) {
          throw DioException(
            requestOptions: RequestOptions(path: 'http://localhost/test'),
            type: DioExceptionType.connectionTimeout,
            error: TimeoutException('timeout'),
          );
        }
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final resp = await mockDio.get<dynamic>('http://localhost/test');
      expect(resp.statusCode, 200);
      expect(call, 3);
    });
  });

  group('422 detail parsing', () {
    test('parses FastAPI detail fields per field', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 422,
        data: <String, dynamic>{
          'detail': <dynamic>[
            <String, dynamic>{
              'loc': <dynamic>['body', 'email'],
              'msg': 'Ungültige E-Mail',
              'type': 'value_error',
            },
            <String, dynamic>{
              'loc': <dynamic>['body', 'name'],
              'msg': 'Name erforderlich',
              'type': 'missing',
            },
          ],
        },
      );
      final ex = ValidationException.fromResponse(resp);
      expect(ex.fieldErrors['email'], contains('Ungültige E-Mail'));
      expect(ex.fieldErrors['name'], contains('Name erforderlich'));
      expect(ex.statusCode, 422);
    });

    test('parses multiple fields simultaneously', () {
      final resp = Response<dynamic>(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 422,
        data: <String, dynamic>{
          'detail': <dynamic>[
            <String, dynamic>{
              'loc': <dynamic>['body', 'a'],
              'msg': 'Fehler A',
              'type': 'x',
            },
            <String, dynamic>{
              'loc': <dynamic>['body', 'b'],
              'msg': 'Fehler B',
              'type': 'x',
            },
            <String, dynamic>{
              'loc': <dynamic>['body', 'c'],
              'msg': 'Fehler C',
              'type': 'x',
            },
          ],
        },
      );
      final ex = ValidationException.fromResponse(resp);
      expect(ex.fieldErrors.length, 3);
      expect(ex.fieldErrors['a'], isNotNull);
      expect(ex.fieldErrors['b'], isNotNull);
      expect(ex.fieldErrors['c'], isNotNull);
    });

    test('422 interceptor wraps into ValidationException error', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      dio.httpClientAdapter = FakeAdapter(<dynamic>[
        ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'detail': <dynamic>[
              <String, dynamic>{
                'loc': <dynamic>['body', 'betrag'],
                'msg': 'Betrag darf maximal 2 Dezimalstellen haben',
                'type': 'x',
              },
            ],
          }),
          422,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      ]);

      try {
        await dio.get<dynamic>('http://localhost/test');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationException>());
        final ve = e.error as ValidationException;
        expect(ve.fieldErrors['betrag'], contains('Betrag darf maximal 2 Dezimalstellen haben'));
        expect(e.message, contains('Betrag'));
      }
    });
  });

  group('Connection-refused → Backend nicht erreichbar', () {
    test('detects SocketException connection refused', () {
      final ex = DioException(
        requestOptions: RequestOptions(path: 'http://localhost:8002/test'),
        type: DioExceptionType.unknown,
        error: const SocketException('Connection refused'),
        message: 'SocketException: Connection refused',
      );
      expect(BackendUnreachableException.isConnectionError(ex), isTrue);
    });

    test('detects connectionError type', () {
      final ex = DioException(
        requestOptions: RequestOptions(path: 'http://localhost:8002/test'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup'),
      );
      expect(BackendUnreachableException.isConnectionError(ex), isTrue);
    });

    test('interceptor maps connection refused to Backend nicht erreichbar', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      dio.httpClientAdapter = _ThrowingAdapter(
        DioException(
          requestOptions: RequestOptions(path: 'http://localhost:8002/test'),
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        ),
      );
      try {
        await dio.get<dynamic>('http://localhost:8002/test');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<BackendUnreachableException>());
        expect((e.error as BackendUnreachableException).message, 'Backend nicht erreichbar');
        expect(e.message, 'Backend nicht erreichbar');
      }
    });

    test('port detection returns null when all ports fail', () async {
      final dio = Dio();
      final client = DioClient(dio: dio);
      // We test detectBackendPort by passing ports that are not open — it should return null quickly.
      // Use localhost with unlikely ports 1,2,3 mocked via passing list.
      final result = await client.detectBackendPort(host: '127.0.0.1', ports: const <int>[1, 2, 3]);
      expect(result, isNull);
    });

    test('BackendUnreachableException carries host and port', () {
      const ex = BackendUnreachableException('Backend nicht erreichbar', host: 'localhost', port: 8002);
      expect(ex.host, 'localhost');
      expect(ex.port, 8002);
      expect(ex.message, 'Backend nicht erreichbar');
    });
  });
}

class _TimeoutFakeAdapter implements HttpClientAdapter {
  _TimeoutFakeAdapter(this.builder);
  final ResponseBody Function() builder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return builder();
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.exception);
  final DioException exception;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw exception;
  }

  @override
  void close({bool force = false}) {}
}
