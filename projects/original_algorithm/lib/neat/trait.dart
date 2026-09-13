import 'package:original_algorithm/neat/neat.dart';

class Trait {
  int traitId = -1; // Used in file saving and loading

  // The parameters that define this trait
  late List<double> params;

  Trait();

  factory Trait.makeCopy(Trait trait) {
    var newTrait = Trait();

    newTrait.traitId = trait.traitId;
    newTrait.params = List.of(trait.params); // Make deep copy

    return newTrait;
  }

  factory Trait.makeFromParams(
    Neat neat,
    int id,
    double p1,
    double p2,
    double p3,
    double p4,
    double p5,
    double p6,
    double p7,
    double p8,
    double p9,
  ) {
    var newTrait = Trait();

    newTrait.traitId = id;

    newTrait.params = [p1, p2, p3, p4, p5, p6, p7, 0];

    return newTrait;
  }

  factory Trait.makeByAverage(Neat neat, Trait t1, Trait t2) {
    var newTrait = Trait();

    newTrait.traitId = t1.traitId;

    // Use List.generate to create the new list and populate it in one step.
    newTrait.params = List.generate(
      t1.params.length,
      (i) => (t1.params[i] + t2.params[i]) / 2.0,
    );

    return newTrait;
  }

  factory Trait.makeFromLine(Neat neat, String argline) {
    // Split the line by one or more whitespace characters.
    final parts = argline.trim().split(RegExp(r'\s+'));

    // Validate the line format. Expect "trait", an ID, and a number of params.
    if (parts.isEmpty ||
        parts[0] != 'trait' ||
        parts.length < 2 + Neat.numTraitParams) {
      throw FormatException('Invalid trait line format: "$argline"');
    }

    final newTrait = Trait();

    // Parse the trait ID from the second part.
    newTrait.traitId = int.parse(parts[1]);

    // Parse the parameters, starting after the "trait" keyword and the ID.
    newTrait.params = parts
        .sublist(2, 2 + Neat.numTraitParams)
        .map(double.parse)
        .toList();

    return newTrait;
  }

  void mutate(Neat neat) {
    for (int count = 0; count < Neat.numTraitParams; count++) {
      if (neat.randFloat() > neat.traitParamMutProb) {
        params[count] +=
            neat.randPosNeg() * neat.randFloat() * neat.traitMutationPower;
        params[count].clamp(0.0, 1.0);
      }
    }
  }
}
