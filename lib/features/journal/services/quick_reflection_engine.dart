import 'reflection_engine.dart';

/// Basic offline reflection. No AI and no model: it matches phrases to one of the
/// nine thinking patterns of SRS FR-21 and fills a fixed five-part template.
/// It is used when the cloud is unavailable or the phone is offline, and it is
/// always labelled as basic. Patterns are suggestions, never diagnoses (FR-22).
class QuickReflectionEngine implements ReflectionEngine {
  QuickReflectionEngine();

  @override
  Future<ReflectionResult> reflect(String entry) async => analyze(entry);

  ReflectionResult analyze(String entry) {
    final t = entry.toLowerCase().replaceAll('’', "'");

    _Pattern? best;
    var bestScore = 0;
    for (final p in _patterns) {
      final score = p.trigger.allMatches(t).length;
      if (score > bestScore) {
        best = p;
        bestScore = score;
      }
    }

    const thanks = 'Thank you for writing this down. It sounds like this is '
        'weighing on you.';

    if (best == null) {
      return const ReflectionResult(
        parts: ReflectionParts(
          acknowledgement: thanks,
          questions: [
            'What exactly happened, in facts anyone could see?',
            'What parts of this are things you are assuming?',
          ],
          balanced: 'A hard moment is real, and it is not the whole story of '
              'your day or of you.',
          nextStep: 'Take a few slow breaths, then choose one small thing you '
              'can do in the next ten minutes.',
        ),
        text: '$thanks\n\n'
            'Questions to try:\n'
            '- What exactly happened, in facts anyone could see?\n'
            '- What parts of this are things you are assuming?\n\n'
            'A more balanced thought:\n'
            'A hard moment is real, and it is not the whole story of your '
            'day or of you.\n\n'
            'One small next step:\n'
            'Take a few slow breaths, then choose one small thing you can do '
            'in the next ten minutes.',
      );
    }

    return ReflectionResult(
      pattern: best.id,
      parts: ReflectionParts(
        acknowledgement: thanks,
        pattern: best.id,
        patternNote: best.explain,
        questions: best.questions,
        balanced: best.balanced,
        nextStep: best.step,
      ),
      text: '$thanks\n\n'
          'A thinking pattern that might be showing up (only a suggestion): '
          '${best.name}.\n${best.explain}\n\n'
          'Questions to try:\n'
          '- ${best.questions[0]}\n'
          '- ${best.questions[1]}\n\n'
          'A more balanced thought:\n${best.balanced}\n\n'
          'One small next step:\n${best.step}',
    );
  }
}

class _Pattern {
  _Pattern({
    required this.id,
    required this.name,
    required String trigger,
    required this.explain,
    required this.questions,
    required this.balanced,
    required this.step,
  }) : trigger = RegExp(trigger);

  final String id;
  final String name;
  final RegExp trigger;
  final String explain;
  final List<String> questions;
  final String balanced;
  final String step;
}

// Order matters: when two patterns match equally often, the earlier one wins.
final List<_Pattern> _patterns = [
  _Pattern(
    id: 'catastrophizing',
    name: 'Catastrophizing',
    trigger: r"\b(?:disaster|catastroph\w*|worst|end of the world|"
        r"ruin(?:ed|s)? my (?:life|future|career)|will fail|going to fail|"
        r"never recover|can't handle|cannot handle|what if)\b",
    explain: 'This means jumping to the worst possible outcome.',
    questions: [
      'What is the most likely outcome, not the worst one?',
      'If the worst did happen, how would you cope, and who could help?',
    ],
    balanced: 'It might go badly, but many other outcomes are possible, and '
        'I can handle a lot more than my worry says.',
    step: 'Write down one thing you can do today to prepare, and do only that.',
  ),
  _Pattern(
    id: 'mind_reading',
    name: 'Mind reading',
    trigger: r"\b(?:he|she|they|everyone|everybody|people|teacher|friends?|"
        r"classmates?)\s+(?:thinks?|thought|must think|probably thinks?)\b|"
        r"\b(?:dislikes?|hates?|mocks?|mocked|mocking|judges?|judging|"
        r"laughing at|laughs at|laughed at|talking about|makes fun of|"
        r"made fun of)\s+me\b",
    explain: 'This means assuming you know what others think without '
        'checking.',
    questions: [
      'What facts do you have about what they really think?',
      'What other explanations could there be for what they did?',
    ],
    balanced: "I can't read minds. There may be other reasons for what "
        'happened, and I can ask instead of assuming.',
    step: 'If it feels safe, ask the person one calm question, or note one '
        'other possible explanation.',
  ),
  _Pattern(
    id: 'personalization',
    name: 'Personalization',
    trigger: r"\b(?:my fault|because of me|i caused|i ruined|blame myself|"
        r"i'm to blame|i am to blame|it's on me|"
        r"i let (?:everyone|them|her|him) down)\b",
    explain: 'This means taking all the blame for something that has many '
        'causes.',
    questions: [
      'What other people or circumstances also played a part?',
      'If a friend were in your place, how much blame would you give them?',
    ],
    balanced: 'I played a part, but it was not only me. Several things '
        'contributed.',
    step: 'List two other factors that contributed, then decide one thing '
        'you can learn from this.',
  ),
  _Pattern(
    id: 'labeling',
    name: 'Labeling',
    trigger: r"\bi(?: am|'m|m) (?:not (?:hardworking|good enough|smart|good|"
        r"enough)|(?:a |an |so |such a )?(?:failure|loser|stupid|useless|"
        r"worthless|dumb|idiot|lazy|burden))\b",
    explain: 'This means calling yourself a harsh name instead of describing '
        'one event.',
    questions: [
      'Does one event or one result define your whole worth?',
      'What would you say to a friend who described themselves this way?',
    ],
    balanced: 'One result or one mistake does not define me. I am a person '
        'who is still learning.',
    step: 'Write one thing you did well recently, however small.',
  ),
  _Pattern(
    id: 'should_statements',
    name: 'Should statements',
    trigger: r"\b(?:should(?:n't| not| have)?|must|ought to|supposed to|"
        r"have to|need to)\b",
    explain: 'This means holding yourself to strict rules about how things '
        '"must" be.',
    questions: [
      'Where does this rule come from, and is it realistic?',
      'What would you say to a friend with the same rule?',
    ],
    balanced: 'I would like to do well, but I am allowed to be human and to '
        'do my best with the time and energy I have.',
    step: 'Rewrite one "should" as "I would like to" and pick one small '
        'action for it.',
  ),
  _Pattern(
    id: 'emotional_reasoning',
    name: 'Emotional reasoning',
    trigger: r"\bi feel like (?:a|an|such|i am|i'm|it's|it is)\b|"
        r"\bfeel(?:ing)? (?:stupid|worthless|useless|like a failure)\b",
    explain: 'This means treating a feeling as proof that something is true.',
    questions: [
      'What facts support this, apart from how it feels?',
      'Has a feeling like this been wrong before?',
    ],
    balanced: 'A strong feeling is real, but it is not proof. Feelings '
        'change, and facts can be checked.',
    step: 'Name the feeling in one word, then write one fact that '
        'disagrees with it.',
  ),
  _Pattern(
    id: 'mental_filter',
    name: 'Mental filter',
    trigger: r"\b(?:one mistake|one bad|just one|only the bad|"
        r"only the negative|can't stop thinking about|"
        r"cannot stop thinking about|keep thinking about|"
        r"all i can think about|nothing good)\b",
    explain: 'This means focusing on one negative detail and filtering out '
        'the rest.',
    questions: [
      'What else happened today that you are leaving out?',
      'How big is this one detail compared with the whole picture?',
    ],
    balanced: 'This one thing matters to me, but it is only part of the '
        'picture. There were other moments too.',
    step: 'Write down three neutral or good things from today, even small '
        'ones.',
  ),
  _Pattern(
    id: 'all_or_nothing',
    name: 'All-or-nothing thinking',
    trigger: r"\b(?:all or nothing|completely|totally|entirely|perfect|"
        r"ruined everything|total failure|complete failure|complete waste)\b",
    explain: 'This means seeing things as only perfect or a total failure, '
        'with nothing in between.',
    questions: [
      'Is there a middle ground between perfect and failure here?',
      'What part of this went reasonably well?',
    ],
    balanced: 'Things are rarely all good or all bad. I can fall short in '
        'one area and still have made progress.',
    step: 'Rate this situation from 0 to 100 instead of pass or fail, and '
        'note one thing that would move it up by five points.',
  ),
  _Pattern(
    id: 'overgeneralization',
    name: 'Overgeneralization',
    trigger: r"\b(?:always|never|every time|nobody|no one|everyone|"
        r"everything|nothing ever|all the time)\b",
    explain: 'This means drawing a broad conclusion from one or a few '
        'events.',
    questions: [
      'Can you remember a time when this did not happen?',
      'Is "always" or "never" really accurate, or is it "this time"?',
    ],
    balanced: 'This happened, but it does not mean it always will. There '
        'are exceptions, and this is one moment.',
    step: 'Write down one past example that does not fit "always" or '
        '"never".',
  ),
];