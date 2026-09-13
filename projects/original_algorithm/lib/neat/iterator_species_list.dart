import 'package:collection/collection.dart';
import 'package:original_algorithm/neat/iterator_list.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/species.dart';

class SpeciesIteratorList extends IteratorList<Species, List<Species>> {
  // Uses Dart super-parameter syntax:
  SpeciesIteratorList(super.neat, super.list, [super.index = 0]);

  Organism? get firstOrganism {
    if (list.first.organisms.isEmpty) return null;
    return list.first.organisms.first;
  }

  Species speciesFrom(int index) {
    return list[index];
  }

  Species speciesFromIndex(int index) {
    return (index == -1) ? list.first : speciesFrom(index);
  }

  Species? findIfSpecies() {
    var spe = list.firstWhereOrNull(
      (spe) => spe.lastImproved() <= neat.dropoffAge,
    );
    return spe;
  }

  // You can add any Species-specific helpers here if needed:
  // e.g.
  // bool findNotDying(int dropoffAge) =>
  //     findIf((spe) => spe.lastImproved() <= dropoffAge);
}
