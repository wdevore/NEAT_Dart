import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/iterator_species_list.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/species.dart';

class Population {
  List<Organism> organisms = []; // The organisms in the Population

  // Species in the Population. Note that the species should comprise all the genomes
  List<Species> species = [];

  // ******* Member variables used during reproduction *******
  // For holding the genetic innovations of the newest generation
  List<Innovation> innovations = [];
  int curNodeId = 0; // Current label number available
  double curInnovNum = 0.0;

  int lastSpecies = 0; // The highest species number

  // ******* Fitness Statistics *******
  double meanFitness = 0.0;
  double variance = 0.0;
  double standardDeviation = 0.0;

  // An integer that when above zero tells when the first winner appeared
  int winnerGen = 0;

  // ******* When do we need to delta code? *******
  double highestFitness = 0.0; // Stagnation detector
  int highestLastChanged = 0; // If too high, leads to delta coding

  Population();

  // ================================================
  // Factories
  // ================================================
  // Construct off of a single spawning Genome
  factory Population.makeFromGenome(Neat neat, Genome g, int size) {
    var newPop = Population();

    newPop.winnerGen = 0;
    newPop.highestFitness = 0.0;
    newPop.highestLastChanged = 0;
    newPop.spawn(neat, g, size);

    return newPop;
  }

  factory Population.makeFromWithoutMutation(
    Neat neat,
    Genome g,
    int size,
    double power,
  ) {
    var newPop = Population();

    newPop.winnerGen = 0;
    newPop.highestFitness = 0.0;
    newPop.highestLastChanged = 0;
    newPop.clone(neat, g, size, power);

    return newPop;
  }

  bool clone(Neat neat, Genome g, int size, double power) {
    // neat.log("Population::clone START ");
    int count;
    Genome newGenome;
    Organism newOrganism;

    // neat.log("(size, power): ", size, power);

    newGenome = g.duplicate(neat, 1);
    newOrganism = Organism.makeFromGenome(neat, 0.0, newGenome, 1);
    organisms.add(newOrganism);
    // neat.log("Added organism to population: ", (int)organisms.size());

    // Create size copies of the Genome
    // Start with perturbed linkweights
    for (count = 2; count <= size; count++) {
      // neat.log("CREATING ORGANISM count: ", count);
      newGenome = g.duplicate(neat, count);
      if (power > 0) {
        newGenome.mutateLinkWeights(neat, power, 1.0, Mutator.gaussian);
      }

      newGenome.randomizeTraits(neat);
      newOrganism = Organism.makeFromGenome(neat, 0.0, newGenome, 1);
      organisms.add(newOrganism);
      // neat.log("Rand Trait=>Added organism to population: ", (int)organisms.size());
    }

    if (organisms.isNotEmpty) {
      // Keep a record of the innovation and node number we are on
      curNodeId = newGenome.getLastNodeId();
      curInnovNum = newGenome.getLastGeneInnovnum();
    }

    // Separate the new Population into species
    speciate(neat);

    // neat.log("Population::clone END ");

    return true;
  }

  // A Population can be spawned off of a single Genome
  // There will be size Genomes added to the Population
  // The Population does not have to be empty to add Genomes
  bool spawn(Neat neat, Genome g, int size) {
    // neat.log("Population::spawn START ");

    Genome newGenome;
    Organism newOrganism;

    // Create 'size' copies of the Genome
    // Start with perturbed link weights
    for (int id = 1; id <= size; id++) {
      // neat.log("CREATING ORGANISM count: ", id);

      newGenome = g.duplicate(neat, id);
      newGenome.mutateLinkWeights(neat, 1.0, 1.0, Mutator.coldgaussian);
      newGenome.randomizeTraits(neat);

      newOrganism = Organism.makeFromGenome(neat, 0.0, newGenome, 1);
      organisms.add(newOrganism);
    }

    // Only update innovation numbers if new organisms were actually created
    if (organisms.isNotEmpty) {
      // Keep a record of the innovation and node number we are on
      var lastOrganism = organisms.last;
      curNodeId = lastOrganism.gnome.getLastNodeId();
      curInnovNum = lastOrganism.gnome.getLastGeneInnovnum();
    }

    // Separate the new Population into species
    speciate(neat);

    // neat.log("Population::spawn END ");

    return true;
  }

  bool speciate(Neat neat) {
    var speciesIt = SpeciesIteratorList(neat, species);
    // int curspecies = 0;
    Organism? compOrg; // Organism for comparison
    int speciesCounter = 0;

    // Step through all existing organisms
    for (var curOrg in organisms) {
      // For each organism, search for a species it is compatible to
      speciesIt.begin();

      if (speciesIt.isEnd) {
        final newSpecies = Species.makeFromID(++speciesCounter);
        species.add(newSpecies);
        newSpecies.addOrganism(neat, curOrg);
        // neat.log("Adding organism to Species: ", (int)species.size());
        curOrg.species = newSpecies;
      } else {
        compOrg = speciesIt.firstOrganism;

        while (compOrg != null && !speciesIt.isEnd) {
          final double distance = curOrg.gnome.compatibility(
            neat,
            compOrg.gnome,
          );

          if (distance < neat.compatThreshold) {
            // Found compatible species
            speciesIt.current.addOrganism(neat, curOrg);
            // Point organism to its species
            curOrg.species = speciesIt.current;
            compOrg = null; // Note the search is over
          } else {
            // Keep searching for a matching species
            speciesIt.next();

            if (!speciesIt.isEnd) compOrg = speciesIt.current.first();
          }
        }

        // If we didn't find a match, create a new species
        if (compOrg != null) {
          final newSpecies = Species.makeFromID(++speciesCounter);
          species.add(newSpecies);
          newSpecies.addOrganism(neat, curOrg);
          curOrg.species = newSpecies;
        }
      }
    }

    lastSpecies = speciesCounter; // Keep track of highest species
    // neat.log("Population::speciate END ");

    return true;
  }

  bool verify() {
    bool verification = false;

    for (var curorg in organisms) {
      verification = curorg.gnome.verify();
    }

    return verification;
  }

  bool epoch(Neat neat, int generation) {
    neat.log("########## Population::epoch START ############");

    // Phase 1: Flag stagnant species & adjust fitness within all species
    _adjustAllSpeciesFitness(neat, generation);

    // Phase 2: Compute average fitness and assign expected offspring per species
    _assignExpectedOffspring(neat);

    // Sort species from highest to lowest performing (by champ's original fitness)
    final sortedSpecies = List.of(species)
      ..sort(
        (a, b) => b.organisms.first.origFitness.compareTo(
          a.organisms.first.origFitness,
        ),
      );

    final bestSpeciesNum = sortedSpecies.first.id;

    // Phase 3 & 4: Check for stagnation (Delta Coding) OR distribute Stolen Babies
    final bool deltaCoded = _checkStagnationAndDeltaCode(neat, sortedSpecies);
    if (!deltaCoded && neat.babiesStolen > 0) {
      _distributeStolenBabies(neat, sortedSpecies);
    }

    // Phase 5: Kill off marked organisms and reproduce each species
    _eliminateWeakOrganisms();
    _reproduceAllSpecies(neat, generation, sortedSpecies);

    // Phase 6: Post-reproduction cleanup, remove extinct species, age survivors, rebuild list
    _postReproductionCleanup(neat, bestSpeciesNum);

    neat.log("########## Population::epoch END ############");
    return true;
  }

  void _adjustAllSpeciesFitness(Neat neat, int generation) {
    // Flag lowest performing older species for obliteration every 30 gens (coevolution)
    if (generation % 30 == 0) {
      final oldSpecies = species.where((s) => s.age >= 20).toList()
        ..sort(
          (a, b) => a.computeMaxFitness().compareTo(b.computeMaxFitness()),
        );
      if (oldSpecies.isNotEmpty) {
        oldSpecies.first.obliterate = true;
      }
    }

    // Adjust fitness (fitness sharing, niching boost, mark weak for death)
    for (final s in species) {
      s.adjustFitness(neat);
    }
  }

  // Phase 2: Compute Offspring Allocation
  void _assignExpectedOffspring(Neat neat) {
    final double totalFitness = organisms.fold(
      0.0,
      (sum, org) => sum + org.fitness,
    );
    final double overallAverage = totalFitness / organisms.length;

    // Assign individual expected offspring
    for (final org in organisms) {
      org.expectedOffspring = (overallAverage > 0)
          ? (org.fitness / overallAverage)
          : 0.0;
    }

    // Tally offspring per species
    double skim = 0.0;
    int totalExpected = 0;
    for (final s in species) {
      skim = s.countOffspring(skim);
      totalExpected += s.expectedOffspring;
    }

    // Precision check: give missing floating-point remainder babies to the best species
    if (totalExpected < organisms.length && species.isNotEmpty) {
      final best = species.reduce(
        (a, b) => a.expectedOffspring >= b.expectedOffspring ? a : b,
      );
      best.expectedOffspring += (organisms.length - totalExpected);
    }
  }

  // Phase 3: Stagnation & Delta-Coding
  bool _checkStagnationAndDeltaCode(Neat neat, List<Species> sortedSpecies) {
    final popChamp = sortedSpecies.first.organisms.first;
    popChamp.popChamp = true;

    // Track fitness records
    if (popChamp.origFitness > highestFitness) {
      highestFitness = popChamp.origFitness;
      highestLastChanged = 0;
    } else {
      highestLastChanged++;
    }

    // Delta coding if stagnant
    if (highestLastChanged >= neat.dropoffAge + 5) {
      highestLastChanged = 0;
      final int halfPop = (neat.popSize / 2).toInt();

      // Give half to top species, half to 2nd species
      final best = sortedSpecies.first;
      best.organisms.first.superChampOffspring = halfPop;
      best.expectedOffspring = halfPop;
      best.ageOfLastImprovement = best.age;

      if (sortedSpecies.length > 1) {
        final second = sortedSpecies[1];
        second.organisms.first.superChampOffspring = neat.popSize - halfPop;
        second.expectedOffspring = neat.popSize - halfPop;
        second.ageOfLastImprovement = second.age;

        // Zero out remaining species
        for (int i = 2; i < sortedSpecies.length; i++) {
          sortedSpecies[i].expectedOffspring = 0;
        }
      } else {
        best.organisms.first.superChampOffspring = neat.popSize;
        best.expectedOffspring = neat.popSize;
      }
      return true;
    }
    return false;
  }

  // Phase 4: Distribute Stolen Babies
  void _distributeStolenBabies(Neat neat, List<Species> sortedSpecies) {
    int stolen = 0;

    // Steal from worst/older species at the end of sorted list
    for (
      int i = sortedSpecies.length - 1;
      i >= 0 && stolen < neat.babiesStolen;
      i--
    ) {
      final s = sortedSpecies[i];
      if (s.age > 5 && s.expectedOffspring > 2) {
        final int needed = neat.babiesStolen - stolen;
        final int available = s.expectedOffspring - 1;
        final int toTake = available >= needed ? needed : available;

        s.expectedOffspring -= toTake;
        stolen += toTake;
      }
    }

    final int oneFifth = (neat.babiesStolen / 5).toInt();
    final int oneTenth = (neat.babiesStolen / 10).toInt();

    // Eligible candidates (not dying)
    final eligible = sortedSpecies
        .where((s) => s.lastImproved() <= neat.dropoffAge)
        .toList();

    // 1st superchamp gets 1/5
    if (eligible.isNotEmpty && stolen >= oneFifth) {
      eligible[0].organisms.first.superChampOffspring = oneFifth;
      eligible[0].expectedOffspring += oneFifth;
      stolen -= oneFifth;
    }

    // 2nd superchamp gets 1/5
    if (eligible.length > 1 && stolen >= oneFifth) {
      eligible[1].organisms.first.superChampOffspring = oneFifth;
      eligible[1].expectedOffspring += oneFifth;
      stolen -= oneFifth;
    }

    // 3rd superchamp gets 1/10
    if (eligible.length > 2 && stolen >= oneTenth) {
      eligible[2].organisms.first.superChampOffspring = oneTenth;
      eligible[2].expectedOffspring += oneTenth;
      stolen -= oneTenth;
    }

    // Distribute any remaining stolen babies to eligible species
    int idx = 0;
    while (stolen > 0 && idx < eligible.length) {
      final s = eligible[idx];
      if (neat.randFloat() > 0.1) {
        final int give = stolen > 3 ? 3 : stolen;
        s.organisms.first.superChampOffspring += give;
        s.expectedOffspring += give;
        stolen -= give;
      }
      idx++;
    }

    // Leftovers go to #1 best species
    if (stolen > 0 && sortedSpecies.isNotEmpty) {
      sortedSpecies.first.organisms.first.superChampOffspring += stolen;
      sortedSpecies.first.expectedOffspring += stolen;
    }
  }

  // Phase 5: Elimination & Reproduction
  void _eliminateWeakOrganisms() {
    organisms.removeWhere((org) {
      if (org.eliminate) {
        org.species.removeOrg(org);
        return true;
      }
      return false;
    });
  }

  void _reproduceAllSpecies(
    Neat neat,
    int generation,
    List<Species> sortedSpecies,
  ) {
    for (final s in sortedSpecies) {
      s.reproduce(neat, generation, this, sortedSpecies);
    }
  }

  // Phase 6: Post-Reproduction Maintenance
  void _postReproductionCleanup(Neat neat, int bestSpeciesNum) {
    organisms.clear();
    species.removeWhere((s) => s.organisms.isEmpty);

    int orgCount = 0;
    for (final s in species) {
      if (s.novel) {
        s.novel = false;
      } else {
        s.age++;
      }

      for (final org in s.organisms) {
        org.species = s;
        org.gnome.genomeId = orgCount++;
        organisms.add(org);
      }
    }

    // Verify best species survived
    final bool bestSurvived = species.any((s) => s.id == bestSpeciesNum);
    if (!bestSurvived) {
      neat.log("ERROR: THE BEST SPECIES DIED!");
    }
  }

  bool rankWithinSpecies() {
    // Add each Species in this generation to the snapshot
    for (final s in species) {
      s.rank();
    }

    return true;
  }
}
