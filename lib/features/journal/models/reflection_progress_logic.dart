/// What the user reads while a reflection is being written. The text changes
/// as time passes, so it is clear the app is working and not stuck.
class ReflectionStage {
  const ReflectionStage({
    required this.index,
    required this.total,
    required this.message,
    this.slow = false,
  });

  /// Which step is current (0 based) and how many steps there are.
  final int index;
  final int total;
  final String message;

  /// True once it is taking longer than usual.
  final bool slow;
}

class _Step {
  const _Step(this.from, this.message, {this.slow = false});
  final int from; // seconds
  final String message;
  final bool slow;
}

const _cloud = <_Step>[
  _Step(0, 'Reading your entry…'),
  _Step(4, 'Looking for thinking patterns…'),
  _Step(10, 'Thinking of gentle questions…'),
  _Step(20, 'Writing your reflection…'),
  _Step(35, 'Still working. A careful reflection can take a little time.',
      slow: true),
  _Step(55, 'This is taking longer than usual. Your entry is already saved.',
      slow: true),
];

const _device = <_Step>[
  _Step(0, 'Getting the private model ready on your phone…'),
  _Step(6, 'Reading your entry…'),
  _Step(15, 'Writing your reflection on this phone…'),
  _Step(40, 'Private mode is slower. Still working, and nothing leaves your phone.',
      slow: true),
  _Step(70, 'This is taking longer than usual. Your entry is already saved.',
      slow: true),
];

/// The stage to show after [seconds] of waiting.
ReflectionStage reflectionStage(int seconds, {required bool onDevice}) {
  final steps = onDevice ? _device : _cloud;
  final normal = steps.where((s) => !s.slow).length;
  var current = 0;
  for (var i = 0; i < steps.length; i++) {
    if (seconds >= steps[i].from) current = i;
  }
  final s = steps[current];
  return ReflectionStage(
    index: current < normal ? current : normal - 1,
    total: normal,
    message: s.message,
    slow: s.slow,
  );
}
