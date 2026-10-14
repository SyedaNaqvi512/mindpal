import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException extends AuthException {
  SessionExpiredException()
      : super('Your session has expired. Please sign in again.');
}

Map<String, dynamic> decodeJson(String body) {
  try {
    final value = jsonDecode(body);
    return value is Map<String, dynamic> ? value : {};
  } catch (_) {
    return {};
  }
}

/// Turns the server's error format (RFC 9457) into one readable sentence.
String problemMessage(Map<String, dynamic> d) {
  final errors = d['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) return first.first.toString();
  }
  final t = d['title'];
  final de = d['detail'];
  final title = t is String ? t : null;
  final detail = de is String ? de : null;
  if (title != null && detail != null) return '$title. $detail';
  return title ?? detail ?? 'Something went wrong. Please try again.';
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5141',
  );
  static const _json = {'Content-Type': 'application/json'};
  static const _kAccess = 'mindpal_access_token';
  static const _kRefresh = 'mindpal_refresh_token';

  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  final http.Client _client = http.Client();
  String? _access;

  Future<bool> isSignedIn() async {
    try {
      final t = await _storage.read(key: _kRefresh);
      return t != null && t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> register(String name, String email, String password) =>
      _authenticate('/auth/register', {
        'displayName': name.trim(),
        'email': email.trim(),
        'password': password,
      });

  Future<void> login(String email, String password) =>
      _authenticate('/auth/login', {
        'email': email.trim(),
        'password': password,
      });

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    http.Response r;
    try {
      r = await _client
          .post(Uri.parse('$baseUrl$path'),
              headers: _json, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(
          'Could not reach MindPal. Check your connection and try again.');
    }
    final data = decodeJson(r.body);
    if (r.statusCode == 200 || r.statusCode == 201) {
      await _saveSession(data);
      return;
    }
    throw AuthException(problemMessage(data));
  }

  Future<void> _saveSession(Map<String, dynamic> d) async {
    final access = d['accessToken'] as String;
    final refresh = d['refreshToken'] as String;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    _access = access;
  }

  /// POST with the access token. On 401 it refreshes the tokens once and retries.
  Future<http.Response> authorizedPost(
      String path, Map<String, dynamic> body) async {
    _access ??= await _storage.read(key: _kAccess);
    var r = await _send(path, body);
    if (r.statusCode == 401) {
      if (!await _refresh()) {
        await _clear();
        throw SessionExpiredException();
      }
      r = await _send(path, body);
      if (r.statusCode == 401) {
        await _clear();
        throw SessionExpiredException();
      }
    }
    return r;
  }

  Future<http.Response> _send(String path, Map<String, dynamic> body) =>
      _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          ..._json,
          if (_access != null) 'Authorization': 'Bearer $_access',
        },
        body: jsonEncode(body),
      );

  /// true = new tokens saved, false = server rejected the refresh token.
  /// Network problems are thrown, so a bad connection never signs the user out.
  Future<bool> _refresh() async {
    final rt = await _storage.read(key: _kRefresh);
    if (rt == null) return false;
    final r = await _client
        .post(Uri.parse('$baseUrl/auth/refresh'),
            headers: _json, body: jsonEncode({'refreshToken': rt}))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 401 || r.statusCode == 400) return false;
    if (r.statusCode != 200) throw Exception('Refresh failed');
    await _saveSession(decodeJson(r.body));
    return true;
  }

  Future<void> logout() async {
    try {
      final rt = await _storage.read(key: _kRefresh);
      if (rt != null) {
        await _client
            .post(Uri.parse('$baseUrl/auth/logout'),
                headers: _json, body: jsonEncode({'refreshToken': rt}))
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
    await _clear();
  }

  Future<void> _clear() async {
    _access = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}