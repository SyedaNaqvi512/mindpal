import 'dart:async';
import 'dart:convert';

import '../../../core/database/database_service.dart';
import '../../../core/errors/app_messages.dart';
import '../../auth/services/auth_service.dart';
import '../models/followup_logic.dart';

class FollowUpAnswer {
  const FollowUpAnswer({
    required this.reply,
    this.suggestions = const [],
    this.safety = false,
  });

  final String reply;
  final List<String> suggestions;
  final bool safety;
}

class FollowUpException implements Exception {
  FollowUpException(this.message, {this.code, this.limitReached = false});

  final String message;
  final String? code;
  final bool limitReached;

  @override
  String toString() => message;
}

/// Asks the server for the next answer.
abstract class FollowUpClient {
  Future<FollowUpAnswer> ask({
    required String entry,
    required String reflection,
    required List<Map<String, String>> history,
    required String message,
  });
}

class ApiFollowUpClient implements FollowUpClient {
  const ApiFollowUpClient();

  @override
  Future<FollowUpAnswer> ask({
    required String entry,
    required String reflection,
    required List<Map<String, String>> history,
    required String message,
  }) async {
    try {
      final r = await AuthService.instance.authorizedPost('/reflect/followup', {
        'entry': entry,
        'reflection': reflection,
        'history': history,
        'message': message,
      }).timeout(const Duration(seconds: 70));
      final data = decodeJson(r.body);

      if (r.statusCode == 200) {
        final reply = ((data['reply'] as String?) ?? '').trim();
        if (reply.isEmpty) {
          throw FollowUpException(AppMessages.generic);
        }
        final raw = data['suggestions'];
        return FollowUpAnswer(
          reply: reply,
          suggestions: raw is List
              ? raw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).take(3).toList()
              : const [],
          safety: data['safety'] == true,
        );
      }

      final code = data['code'] as String?;
      throw FollowUpException(
        AppMessages.resolve(
          code: code,
          status: r.statusCode,
          fieldError: fieldError(data),
        ),
        code: code,
        limitReached: code == 'followup_limit_reached',
      );
    } on SessionExpiredException {
      rethrow;
    } on FollowUpException {
      rethrow;
    } on AuthException catch (e) {
      throw FollowUpException(e.message, code: e.code);
    } on TimeoutException {
      throw FollowUpException(AppMessages.timeout, code: 'timeout');
    } catch (e) {
      throw FollowUpException(await AppMessages.forNetworkError(e), code: 'network');
    }
  }
}

/// Where the conversation is kept (the encrypted database on the phone).
abstract class ChatStore {
  Future<List<ChatMessage>> load(int entryId);

  Future<void> addPair(
    int entryId, {
    required String user,
    required String assistant,
    List<String> suggestions = const [],
  });

  Future<void> clear(int entryId);

  Future<String?> entryText(int entryId);
}

class DbChatStore implements ChatStore {
  const DbChatStore();

  @override
  Future<List<ChatMessage>> load(int entryId) async {
    await DatabaseService.ensureChatTable();
    final rows = await DatabaseService.getChatMessages(entryId);
    return [for (final r in rows) ChatMessage.fromRow(r)];
  }

  @override
  Future<void> addPair(
    int entryId, {
    required String user,
    required String assistant,
    List<String> suggestions = const [],
  }) async {
    await DatabaseService.ensureChatTable();
    await DatabaseService.addChatPair(
      entryId,
      user: user,
      assistant: assistant,
      suggestionsJson: suggestions.isEmpty ? null : jsonEncode(suggestions),
    );
  }

  @override
  Future<void> clear(int entryId) async {
    await DatabaseService.ensureChatTable();
    await DatabaseService.deleteChat(entryId);
  }

  @override
  Future<String?> entryText(int entryId) => DatabaseService.getEntryContent(entryId);
}
