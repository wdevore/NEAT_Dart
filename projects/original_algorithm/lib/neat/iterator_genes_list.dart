import 'package:original_algorithm/neat/gene.dart';
import 'package:original_algorithm/neat/iterator_list.dart';

class GenesIteratorList extends IteratorList<Gene, List<Gene>> {
  // Uses Dart super-parameter syntax:
  GenesIteratorList(super.neat, super.list, [super.index = 0]);

  // You can add any Species-specific helpers here if needed:
  // e.g.
  // bool findNotDying(int dropoffAge) =>
  //     findIf((spe) => spe.lastImproved() <= dropoffAge);
}
