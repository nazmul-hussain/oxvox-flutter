import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';

/// An error message from the server (or a local network message) to show to the user.
class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, this.status);
  @override
  String toString() => message;
}

/// Client for the same Netlify function the web app uses (/api/*, MongoDB Atlas behind it).
/// The server keeps the session in an HttpOnly cookie; a native app has no cookie jar, so the
/// cookie value is stored here and sent back on each request.
class OxApi {
  OxApi(this._prefs);

  final SharedPreferences _prefs;
  static const _cookieName = 'oxvox_session';
  static const _cookieKey = 'apiSessionCookie';

  bool get hasSession => (_prefs.getString(_cookieKey) ?? '').isNotEmpty;

  /// Sends a request and returns the decoded JSON body. Throws [ApiException] on errors.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final req = http.Request(method, Uri.parse('${AppConfig.apiBase}$path'));
    req.headers['Accept'] = 'application/json';
    final cookie = _prefs.getString(_cookieKey);
    if (cookie != null && cookie.isNotEmpty) {
      req.headers['Cookie'] = '$_cookieName=$cookie';
    }
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    late http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException(
        'Could not reach the server. Check your internet connection.',
        0,
      );
    }
    _captureCookie(res.headers['set-cookie']);
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      // Not JSON: the server or the function is not reachable as expected.
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        (data['error'] as String?) ?? 'Request failed (${res.statusCode}).',
        res.statusCode,
      );
    }
    return data;
  }

  void _captureCookie(String? header) {
    if (header == null) return;
    final m = RegExp('$_cookieName=([^;]*)').firstMatch(header);
    if (m == null) return;
    final value = m.group(1) ?? '';
    if (value.isEmpty) {
      _prefs.remove(_cookieKey);
    } else {
      _prefs.setString(_cookieKey, value);
    }
  }

  Future<void> clearSession() => _prefs.remove(_cookieKey);
}
