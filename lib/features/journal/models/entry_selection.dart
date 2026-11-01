/// Which History entries are ticked in "select" mode (batch operations).
/// Pure logic, so it can be unit tested without a screen.
class EntrySelection {
  final Set<int> _ids = {};

  bool get isActive => _ids.isNotEmpty;
  int get count => _ids.length;
  Set<int> get ids => Set.unmodifiable(_ids);

  bool contains(int id) => _ids.contains(id);

  /// Ticks the entry, or unticks it if it was ticked.
  void toggle(int id) {
    if (!_ids.remove(id)) _ids.add(id);
  }

  /// Ticks every entry in [visibleIds].
  void selectAll(Iterable<int> visibleIds) => _ids.addAll(visibleIds);

  /// True when every visible entry is ticked.
  bool allSelected(Iterable<int> visibleIds) {
    final v = visibleIds.toSet();
    return v.isNotEmpty && _ids.containsAll(v);
  }

  void clear() => _ids.clear();

  /// Drops ticks for entries that are no longer in the list (after a filter or delete).
  void keepOnly(Iterable<int> visibleIds) =>
      _ids.retainAll(visibleIds.toSet());
}
