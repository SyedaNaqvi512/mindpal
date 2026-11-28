import '../../core/theme/app_look.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/motion/motion.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/motion_kit.dart';
import '../safety/support_screen.dart';
import 'breathing_session_screen.dart';
import 'learn_content.dart';
import 'learn_content_ur.dart';
import 'learn_language.dart';

/// FR-64: the list of Learn articles. Opened from Settings and from the
/// Exercise Library. It reads only bundled text, so it works offline. The
/// reader can switch between English and Urdu (the choice is remembered).
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<String>(
      valueListenable: learnLanguage,
      builder: (context, lang, _) {
        final ur = lang == 'ur';
        return Scaffold(
          appBar: AppBar(title: Text(ur ? kLearnTitleUr : 'Learn')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const LanguageToggle(),
              const SizedBox(height: 12),
              Directionality(
                textDirection: ur ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  ur
                      ? kLearnIntroUr
                      : 'Short reads about mindfulness and how it connects to your '
                          'journal. They work without internet, and nothing you read here '
                          'is saved or sent anywhere.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontFamily: ur ? kUrduFamily : null,
                    height: ur ? 2.0 : 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < kArticles.length; i++)
                FadeSlideIn(
                  press: true,
                  delay: staggerDelay(i),
                  child: _ArticleCard(article: kArticles[i], lang: lang),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A two-choice switch: English or Urdu. It sets [learnLanguage].
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: learnLanguage,
      builder: (context, lang, _) => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'en', label: Text('English')),
          ButtonSegment(
            value: 'ur',
            label: Text('اردو', style: TextStyle(fontFamily: kUrduFamily, height: 1.6)),
          ),
        ],
        showSelectedIcon: false,
        selected: {lang},
        onSelectionChanged: (s) => setLearnLanguage(s.first),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.lang});

  final Article article;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ur = lang == 'ur';
    final t = articleText(article, lang);
    final family = ur ? kUrduFamily : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ArticleScreen(article: article)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: ur ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppLook.of(context).fieldRadius),
                ),
                child: Icon(article.icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: family,
                            height: ur ? 1.9 : null)),
                    const SizedBox(height: 2),
                    Text(t.summary,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontFamily: family,
                            height: ur ? 1.9 : null)),
                    const SizedBox(height: 6),
                    Text(ur ? minutesReadUr(article.minutes) : '${article.minutes} min read',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontFamily: family,
                            height: ur ? 1.9 : null)),
                  ],
                ),
              ),
              Icon(
                ur ? Symbols.chevron_left_rounded : Symbols.chevron_right_rounded,
                color: scheme.primary,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// One article. FR-68: it ends with the "not therapy" note. A thin bar under
/// the title shows how far down the article the reader is.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final _scroll = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final p = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    if ((p - _progress).abs() > 0.01) setState(() => _progress = p);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: learnLanguage,
      builder: (context, lang, _) => _buildFor(context, lang),
    );
  }

  Widget _buildFor(BuildContext context, String lang) {
    final article = widget.article;
    final ur = lang == 'ur';
    final t = articleText(article, lang);
    final family = ur ? kUrduFamily : null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ur ? kLearnTitleUr : 'Learn',
            style: ur ? const TextStyle(fontFamily: kUrduFamily, height: 1.8) : null),
        actions: [
          IconButton(
            tooltip: ur ? 'Read in English' : 'اردو میں پڑھیں',
            icon: const Icon(Symbols.translate_rounded),
            onPressed: () => setLearnLanguage(ur ? 'en' : 'ur'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _progress),
            duration: Motion.of(context, const Duration(milliseconds: 200)),
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 3,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: ur ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                PopIn(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppLook.of(context).fieldRadius),
                    ),
                    child: Icon(article.icon, color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(ur ? minutesReadUr(article.minutes) : '${article.minutes} min read',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontFamily: family,
                        height: ur ? 1.9 : null)),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(t.title,
                  style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFamily: family,
                      height: ur ? 1.9 : null)),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < t.blocks.length; i++)
              FadeSlideIn(
                key: ValueKey('$lang-$i'),
                delay: staggerDelay(i, stepMs: 35, maxSteps: 6),
                offset: 0.03,
                child: _BlockView(block: t.blocks[i], urdu: ur),
              ),
            if (article.action != LearnAction.none) ...[
              const SizedBox(height: 18),
              _ActionButton(action: article.action, urdu: ur),
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
                      child: Text(ur ? kNotTherapyNoteUr : kNotTherapyNote,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontFamily: family,
                              height: ur ? 1.9 : 1.4)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.urdu});

  final Block block;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final family = urdu ? kUrduFamily : null;
    final body = TextStyle(
        fontSize: urdu ? 17 : 16, height: urdu ? 2.0 : 1.55, fontFamily: family);

    switch (block.kind) {
      case BlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(block.text,
                style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: family,
                    height: urdu ? 1.9 : null)),
          ),
        );
      case BlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(block.text, style: body),
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
                      padding: EdgeInsetsDirectional.only(
                          top: urdu ? 16 : 9, end: 12, start: 4),
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
                      child: Text(item, style: body.copyWith(height: urdu ? 2.0 : 1.5)),
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
  const _ActionButton({required this.action, required this.urdu});

  final LearnAction action;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    final isBreathing = action == LearnAction.breathing;

    return FilledButton.icon(
      icon: Icon(isBreathing ? Symbols.air_rounded : Symbols.favorite_rounded),
      label: Text(
        urdu
            ? (isBreathing ? kBreathingButtonUr : kSupportButtonUr)
            : (isBreathing ? 'Try the 5-minute Breathing Bubble' : 'See support contacts'),
        style: urdu ? const TextStyle(fontFamily: kUrduFamily, height: 1.7) : null,
      ),
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
