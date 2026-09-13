import 'package:original_algorithm/neat/link.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/nnode.dart';
import 'package:original_algorithm/neat/trait.dart';

class Gene {
  late Link link;
  double innovationNum = 0.0;
  // Used to see how much mutation has changed the link
  double mutationNum = 0.0;
  bool expressed = false; // When this is off the Gene is disabled/not-expressed
  bool frozen = false; // When frozen, the linkweight cannot be mutated

  Gene();

  factory Gene.makeFromNodes(
    Neat neat,
    double w,
    NNode iNode,
    NNode oNode,
    bool recurrent,
    double innovationNum,
    double mutationNum,
  ) {
    var gene = Gene()
      ..link = Link.makeFromNodes(neat, w, iNode, oNode, recurrent)
      ..innovationNum = innovationNum
      ..mutationNum = mutationNum
      ..expressed = true
      ..frozen = false;

    return gene;
  }

  factory Gene.makeFromTrait(
    Neat neat,
    Trait? trait,
    double w,
    NNode? iNode,
    NNode? oNode,
    bool recurrent,
    double innovationNum,
    double mutationNum,
  ) {
    var gene = Gene()
      ..link = Link.makeFromTrait(neat, trait, w, iNode, oNode, recurrent)
      ..innovationNum = innovationNum
      ..mutationNum = mutationNum
      ..expressed = true
      ..frozen = false;

    return gene;
  }

  factory Gene.makeFromTraitNonRecurrent(
    Neat neat,
    Trait trait,
    double w,
    NNode iNode,
    NNode oNode,
    double innovation,
    double mutationNum,
  ) {
    return Gene.makeFromTrait(
      neat,
      trait,
      w,
      iNode,
      oNode,
      false,
      innovation,
      mutationNum,
    );
  }

  factory Gene.makeFromTraitRecurrent(
    Neat neat,
    Trait trait,
    double w,
    NNode iNode,
    NNode oNode,
    double innovation,
    double mutationNum,
  ) {
    return Gene.makeFromTrait(
      neat,
      trait,
      w,
      iNode,
      oNode,
      true,
      innovation,
      mutationNum,
    );
  }

  factory Gene.makeFromGene(
    Neat neat,
    Gene gene,
    Trait? trait,
    NNode? iNode,
    NNode? oNode,
  ) {
    var g = Gene()
      ..link = Link.makeFromTrait(
        neat,
        trait,
        gene.link.weight,
        iNode,
        oNode,
        gene.link.isRecurrent,
      )
      ..innovationNum = gene.innovationNum
      ..mutationNum = gene.mutationNum
      ..expressed = gene.expressed
      ..frozen = gene.frozen;

    return g;
  }

  factory Gene.makeCopy(Neat neat, Gene gene) {
    var g = Gene()
      ..link = Link.makeFromLink(neat, gene.link)
      ..innovationNum = gene.innovationNum
      ..mutationNum = gene.mutationNum
      ..expressed = gene.expressed
      ..frozen = gene.frozen;

    return g;
  }

  factory Gene.makeFromLine(
    Neat neat,
    String argLine,
    List<Trait> traits,
    List<NNode> nodes,
  ) {
    // This regex finds all number-like sequences of digits and dots.
    final RegExp numRegExp = RegExp(r'[\d\.]+');
    final matches = numRegExp.allMatches(argLine).map((m) => m[0]!).toList();

    // Expecting 8 numbers after the "gene" keyword.
    if (!argLine.trim().startsWith('gene') || matches.length < 8) {
      // In a real application, throwing a FormatException would be better.
      // For now, we return an empty/default Gene.
      throw FormatException('Invalid gene line: $argLine');
    }

    // Parse all values from the matched strings.
    final int traitNum = int.parse(matches[0]);
    final int iNodeNum = int.parse(matches[1]);
    final int oNodeNum = int.parse(matches[2]);
    final double weight = double.parse(matches[3]);
    final bool isRecurrent = int.parse(matches[4]) == 1;
    final double innovation = double.parse(matches[5]);
    final double mutation = double.parse(matches[6]);
    final bool enabled = int.parse(matches[7]) == 1;

    // Find the corresponding Trait and Nodes from the provided lists.
    Trait? trait;
    if (traitNum != 0) {
      try {
        trait = traits.firstWhere((t) => t.traitId == traitNum);
      } on StateError {
        // No matching trait was found, trait remains null.
        trait = null;
      }
    }

    final NNode iNode = nodes[iNodeNum]; // Assuming nodes are indexed by ID.
    final NNode oNode = nodes[oNodeNum];

    final Gene gene = Gene()
      ..link = Link.makeFromTrait(
        neat,
        trait,
        weight,
        iNode,
        oNode,
        isRecurrent,
      )
      ..innovationNum = innovation
      ..mutationNum = mutation
      ..expressed = enabled
      ..frozen = false;

    // If a trait was found, derive its parameters for the link.
    // gene.link.deriveTrait(neat, trait);   // <== AI add this but it isn't in the original code

    return gene;
  }
}
