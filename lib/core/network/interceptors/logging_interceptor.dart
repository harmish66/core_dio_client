import 'dart:convert';
import 'package:dio/dio.dart';

/// LoggingInterceptor prints structured, human-friendly API request/response
/// logs using print() for better visibility in the debug console.
class LoggingInterceptor extends Interceptor {
  final bool enabled;
  final int maxBodyChars;
  final bool redactHeaders;
  final Set<String> sensitiveHeaders;
  final void Function(String line)? logPrint;
  static int _nextId = 1;

  LoggingInterceptor({
    this.enabled = true,
    this.maxBodyChars = 10240, // 10 KB
    this.redactHeaders = true,
    Set<String>? sensitiveHeaders,
    this.logPrint,
  }) : sensitiveHeaders = (sensitiveHeaders ?? const {'authorization', 'cookie', 'set-cookie'});

  String _prettyJson(dynamic value) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      if (value == null) {
        return 'null';
      }
      if (value is String) {
        try {
          final decoded = json.decode(value);
          return encoder.convert(decoded);
        } catch (_) {
          return value;
        }
      }
      return encoder.convert(value);
    } catch (e) {
      return value.toString();
    }
  }

  String _shorten(String s) {
    if (s.length <= maxBodyChars) return s;
    return '${s.substring(0, maxBodyChars)}\n... (truncated, ${s.length} chars)';
  }

  Map<String, dynamic> _normalizeHeaders(Map<String, dynamic>? headers) {
    final map = <String, dynamic>{};
    if (headers == null) return map;
    headers.forEach((k, v) {
      map[k.toString()] = v is Iterable ? v.toList() : v;
    });
    return map;
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    if (!redactHeaders) return headers;
    final out = <String, dynamic>{};
    headers.forEach((k, v) {
      if (sensitiveHeaders.contains(k.toLowerCase())) {
        out[k] = '<REDACTED>';
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  void _printLog(String text) {
    for (var line in text.split('\n')) {
      if (logPrint != null) {
        logPrint!(line);
      } else {
        // ignore: avoid_print
        print(line);
      }
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!enabled) {
      handler.next(options);
      return;
    }

    final id = _nextId++;
    options.extra['_logId'] = id;
    options.extra['_startTime'] = DateTime.now().millisecondsSinceEpoch;

    final method = options.method.toUpperCase();
    final url = options.uri.toString();
    final headers = _redactHeaders(_normalizeHeaders(options.headers.cast<String, dynamic>()));
    final body = options.data;

    final buffer = StringBuffer();
    buffer.writeln('==================== API REQUEST ====================');
    buffer.writeln('ID     : $id');
    buffer.writeln('METHOD : $method');
    buffer.writeln('URL    : $url');
    buffer.writeln('');
    buffer.writeln('HEADERS:');
    buffer.writeln(_shorten(_prettyJson(headers)));
    buffer.writeln('');
    buffer.writeln('BODY:');
    if (body == null) {
      buffer.writeln('null');
    } else {
      if (body is FormData) {
        final fm = <String, dynamic>{};
        for (final entry in body.fields) {
          fm[entry.key] = entry.value;
        }
        final files = <String, String>{};
        for (final f in body.files) {
          files[f.key] = f.value.filename ?? f.value.contentType?.toString() ?? 'file';
        }
        buffer.writeln(_shorten(_prettyJson({'fields': fm, 'files': files})));
      } else {
        buffer.writeln(_shorten(_prettyJson(body)));
      }
    }
    buffer.writeln('');
    buffer.writeln('====================================================');

    _printLog(buffer.toString());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!enabled) {
      handler.next(response);
      return;
    }

    final options = response.requestOptions;
    final id = options.extra['_logId'] ?? (_nextId++);
    final startMs = options.extra['_startTime'] as int?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = startMs != null ? (nowMs - startMs) : null;

    final method = options.method.toUpperCase();
    final url = options.uri.toString();
    final status = response.statusCode;
    final headers = _redactHeaders(_normalizeHeaders(response.headers.map));
    final body = response.data;

    final buffer = StringBuffer();
    buffer.writeln('==================== API RESPONSE ====================');
    buffer.writeln('ID     : $id');
    buffer.writeln('METHOD : $method');
    buffer.writeln('URL    : $url');
    buffer.writeln('STATUS : ${status ?? 'unknown'}');
    buffer.writeln('TIME   : ${elapsed != null ? '${elapsed}ms' : 'unknown'}');
    buffer.writeln('');
    buffer.writeln('HEADERS:');
    buffer.writeln(_shorten(_prettyJson(headers)));
    buffer.writeln('');
    buffer.writeln('BODY:');
    buffer.writeln(_shorten(_prettyJson(body)));
    buffer.writeln('');
    buffer.writeln('====================================================');

    _printLog(buffer.toString());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!enabled) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final id = options.extra['_logId'] ?? (_nextId++);
    final startMs = options.extra['_startTime'] as int?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = startMs != null ? (nowMs - startMs) : null;

    final method = options.method.toUpperCase();
    final url = options.uri.toString();
    final status = err.response?.statusCode;
    final headers = _redactHeaders(_normalizeHeaders(err.response?.headers.map));
    final body = err.response?.data;
    final message = err.message;

    final buffer = StringBuffer();
    buffer.writeln('==================== API ERROR ======================');
    buffer.writeln('ID     : $id');
    buffer.writeln('METHOD : $method');
    buffer.writeln('URL    : $url');
    buffer.writeln('STATUS : ${status ?? 'unknown'}');
    buffer.writeln('TIME   : ${elapsed != null ? '${elapsed}ms' : 'unknown'}');
    buffer.writeln('');
    buffer.writeln('ERROR:');
    buffer.writeln(message);
    buffer.writeln('');
    buffer.writeln('HEADERS:');
    buffer.writeln(_shorten(_prettyJson(headers)));
    buffer.writeln('');
    buffer.writeln('BODY:');
    buffer.writeln(_shorten(_prettyJson(body)));
    buffer.writeln('');
    buffer.writeln('====================================================');

    _printLog(buffer.toString());
    handler.next(err);
  }
}
