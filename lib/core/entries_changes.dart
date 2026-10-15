import 'package:flutter/foundation.dart';

/// Bumped every time a journal entry is saved, edited or deleted.
/// Home and History listen to it and reload their lists.
final ValueNotifier<int> entriesChanged = ValueNotifier<int>(0);