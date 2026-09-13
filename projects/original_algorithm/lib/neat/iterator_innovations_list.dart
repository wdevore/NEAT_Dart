import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/iterator_list.dart';

class InnovationsIteratorList
    extends IteratorList<Innovation, List<Innovation>> {
  // Uses Dart super-parameter syntax:
  InnovationsIteratorList(super.neat, super.list, [super.index = 0]);

  // You can add any Species-specific helpers here if needed:
  // e.g.
  // bool findNotDying(int dropoffAge) =>
  //     findIf((spe) => spe.lastImproved() <= dropoffAge);
}
