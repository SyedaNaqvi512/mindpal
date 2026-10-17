import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../account/models/user_profile.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.code});
  final String message;

  /// Stable error code from the server (for example `invalid_code`).
  final String? code;

  @override
  String toString() => message;
}

class SessionExpiredException extends AuthException {
  SessionExpiredException()
      : super('Your session has expired. Please sign in again.');
}

/// Login was refused only because the email is not verified yet.
class EmailNotVerifiedException extends AuthException {
  EmailNotVerifiedException(this.email)
      : super('Please verify your email first.', code: 'email_not_verified');
  final String email;
}

class RegisterResult {
  const RegisterResult({required this.verificationRequired, required this.email});
  final bool verificationRequired;
  final String email;
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
  static const _network =
      'Could not reach MindPal. Check your connection and try again.';

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

  // ---- public (no token) calls -------------------------------------------

  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required String gender,
  }) async {
    final r = await _post('/auth/register', {
      'displayName': name.trim(),
      'email': email.trim(),
      'password': password,
      'gender': gender,
    });
    final data = decodeJson(r.body);
    if (r.statusCode != 200 && r.statusCode != 201) throw _error(data);
    final auth = data['auth'];
    final required = (data['verificationRequired'] as bool?) ?? false;
    if (!required && auth is Map<String, dynamic>) await _saveSession(auth);
    return RegisterResult(
      verificationRequired: required,
      email: (data['email'] as String?) ?? email.trim(),
    );
  }

  Future<void> login(String email, String password) async {
    final r = await _post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final data = decodeJson(r.body);
    if (r.statusCode == 200) {
      await _saveSession(data);
      return;
    }
    if (data['code'] == 'email_not_verified') {
      throw EmailNotVerifiedException(email.trim());
    }
    throw _error(data);
  }

  /// Checks the emailed code. On success the user is signed in.
  Future<void> verifyEmail(String email, String code) async {
    final r = await _post(
        '/auth/verify-email', {'email': email.trim(), 'code': code.trim()});
    final data = decodeJson(r.body);
    if (r.statusCode != 200) throw _error(data);
    await _saveSession(data);
  }

  Future<void> resendVerification(String email) async {
    final r = await _post('/auth/resend-verification', {'email': email.trim()});
    if (r.statusCode != 202 && r.statusCode != 200) {
      throw _error(decodeJson(r.body));
    }
  }

  Future<void> forgotPassword(String email) async {
    final r = await _post('/auth/forgot-password', {'email': email.trim()});
    if (r.statusCode != 202 && r.statusCode != 200) {
      throw _error(decodeJson(r.body));
    }
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    final r = await _post('/auth/reset-password', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
    if (r.statusCode != 204 && r.statusCode != 200) {
      throw _error(decodeJson(r.body));
    }
  }

  // ---- signed-in calls ---------------------------------------------------

  Future<UserProfile> fetchProfile() async {
    final r = await authorizedGet('/me');
    if (r.statusCode != 200) throw _error(decodeJson(r.body));
    return UserProfile.fromJson(decodeJson(r.body));
  }


  
 
 
  Future<UserProfile> updateProfile({
    String? displayName,
    int? avatarId,
  }) async {
    final r = await authorizedRequest('PATCH', '/me', {
      'displayName': ?displayName?.trim(),
      'avatarId': ?avatarId,
    });

    if (r.statusCode != 200) throw _error(decodeJson(r.body));

    return UserProfile.fromJson(decodeJson(r.body));
  }





  /// The server signs out every other device and returns fresh tokens for this one.
  Future<void> changePassword(String current, String next) async {
    final r = await authorizedPost('/me/password', {
      'currentPassword': current,
      'newPassword': next,
    });
    final data = decodeJson(r.body);
    if (r.statusCode != 200) throw _error(data);
    await _saveSession(data);
  }

  // ---- plumbing ----------------------------------------------------------

  AuthException _error(Map<String, dynamic> d) =>
      AuthException(problemMessage(d), code: d['code'] as String?);

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _client
          .post(Uri.parse('$baseUrl$path'),
              headers: _json, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(_network);
    }
  }

  Future<void> _saveSession(Map<String, dynamic> d) async {
    final access = d['accessToken'] as String;
    final refresh = d['refreshToken'] as String;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    _access = access;
  }

  /// Request with the access token. On 401 it refreshes the tokens once and retries.
  Future<http.Response> authorizedRequest(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    _access ??= await _storage.read(key: _kAccess);
    http.Response r;
    try {
      r = await _send(method, path, body);
      if (r.statusCode == 401) {
        if (!await _refresh()) {
          await _clear();
          throw SessionExpiredException();
        }
        r = await _send(method, path, body);
        if (r.statusCode == 401) {
          await _clear();
          throw SessionExpiredException();
        }
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(_network);
    }
    return r;
  }

  Future<http.Response> authorizedPost(String path, Map<String, dynamic> body) =>
      authorizedRequest('POST', path, body);

  Future<http.Response> authorizedGet(String path) =>
      authorizedRequest('GET', path);

  Future<http.Response> authorizedPut(String path, Map<String, dynamic> body) =>
      authorizedRequest('PUT', path, body);

  Future<http.Response> authorizedDelete(String path) =>
      authorizedRequest('DELETE', path);

  Future<http.Response> _send(
      String method, String path, Map<String, dynamic>? body) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll({
      ..._json,
      if (_access != null) 'Authorization': 'Bearer $_access',
    });
    if (body != null) request.body = jsonEncode(body);
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamed);
  }

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
