import 'package:original_algorithm/neat/neat.dart';

class IteratorList<E, T extends List<E>> {
  final T list;
  int index = 0;
  Neat neat;

  IteratorList(this.neat, this.list, [this.index = 0]);

  /// Current element
  E get current => list[index];

  E get first => list.first;

  int begin() {
    index = 0;
    return index;
  }

  int end() => list.length - 1;

  /// Advance forward
  bool next() {
    if (index < list.length) {
      index++;
      return true;
    }
    return false;
  }

  /// Step backward
  bool prev() {
    if (index > 0) {
      index--;
      return true;
    }
    return false;
  }

  int get length => list.length;

  /// Equivalent to (it == list.end())
  bool get isEnd => index >= list.length;

  bool isIndexAtEnd(int index) {
    return index >= list.length;
  }

  /// Equivalent to (it == list.begin())
  bool get isBegin => index == 0;

  bool get isRevBegin => index < 0;

  E? findIf(bool Function(E element) test) {
    final idx = list.indexWhere(test, index);
    if (idx != -1) {
      index = idx;
      return list[index];
    }
    index = list.length;
    return null;
  }

  /// Searches starting at [start] for an element matching [test]
  int findIfAt(int start, bool Function(E element) test) {
    return list.indexWhere(test, start);
  }

  int reverseFind(bool Function(E element) test, [int? start]) {
    return list.lastIndexWhere(test, start);
  }

  void sort(int Function(E a, E b)? compare) {
    list.sort(compare);
  }
}
