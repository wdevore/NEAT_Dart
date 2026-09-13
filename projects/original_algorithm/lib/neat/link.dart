import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/nnode.dart';
import 'package:original_algorithm/neat/trait.dart';

class Link {
  // The genetic sequence
  // DNA is random floating point values between 0 and 1 (!!)
  List<double> genes = [];

  double weight = 0.0; // Weight of connection
  NNode? inNode; // NNode inputting into the link
  NNode? outNode; // NNode that the link affects
  bool isRecurrent = false;
  bool timeDelay = false;

  Trait? linkTrait; // Points to a trait of parameters for genetic creation

  int traitId = -1; // identify the trait derived by this link

  // ************ LEARNING PARAMETERS ***********
  // These are link-related parameters that change during Hebbian type learning
  double addedWeight = 0.0; // The amount of weight adjustment

  late List<double> params;

  Link();

  factory Link.makeFromNodes(
    Neat neat,
    double w,
    NNode? iNode,
    NNode? oNode,
    bool recurrent,
  ) {
    Link link = Link()
      ..weight = w
      ..inNode = iNode
      ..outNode = oNode
      ..isRecurrent = recurrent
      ..addedWeight = 0
      ..timeDelay = false
      ..traitId = 1
      ..params = List.filled(Neat.numTraitParams, 0.0);

    return link;
  }

  factory Link.makeFromTrait(
    Neat neat,
    Trait? lt,
    double w,
    NNode? iNode,
    NNode? oNode,
    bool recurrent,
  ) {
    Link link = Link.makeFromNodes(neat, w, iNode, oNode, recurrent)
      ..linkTrait = lt;

    link.traitId = lt?.traitId ?? 1;

    return link;
  }

  factory Link.makeFromWeight(Neat neat, double w) {
    Link link = Link.makeFromNodes(neat, w, null, null, false);

    return link;
  }

  // Make copy
  factory Link.makeFromLink(Neat neat, Link link) {
    Link lnk = Link.makeFromNodes(
      neat,
      link.weight,
      link.inNode,
      link.outNode,
      link.isRecurrent,
    );

    lnk.addedWeight = link.addedWeight;
    lnk.linkTrait = link.linkTrait;
    lnk.timeDelay = link.timeDelay;
    lnk.traitId = link.traitId;

    return lnk;
  }

  void deriveTrait(Neat neat, Trait? currentTrait) {
    // Only do anything if there is a trait to derive from
    if (currentTrait != null) {
      // If this link already has a trait, its parameters are fixed
      final bool isGrowable = linkTrait == null;
      params = List.of(currentTrait.params, growable: isGrowable);
      traitId = currentTrait.traitId;
    } else {
      params = List.filled(Neat.numTraitParams, 0.0);
      traitId = 1;
    }
  }
}
