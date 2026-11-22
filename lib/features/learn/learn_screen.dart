import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/fade_slide_in.dart';
import '../safety/support_screen.dart';
import 'breathing_session_screen.dart';
import 'learn_content.dart';

/// FR-64: the list of Learn articles. Opened from the Home card and from the
/// Exercise Library. It reads only bundled text, so it works offline.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Short reads about mindfulness and how it connects to your '
            'journal. They work without internet, and nothing you read here '
            'is saved or sent anywhere.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < kArticles.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 40 * i),
              child: _ArticleCard(article: kArticles[i]),
            ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ArticleScreen(article: article)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(article.icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(article.summary,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('${article.minutes} min read',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One article. FR-68: it ends with the "not therapy" note.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(article.icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Text('${article.minutes} min read',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(article.title,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          for (final b in article.blocks) _BlockView(block: b),
          if (article.action != LearnAction.none) ...[
            const SizedBox(height: 18),
            _ActionButton(action: article.action),
          ],
          const SizedBox(height: 22),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.info_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kNotTherapyNote,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final Block block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    switch (block.kind) {
      case BlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(block.text,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        );
      case BlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(block.text, style: const TextStyle(fontSize: 16, height: 1.55)),
        );
      case BlockKind.bullets:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in block.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, right: 12, left: 4),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final LearnAction action;

  @override
  Widget build(BuildContext context) {
    final isBreathing = action == LearnAction.breathing;

    return FilledButton.icon(
      icon: Icon(isBreathing ? Symbols.air_rounded : Symbols.favorite_rounded),
      label: Text(isBreathing
          ? 'Try the 5-minute Breathing Bubble'
          : 'See support contacts'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isBreathing
              ? const BreathingSessionScreen()
              : const SupportScreen(),
        ),
      ),
    );
  }
}
