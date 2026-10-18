import 'dart:async';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'fake_tududi.dart';

/// Routes Dio requests into a [FakeTududi] handler without any network.
class FakeTududiAdapter implements HttpClientAdapter {
  FakeTududiAdapter(this.server);
  final FakeTududi server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }

    final headers = <String, String>{
      for (final e in options.headers.entries)
        e.key.toLowerCase(): e.value.toString(),
    };
    final req = shelf.Request(
      options.method,
      options.uri,
      headers: headers,
      body: bytes,
    );

    final shelf.Response res;
    try {
      res = await server.handler(req);
    } on FakeConnectionError {
      if (options.connectTimeout != null) {
        throw DioException.connectionTimeout(
          timeout: options.connectTimeout!,
          requestOptions: options,
        );
      }
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'FakeTududi is offline',
      );
    }

    final out = await res.read().expand((c) => c).toList();
    return ResponseBody.fromBytes(
      Uint8List.fromList(out),
      res.statusCode,
      headers: {
        for (final e in res.headersAll.entries) e.key.toLowerCase(): e.value,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio wired to [server], with an in-memory cookie jar (like the app).
Dio makeDio(
  FakeTududi server, {
  String baseUrl = 'http://fake.tududi.test/api',
  CookieJar? jar,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = FakeTududiAdapter(server);
  dio.interceptors.add(CookieManager(jar ?? CookieJar()));
  return dio;
}
