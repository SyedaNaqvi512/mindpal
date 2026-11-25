import '../services/exercise_controller.dart';

/// Short, plain "why this helps" notes and examples for each step, so the
/// exercises explain themselves instead of only asking questions. No scoring
/// or failure wording (FR-43).
const Map<String, Map<String, StepGuide>> kStepGuides = {
  'sort': {
    'Your thought': StepGuide(
      'A thought can feel like a fact. Writing it down lets you look at it from a little distance.',
      'I will mess up the presentation and everyone will notice.',
    ),
    'Sort the statements': StepGuide(
      'A fact is something anyone could observe or check. An assumption is a guess, a prediction or a belief about what others think.',
      '"The presentation is at 10" is a fact. "Everyone will think I am useless" is an assumption.',
    ),
  },
  'scale': {
    'Your thought': StepGuide(
      'Pick one thought that is weighing on you. One at a time is easier to look at.',
      'I always let people down.',
    ),
    'Evidence for': StepGuide(
      'Be fair to the thought first. Real evidence is something you could show, not only a feeling.',
      'I missed a deadline last month.',
    ),
    'Evidence against': StepGuide(
      'Now look for what does not fit: times it was not true, or what a good friend would say.',
      'I helped a friend move last week and she thanked me.',
    ),
  },
  'belief': {
    'Your thought': StepGuide(
      'Choose a thought you would like to look at. It helps to use the exact words you hear in your head.',
    ),
    'How strongly do you believe it?': StepGuide(
      'This first rating gives you something to compare with later. There is no right or wrong number.',
    ),
    'Think it through': StepGuide(
      'Write what makes the thought feel true, and what does not quite fit it. Both sides count.',
      'It feels true because I made a mistake. It does not fit that I also did most of it well.',
    ),
    'Rate it again': StepGuide(
      'The number may move a lot, a little or not at all. Any of these is fine, and each tells you something.',
    ),
  },
  'thought_record': {
    'The situation': StepGuide(
      'Stick to what happened: who, where, when. Keep how you read it for the next step.',
      'Tuesday, team meeting. My manager moved on without discussing my idea.',
    ),
    'Your thought': StepGuide(
      'Write the thought the way it sounded in your head, even if it feels harsh.',
      'They do not value my work.',
    ),
    'How you felt': StepGuide(
      'Naming a feeling clearly can make it a little easier to carry. More than one can be true at once.',
    ),
    'How strong was it?': StepGuide(
      'Feelings rise and fall. This number is only for this moment.',
    ),
    'Evidence for the thought': StepGuide(
      'What actually happened that supports the thought? Facts, not guesses.',
      'My idea was not mentioned in the notes.',
    ),
    'Evidence against the thought': StepGuide(
      'What does not fit? Think of times it was different, or another way to read the situation.',
      'Last month the same manager praised my report in front of everyone.',
    ),
  },
  'gratitude': {
    'Things to appreciate': StepGuide(
      'Looking for small good things trains your attention to notice them. Ordinary things count.',
    ),
    'Why it matters': StepGuide(
      'A few words about why something matters make it feel more real than a list.',
      'The tea break mattered because it was the first quiet moment I had all day.',
    ),
    'Carry it with you': StepGuide(
      'One sentence is easier to remember later than a whole page.',
      'Today I noticed that people were kind to me.',
    ),
  },
  'self_compassion': {
    'Something hard': StepGuide(
      'Name what is hard without judging it. A few words are enough.',
    ),
    'Notice what you feel': StepGuide(
      'Noticing a feeling is different from being taken over by it.',
    ),
    'You are not alone': StepGuide(
      'Feeling this way is part of being human. It does not mean something is wrong with you.',
    ),
    'A kind sentence': StepGuide(
      'We are often gentler with friends than with ourselves. Try saying to yourself what you would say to them.',
      'It is okay that this is hard. You are doing what you can.',
    ),
  },
  'problem_solving': {
    'The problem': StepGuide(
      'A problem written in one or two clear sentences is smaller than the one that goes round in your head.',
      'I have three assignments due in the same week.',
    ),
    'Possible options': StepGuide(
      'List first, judge later. Include small and imperfect ideas; they often lead to good ones.',
      'Ask for an extension. Start with the shortest one. Study with a friend.',
    ),
    'Choose one': StepGuide(
      'You do not need the perfect option, only one that feels doable right now.',
    ),
    'A small first step': StepGuide(
      'A step that takes ten minutes is easier to start than a plan.',
      'Open the assignment and write the headings.',
    ),
    'When': StepGuide(
      'Choosing a time makes it far more likely that the step happens.',
    ),
  },
  'check_in': {
    'Mood': StepGuide(
      'Check in honestly, not the way you think you should feel. Over time your check-ins show patterns.',
    ),
    'Energy': StepGuide(
      'Mood and energy are different. You can feel low but wired, or calm but tired.',
    ),
    'In a few words': StepGuide(
      'Choosing words gives your day a shape you can recognise later.',
    ),
    'A short note': StepGuide(
      'Anything that explains today is useful to look back on. This step is optional.',
    ),
  },
  'stop': {
    'S: Stop': StepGuide('Pausing breaks the automatic rush. Even a few seconds helps.'),
    'T: Take a breath': StepGuide('A slow breath out tells your body it can ease a little.'),
    'O: Observe': StepGuide(
      'Look at what is here: thoughts, feelings, body, surroundings. You only need to notice.',
    ),
    'P: Proceed': StepGuide('Choose the next small thing, with kindness toward yourself.'),
  },
  'anchor': {
    'Choose a phrase': StepGuide(
      'A short phrase you believe is easier to hold on to than a long one.',
      'One breath at a time.',
    ),
    'Read it as you breathe': StepGuide(
      'Pairing the phrase with slow breathing makes it easier to find again when you need it.',
    ),
  },
  'breathing': {
    'Breathe': StepGuide(
      'Breathing out slowly can settle the body. Follow the bubble at a pace that feels comfortable.',
    ),
  },
};

/// Used when a step has no note of its own (the grounding steps and the body
/// scan areas).
const Map<String, StepGuide> kExerciseGuideFallback = {
  'grounding': StepGuide(
    'Noticing things you can sense pulls your attention to the present moment and away from worry.',
  ),
  'body_scan': StepGuide(
    'Let your attention rest on this area. You do not need to change anything; noticing is enough.',
  ),
};

StepGuide? guideFor(String exerciseId, String stepTitle) =>
    kStepGuides[exerciseId]?[stepTitle] ?? kExerciseGuideFallback[exerciseId];

List<ExerciseStep> applyGuides(String exerciseId, List<ExerciseStep> steps) => [
      for (final s in steps) s.withGuide(guideFor(exerciseId, s.title)),
    ];
