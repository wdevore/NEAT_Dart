import 'package:original_algorithm/neat/iterator_list.dart';
import 'package:original_algorithm/neat/organism.dart';

class OrganismsIteratorList extends IteratorList<Organism, List<Organism>> {
  // Uses Dart super-parameter syntax:
  OrganismsIteratorList(super.neat, super.list, [super.index = 0]);

  // You can add any Species-specific helpers here if needed:
  // e.g.
  // bool findNotDying(int dropoffAge) =>
  //     findIf((spe) => spe.lastImproved() <= dropoffAge);
}
