import 'dart:convert';

/// Questions the user can ask after the reflection, for one entry.
const int maxFollowUps = 10;
const int maxChatMessageChars = 500;

/// Things to tap when the AI gave no suggestions of its own.
const List<String> defaultSuggestions = [
  'Help me look at this differently',
  'What can I try today?',
  'Why might I think this way?',
];

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.suggestions = const [],
  });

  final int? id;

  /// 'user' or 'assistant'.
  final String role;
  final String content;
  final DateTime createdAt;
  final List<String> suggestions;

  bool get isUser => role == 'user';

  factory ChatMessage.fromRow(Map<String, Object?> r) {
    var suggestions = <String>[];
    final raw = r['suggestions_json'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) suggestions = d.whereType<String>().toList();
      } catch (_) {}
    }
    return ChatMessage(
      id: r['id'] as int?,
      role: r['role'] as String,
      content: r['content'] as String,
      createdAt: DateTime.tryParse((r['created_at'] as String?) ?? '') ??
          DateTime.now(),
      suggestions: suggestions,
    );
  }
}

/// Each question the user asked counts once.
int questionsUsed(List<ChatMessage> messages) =>
    messages.where((m) => m.isUser).length;

int questionsLeft(List<ChatMessage> messages) =>
    (maxFollowUps - questionsUsed(messages)).clamp(0, maxFollowUps).toInt();

bool limitReached(List<ChatMessage> messages) => questionsLeft(messages) == 0;

/// A message for the question box, or null when the question can be sent.
String? validateQuestion(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Type your question first.';
  if (t.length > maxChatMessageChars) {
    return 'Keep your message under $maxChatMessageChars characters.';
  }
  return null;
}

/// The conversation as the server expects it: complete question and answer
/// pairs, oldest first. The server remembers nothing, so the whole
/// conversation is sent with each question.
List<Map<String, String>> historyPayload(List<ChatMessage> messages) {
  final out = <Map<String, String>>[];
  for (var i = 0; i + 1 < messages.length; i += 2) {
    final q = messages[i];
    final a = messages[i + 1];
    if (!q.isUser || a.isUser) break;
    out.add({'role': 'user', 'text': q.content});
    out.add({'role': 'assistant', 'text': a.content});
  }
  return out;
}

/// What to offer under the last answer.
List<String> suggestionsFor(List<ChatMessage> messages) {
  if (messages.isEmpty) return defaultSuggestions;
  final last = messages.last;
  if (!last.isUser && last.suggestions.isNotEmpty) return last.suggestions;
  return defaultSuggestions;
}

/// Changing text shown while the answer is written, so it is clear the app
/// is working.
String followUpWaitMessage(int seconds) {
  if (seconds >= 40) return 'This is taking longer than usual. You can keep waiting.';
  if (seconds >= 22) return 'Still working. Good answers can take a little time.';
  if (seconds >= 10) return 'Writing a reply…';
  if (seconds >= 4) return 'Looking back over our conversation…';
  return 'Thinking about what you said…';
}

// ---- Light formatting of the AI's answer ----

class ChatSpan {
  const ChatSpan(this.text, {this.bold = false});
  final String text;
  final bool bold;
}

class ChatBlock {
  const ChatBlock(this.text, {this.bullet = false});
  final String text;
  final bool bullet;
}

/// Paragraphs and bullet lines ("- ", "* " or "• ").
List<ChatBlock> parseChatBlocks(String input) {
  final blocks = <ChatBlock>[];
  final para = <String>[];

  void flush() {
    if (para.isNotEmpty) {
      blocks.add(ChatBlock(para.join('\n')));
      para.clear();
    }
  }

  for (final raw in input.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final bullet = RegExp(r'^(?:-|•|\*(?!\*))\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      flush();
      final t = bullet.group(1)!.trim();
      if (t.isNotEmpty) blocks.add(ChatBlock(t, bullet: true));
    } else {
      para.add(line);
    }
  }
  flush();
  return blocks;
}

/// Splits a line into normal and **bold** pieces. An unclosed ** is ignored.
List<ChatSpan> parseSpans(String s) {
  final parts = s.split('**');
  if (parts.length % 2 == 0 && parts.length >= 2) {
    final last = parts.removeLast();
    parts[parts.length - 1] = parts.last + last;
  }
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) ChatSpan(parts[i], bold: i.isOdd),
  ];
}

/// The answer as plain text (for copying).
String plainChatText(String s) => s.replaceAll('**', '');
