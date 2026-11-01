import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/entry_selection.dart';

void main() {
  group('EntrySelection (History batch select)', () {
    test('starts empty and inactive', () {
      final s = EntrySelection();
      expect(s.isActive, isFalse);
      expect(s.count, 0);
    });

    test('toggle ticks and unticks an entry', () {
      final s = EntrySelection()..toggle(4);
      expect(s.isActive, isTrue);
      expect(s.contains(4), isTrue);
      s.toggle(4);
      expect(s.contains(4), isFalse);
      expect(s.isActive, isFalse);
    });

    test('select all ticks every visible entry', () {
      final s = EntrySelection()..selectAll([1, 2, 3]);
      expect(s.count, 3);
      expect(s.allSelected([1, 2, 3]), isTrue);
      expect(s.allSelected([1, 2, 3, 4]), isFalse);
    });

    test('allSelected is false for an empty list', () {
      expect(EntrySelection().allSelected([]), isFalse);
    });

    test('clear removes all ticks', () {
      final s = EntrySelection()..selectAll([1, 2]);
      s.clear();
      expect(s.isActive, isFalse);
    });

    test('keepOnly drops entries that left the list', () {
      final s = EntrySelection()..selectAll([1, 2, 3]);
      s.keepOnly([2, 3, 9]);
      expect(s.ids, {2, 3});
    });

    test('ids cannot be changed from outside', () {
      final s = EntrySelection()..toggle(1);
      expect(() => s.ids.add(2), throwsUnsupportedError);
    });
  });
}
