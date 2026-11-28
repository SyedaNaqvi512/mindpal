/// Plain-language notes for each thinking pattern (the ids match
/// `ThinkingPatterns`). They describe a common way of thinking that many
/// people notice in themselves. They are never a diagnosis, and every example
/// is made up. The wording is original.
class PatternGuide {
  const PatternGuide({required this.means, required this.example, required this.gentler});

  /// What the pattern is, in one or two sentences.
  final String means;

  /// A made-up example thought.
  final String example;

  /// A kinder question or step to try.
  final String gentler;
}

const Map<String, PatternGuide> kPatternGuides = {
  'all_or_nothing': PatternGuide(
    means: 'Seeing things in two boxes only, such as perfect or terrible, with '
        'nothing in between.',
    example: '"If I do not get full marks, the whole semester is ruined."',
    gentler: 'Look for the middle. What would a 6 out of 10 look like, and what '
        'did go okay?',
  ),
  'overgeneralization': PatternGuide(
    means: 'Taking one event and treating it as a rule for everything, often '
        'with words like always and never.',
    example: '"I forgot my notes once, so I always mess up presentations."',
    gentler: 'Ask whether this was one time or a real pattern. Can you remember '
        'a time it went differently?',
  ),
  'catastrophizing': PatternGuide(
    means: 'Jumping to the worst possible outcome and treating it as likely.',
    example: '"My friend has not replied, so she must be angry and the '
        'friendship is over."',
    gentler: 'Write the worst, the best and the most likely outcome. The most '
        'likely one is usually somewhere in the middle.',
  ),
  'mind_reading': PatternGuide(
    means: 'Assuming you know what other people think, usually something '
        'negative about you, without checking.',
    example: '"He looked at his phone while I spoke, so he thinks I am boring."',
    gentler: 'List other reasons that could explain it. If it matters, a kind '
        'question can help you check.',
  ),
  'emotional_reasoning': PatternGuide(
    means: 'Treating a feeling as proof that something is true.',
    example: '"I feel hopeless, so nothing will ever change."',
    gentler: 'A feeling is real information about you, but not always about the '
        'facts. What would you say to a friend who felt this way?',
  ),
  'should_statements': PatternGuide(
    means: 'Holding strict rules about how you or other people must behave, '
        'which brings guilt or frustration when they are not met.',
    example: '"I should be able to handle this without any help."',
    gentler: 'Try swapping "should" for "could" or "would like to". Does the '
        'rule still feel fair?',
  ),
  'labeling': PatternGuide(
    means: 'Giving yourself or someone else a fixed label instead of '
        'describing what happened.',
    example: '"I missed the deadline, so I am lazy."',
    gentler: 'Describe what happened instead of who you are: "I missed this '
        'deadline." Then ask what made it hard.',
  ),
  'personalization': PatternGuide(
    means: 'Taking too much of the blame for things that have many causes, or '
        'assuming events are about you.',
    example: '"The group project went badly, so it is all my fault."',
    gentler: 'Picture a pie of everything that could have contributed. How big '
        'is your slice, honestly?',
  ),
  'mental_filter': PatternGuide(
    means: 'Focusing on one negative detail and letting the good parts fade '
        'away.',
    example: '"I got ten kind comments and one critical one, and all I can '
        'think about is the critical one."',
    gentler: 'Name three things that went well, however small, and give them '
        'equal time.',
  ),
};
