import 'dart:math';

/// Content pools. The exercises pick from these with the session's seed, so
/// the same exercise feels different each time and the user never faces a
/// blank page. Wording is gentle: "may help", no health claims, no scoring.

T pickOne<T>(List<T> pool, int seed, [int salt = 0]) =>
    pool[Random(seed + salt * 7919).nextInt(pool.length)];

List<T> pickMany<T>(List<T> pool, int n, int seed) {
  final l = [...pool]..shuffle(Random(seed));
  return l.take(n).toList();
}

// Thought-based exercises: common thoughts to start from (tap, then edit).
const kCommonThoughts = [
  'I always mess things up.',
  'Everyone else is doing better than me.',
  'Something bad is going to happen.',
  'They must be upset with me.',
  'I cannot handle this.',
  'I should have done more.',
  'Nobody understands me.',
];

const kSituationIdeas = [
  'Before an exam or a presentation',
  'A conversation that did not go well',
  'Waiting for someone to reply',
  'Alone in the evening',
  'Something I read or saw online',
  'A moment with family',
];

const kGratitudeThings = [
  'A person who helped me', 'A good meal', 'Some rest', 'Time outdoors',
  'A kind word', 'Something I finished', 'Music', 'A quiet moment',
  'My own effort', 'Something that made me laugh', 'A message from someone',
  'A warm bed', 'Something I learned', 'Good weather', 'A favourite drink',
  'A place where I feel safe', 'Something I am looking forward to',
  'A memory that made me smile', 'A skill I have', 'Time with family',
];

const kGratitudeWhyPrompts = [
  'Pick one of them and write why it matters to you.',
  'Choose the one that surprised you most. What made it count today?',
  'Imagine it was missing from your day. What would be different?',
  'Who or what made this possible? Write a few words about them.',
  'What did this give you today: comfort, energy, a smile or a break?',
];

const kGratitudeWhyIdeas = [
  'It made my day easier.',
  'It helped me feel less alone.',
  'It gave me a break.',
  'It reminded me what matters.',
];

const kHardIdeas = [
  'An exam or a deadline',
  'Something I said or did',
  'How I feel about myself',
  'A relationship',
  'Feeling behind other people',
  'I am simply tired',
];

const kKindPrompts = [
  'Imagine a good friend felt this way. What kind thing would you say to them? Now write it to yourself.',
  'If a child you care about felt this, how would you speak to them? Say the same to yourself.',
  'What would you want to hear right now from someone who cares about you?',
];

const kKindIdeas = [
  'It is okay to find this hard.',
  'You are trying, and that counts.',
  'You do not have to be perfect to be worthy.',
  'I am here with you.',
];

const kProblemIdeas = [
  'A deadline I am worried about',
  'A disagreement with someone',
  'Too much to do at once',
  'A decision I keep putting off',
];

const kOptionIdeas = [
  'Ask someone for help',
  'Break it into smaller parts',
  'Take a short break first',
  'Do the easiest part first',
  'Write down what I already know',
  'Wait a day and look again',
];

const kFirstStepIdeas = [
  'Write down the first small task',
  'Send one message',
  'Set a 10-minute timer and begin',
  'Tidy my space, then start',
];

const kCheckInWords = [
  'Calm', 'Busy', 'Anxious', 'Hopeful', 'Tired', 'Focused', 'Sad', 'Grateful',
  'Stressed', 'Okay', 'Restless', 'Lonely', 'Motivated', 'Overwhelmed',
  'Content', 'Irritable', 'Curious', 'Numb',
];

const kCheckInNotePrompts = [
  'Anything else on your mind today? This is optional.',
  'What shaped your mood today? This is optional.',
  'What would make the rest of today a little easier? This is optional.',
  'What is one small thing you are glad about today? This is optional.',
];

const kCheckInNoteIdeas = [
  'Slept badly',
  'A good talk with someone',
  'Too much to do',
  'A quiet, easy day',
];

/// What to notice for each circle in the grounding exercise.
const Map<String, List<String>> kGroundingCues = {
  'see': [
    'Something far away',
    'Something close to you',
    'Something with a colour you like',
    'Something that is moving, or could move',
    'Something you have not looked at before',
  ],
  'feel': [
    'Your feet on the floor',
    'The surface under you',
    'The air on your skin',
    'The weight of your clothes',
  ],
  'hear': ['The farthest sound', 'The nearest sound', 'A sound that repeats'],
  'smell': ['Something in the air', 'Something on your hands or clothes'],
  'taste': ['What is in your mouth right now'],
};

const kObserveOptions = [
  'Thoughts', 'Feelings', 'My body', 'Sounds around me', 'Tension',
  'Hunger or thirst', 'Tiredness', 'Worry about the future',
  'Something I need to do', 'Something else',
];

const kProceedOptions = [
  'Carry on slowly', 'Ask for help', 'Take a short walk', 'Drink some water',
  'Write in my journal', 'Do one small task', 'Talk to someone I trust',
  'Stretch my shoulders', 'Look away from the screen for a minute',
];

/// Shown on the finish screen: one idea to keep from the exercise.
const Map<String, String> kTakeAway = {
  'sort': 'A thought is not always a fact. Separating what you know from what you are guessing can make a worry smaller.',
  'scale': 'A fair look at both sides often shows more than the first thought did.',
  'belief': 'How strongly you believe a thought can change when you look at it closely, and it can also stay the same. Both are fine.',
  'breathing': 'A slow breath out may help your body settle. You can do this anywhere, in under a minute.',
  'grounding': 'Noticing what your senses can find brings attention back to the present moment.',
  'thought_record': 'Writing the situation, thought and feeling apart shows how they connect, and where there is room for another view.',
  'gratitude': 'Looking for small good things trains attention to notice them, even on hard days.',
  'self_compassion': 'Speaking to yourself the way you would to a friend is a skill, and it gets easier with practice.',
  'problem_solving': 'A problem broken into options and one small step is easier to start than one that stays in your head.',
  'check_in': 'A daily check-in builds a picture of your days that you can look back on.',
  'stop': 'A short pause between a trigger and your reaction gives you a choice about what to do next.',
  'anchor': 'A phrase you have practised is easier to find when things feel hard.',
  'body_scan': 'Tension is easier to let go of once you notice it. Noticing is enough.',
};

/// Shown on the finish screen: small things to try later today.
const Map<String, List<String>> kTryToday = {
  'sort': [
    'The next time a worry shows up, ask: is this a fact or a guess?',
    'Write one worry on paper and mark each part Fact or Assumption.',
    'Tell a friend one assumption you caught yourself making.',
  ],
  'scale': [
    'Next time you judge yourself, name one piece of evidence on the other side.',
    'Ask a friend what they would say about your thought.',
  ],
  'belief': [
    'Rate a worry out of 100 now, and again tonight.',
    'Notice whether a thought feels as strong after you have eaten, rested or talked.',
  ],
  'breathing': [
    'Take three slow breaths before your next meal.',
    'Breathe out slowly while you wait for something today.',
  ],
  'grounding': [
    'The next time you feel tense, find five things you can see.',
    'Notice three sounds on your way to your next class or task.',
  ],
  'thought_record': [
    'Catch one thought today and write the situation next to it.',
    'Ask yourself: what would I say to a friend who had this thought?',
  ],
  'gratitude': [
    'Tell one person today that you appreciate them.',
    'Before sleep, name one good thing from today.',
  ],
  'self_compassion': [
    'Say your kind sentence out loud once today.',
    'When you notice self-criticism, add the words "and I am doing my best".',
  ],
  'problem_solving': [
    'Do your first step today, even for ten minutes.',
    'Tell someone your plan so it feels real.',
  ],
  'check_in': [
    'Check in again this evening and see what changed.',
    'Notice what lifts your energy today, even a little.',
  ],
  'stop': [
    'Use STOP once today, at a moment when nothing is wrong.',
    'Pause for one breath before you reply to your next message.',
  ],
  'anchor': [
    'Say your phrase quietly when you wake up.',
    'Put your phrase on a note where you will see it.',
  ],
  'body_scan': [
    'Before sleep, relax your shoulders and jaw.',
    'Notice your feet on the floor at three moments today.',
  ],
};
