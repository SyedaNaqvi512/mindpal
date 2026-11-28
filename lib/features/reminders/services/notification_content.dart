// The words of MindPal's notifications, and the pure logic that picks one for
// each day. Everything here is plain Dart, so it is unit tested.
//
// Rules for every line: warm and short, never about a streak, a miss or a
// failure, never any journal text, no medical claims, and no made-up quotes
// from real people. The thoughts are written for MindPal.

/// Short titles for the daily check-in reminder.
const List<String> kCheckInTitles = [
  'MindPal',
  'A quiet minute',
  'Checking in',
  'Hello, you',
  'Time for you',
  'A gentle hello',
];

/// Bodies for the daily check-in reminder. They invite, they never push.
const List<String> kCheckInBodies = [
  'How are you feeling today? A minute is enough.',
  'Take a breath. When you are ready, your journal is here.',
  'No pressure, just a gentle check-in. How is your day going?',
  'A few words about today can make it feel lighter.',
  'Pause for a moment. What is on your mind right now?',
  'Your journal is a safe place. Stop by whenever you like.',
  'How is your heart today? Tell it to the page.',
  'A tiny check-in now can help you understand your day later.',
  'It is a good moment to notice how you feel.',
  'Whatever today looked like, you are welcome here.',
  'Want to put today into words? Even one line counts.',
  'Slow down for a minute and see how you are doing.',
  'Small moments of care add up. Check in with yourself.',
  'You do not have to have the right words. Just start.',
  'Take a minute for yourself. You deserve it.',
  'How did today treat you? Write it down, then let it go.',
  'Be kind to yourself today, and check in when you can.',
  'A calm minute with your thoughts is waiting for you.',
  'What went well today, even a little? Note it down.',
  'Notice one feeling right now. Give it a name.',
  'Your feelings are allowed to be exactly as they are.',
  'Come back to yourself for a minute. MindPal is ready.',
  'Today does not need to be perfect to be worth a few words.',
  'Checking in is a way of looking after yourself.',
  'How are you, really? There is room for the honest answer here.',
  'End the day gently. Write one thing you noticed.',
  'You showed up for today. Want to look back on it for a moment?',
  'If your mind feels busy, writing can give it somewhere to rest.',
  'Ready when you are. A short entry is a good entry.',
  'A little reflection can turn a heavy day into a lighter one.',
];

/// Short thoughts about the mind, one for each day. Written for MindPal.
const List<String> kQuotes = [
  'A thought is not a fact. You can notice it without believing it.',
  'You do not have to calm every storm. Sometimes it is enough to breathe while it passes.',
  'Feelings come like weather. They are real, and they change.',
  'Rest is not a reward you earn. It is something you need.',
  'Speak to yourself the way you would speak to a friend you care about.',
  'Progress is often quiet. Small steps still move you forward.',
  'You can feel two things at once: tired and hopeful, nervous and ready.',
  'Naming a feeling gives it a shape, and a shape is easier to hold.',
  'Not every thought that visits needs a place to stay.',
  'Being gentle with yourself is not giving up. It is how you keep going.',
  'A hard day does not make a hard life. Let today be only today.',
  'Take one breath all the way in, and all the way out. You are here.',
  'You are allowed to take up space with your feelings.',
  'It is okay to ask for help. That is a strong thing to do.',
  'Your worth does not depend on how much you did today.',
  'Notice what is going well, even if it is small. Small things count.',
  'You do not have to figure everything out tonight.',
  'When your mind races, try slowing the breath first. The thoughts often follow.',
  'Worry tries to solve tomorrow today. Come back to this moment.',
  'Sadness is not a flaw. It often shows what matters to you.',
  'You have got through hard days before. That strength is still yours.',
  'Be patient with your mind. It is learning, just like you.',
  'Writing a feeling down is a way of listening to yourself.',
  'You can set something down for now and pick it up when you are ready.',
  'A kind word to yourself costs nothing and can change an evening.',
  'It is okay to start again. Every new day is a fresh page.',
  'Comparison is a thief of calm. Your pace is your own.',
  'What you feel is information, not a verdict.',
  'Even a few minutes of quiet can help your mind reset.',
  'You are more than your worst thought of the day.',
  'Look for what you can control today, and let the rest be.',
  'Gratitude does not erase the hard parts. It makes room for the good ones too.',
  'Slow is still moving. Rest is part of the journey.',
  'Mistakes are how learning leaves its mark. You are learning.',
  'Let the thought pass like a cloud. You are the sky, not the cloud.',
  'Do one kind thing for yourself today, however small.',
  'Boundaries are a way of caring for your energy.',
  'You do not need to be fearless. You can be afraid and still take a step.',
  'Your feelings make sense, even when they are hard to explain.',
  'Be curious about your thoughts instead of judging them.',
  'Some days the best you can do is enough.',
  'Unclench your shoulders. Soften your jaw. Breathe out slowly.',
  'There is no right way to feel, just your own way, right now.',
  'Healing is not a straight line, and that is perfectly normal.',
  'Make room for joy, even on busy days. It counts too.',
  'Notice three things you can see, two you can hear, one you can feel. You are here.',
  'You can be proud of how far you have come and still be growing.',
  'Quiet moments are not empty. They are where your mind catches up.',
  'It helps to ask: what would I say to someone I love who felt this way?',
  'The goal is not to feel nothing. It is to feel and still be kind to yourself.',
  'Sleep, water, a little light and fresh air are small acts of mind care.',
  'Your story is still being written, and you hold the pen.',
  'Try to catch one all-or-nothing thought today, and look for the middle.',
  'Letting go can start with one slow breath.',
  'Today, choose progress over perfect.',
  'You are allowed to change your mind, your plans and your pace.',
  'Listening to yourself is a skill, and it grows with practice.',
  'Peace is not the absence of problems. It is a little calm inside them.',
  'The way you talk to yourself shapes the way you feel. Choose softer words.',
  'Be proud of the days you simply kept going.',
  'Your mind needs care, just like your body. Give it a minute today.',
];

/// Title of the daily thought notification.
const List<String> kQuoteTitles = [
  'A thought for today',
  'A moment of calm',
  'For your mind today',
  'A small reminder',
];

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// A step that visits every item of a list of [n] before any repeats, and
/// that jumps around so neighbours in the list are not neighbours in time.
int _step(int n) {
  for (final s in const [7, 11, 13, 17, 5, 3, 1]) {
    if (s < n && _gcd(s, n) == 1) return s;
  }
  return 1;
}

/// Whole days since 1 Jan 1970 for a calendar date, ignoring the time of day
/// and daylight saving.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1970)).inDays;

/// The item of [pool] for [day]. The same day always gives the same item,
/// the next day gives a different one, and the whole pool is used before any
/// item comes back. [salt] makes two pools pick differently on the same day.
String pickForDay(List<String> pool, DateTime day, {int salt = 0}) {
  assert(pool.isNotEmpty);
  final n = pool.length;
  final i = ((dayNumber(day) * _step(n) + salt) % n + n) % n;
  return pool[i];
}

/// A notification to schedule.
class PlannedNotification {
  const PlannedNotification(this.when, this.title, this.body);

  final DateTime when;
  final String title;
  final String body;
}

/// The next [count] times a daily notification should fire at [minutes] after
/// midnight, starting with today if that time is still ahead.
List<DateTime> upcomingTimes(DateTime now, int minutes, {int count = 14}) {
  final h = minutes ~/ 60, m = minutes % 60;
  final today = DateTime(now.year, now.month, now.day, h, m);
  final first = today.isAfter(now) ? 0 : 1;
  return [
    for (var i = 0; i < count; i++) DateTime(now.year, now.month, now.day + first + i, h, m),
  ];
}

/// The check-in reminders for the next [count] days, each with its own words.
List<PlannedNotification> planCheckIns(DateTime now, int minutes, {int count = 14}) => [
      for (final t in upcomingTimes(now, minutes, count: count))
        PlannedNotification(
          t,
          pickForDay(kCheckInTitles, t, salt: 2),
          pickForDay(kCheckInBodies, t),
        ),
    ];

/// The daily thoughts for the next [count] days, a different one each day.
List<PlannedNotification> planQuotes(DateTime now, int minutes, {int count = 14}) => [
      for (final t in upcomingTimes(now, minutes, count: count))
        PlannedNotification(
          t,
          pickForDay(kQuoteTitles, t, salt: 1),
          pickForDay(kQuotes, t),
        ),
    ];
