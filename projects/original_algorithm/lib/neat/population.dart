import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/iterator_species_list.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/species.dart';

class Population {
  late List<Organism> organisms; // The organisms in the Population

  // Species in the Population. Note that the species should comprise all the genomes
  late List<Species> species;

  // ******* Member variables used during reproduction *******
  // For holding the genetic innovations of the newest generation
  late List<Innovation> innovations;
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
      // newGenome.mutate_link_weights(1.0,1.0,Mutator::GAUSSIAN);
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

  bool epoch2(Neat neat, int generation) {
    double total = 0.0; // Used to compute average fitness over all Organisms

    // The average modified fitness among ALL organisms
    double overallAverage = 0.0;

    int orgCount = 0;

    // The fractional parts of expected offspring that can be
    // Used only when they accumulate above 1 for the purposes of counting
    // Offspring
    double skim = 0.0;
    int totalExpected = 0; // precision checking
    int totalOrganisms = organisms.length;
    int maxExpected = 0;
    Species? bestSpecies;
    int finalExpected = 0;

    // int pause = 0;

    // Rights to make babies can be stolen from inferior species
    // and given to their superiors, in order to concentrate exploration on
    // the best species
    // int NUM_STOLEN = neat.babiesStolen; // Number of babies to steal
    int oneFifthStolen = 0;
    int oneTenthStolen = 0;

    // Babies taken from the bad species and given to the champs
    int stolenBabies = 0;

    int halfPop = 0;

    // Used in debugging to see why (if) best species dies
    int bestSpeciesNum = 0;
    bool bestOk = false;

    // We can try to keep the number of species constant at this number
    // int numSpeciesTarget = 4;
    // int numSpecies = species.length;

    // Stick the Species pointers into a new Species list for sorting
    // neat.log("Species in population: ", (int)(species.size()));
    // Species sorted by max fit org in Species
    // List<Species> sortedSpecies = List.of(species); // Shallow copy

    var sortedSpeciesIt = SpeciesIteratorList(neat, List.of(species));

    // Sort the Species by max fitness (Use an extra list to do this)
    // These need to use ORIGINAL fitness
    // sorted_species.qsort(order_species);
    // std::sort(sorted_species.begin(), sorted_species.end(), order_species);
    sortedSpeciesIt.sort(
      (a, b) => a.organisms.first.origFitness.compareTo(
        b.organisms.first.origFitness,
      ),
    );

    // Flag the lowest performing species over age 20 every 30 generations
    // NOTE: THIS IS FOR COMPETITIVE COEVOLUTION STAGNATION DETECTION

    // Find the last species that is not young
    final index = sortedSpeciesIt.reverseFind((spe) => spe.age >= 20);

    // If not found (-1), fallback to the first element (index 0)
    var curSpecies = sortedSpeciesIt.speciesFromIndex(index);

    // neat.log("Found species: ", curSpecies.id);

    if (generation % 30 == 0) curSpecies.obliterate = true;

    // Use Species' ages to modify the objective fitness of organisms
    //  in other words, make it more fair for younger species
    //  so they have a chance to take hold
    // Also penalize stagnant species
    // Then adjust the fitness using the species size to "share" fitness
    // within a species.
    // Then, within each Species, mark for death
    // those below survival_thresh*average
    for (var s in species) {
      s.adjustFitness(neat);
    }

    // Calculate the total fitness of the population and then to assign the
    // expected number of offspring to each organism.

    // Go through the organisms and add up their fitnesses to compute the
    // overall average
    for (var org in organisms) {
      total += org.fitness;
      // neat.logDbl("total ", total, false);
      // neat.logDbl("org fitness ", org.fitness, false);
    }

    overallAverage = total / totalOrganisms;
    // neat.logDbl("total ", total, false);
    // neat.logDbl("total_organisms ", totalOrganisms, false);
    // neat.log("(Generation, overall_average): ", generation, overall_average);

    // Now compute expected number of offspring for each individual organism
    for (var org in organisms) {
      org.expectedOffspring = (org.fitness / overallAverage);
    }

    // Now add those offspring up within each Species to get the number of
    // offspring per Species
    skim = 0.0;
    totalExpected = 0;
    for (var s in species) {
      skim = s.countOffspring(skim);
      // neat.log(
      //   "########### Population::epoch::Species::count_offspring ############, skim:",
      //   skim,
      // );

      totalExpected += s.expectedOffspring;
    }

    // Need to make up for lost foating point precision in offspring assignment
    // If we lost precision, give an extra baby to the best Species
    if (totalExpected < totalOrganisms) {
      // Find the Species expecting the most
      maxExpected = 0;
      finalExpected = 0;

      for (var s in species) {
        if (s.expectedOffspring >= maxExpected) {
          maxExpected = s.expectedOffspring;
          bestSpecies = s;
        }
        finalExpected += s.expectedOffspring;
      }

      // Give the extra offspring to the best species
      if (bestSpecies != null) {
        bestSpecies.expectedOffspring++;
      } else {
        // neat.log("WARNING: Found no Best Species");
      }

      finalExpected++;

      // If we still arent at total, there is a problem
      // Note that this can happen if a stagnant Species
      // dominates the population and then gets killed off by its age
      // Then the whole population plummets in fitness
      // If the average fitness is allowed to hit 0, then we no longer have
      // an average we can use to assign offspring.
      if (finalExpected < totalOrganisms) {
        // neat.log("######## EPOCH Population died! #########");
        for (var s in species) {
          s.expectedOffspring = 0;
        }
        if (bestSpecies != null) bestSpecies.expectedOffspring = totalOrganisms;
      }
    }

    // Sort the Species by max fitness (Use an extra list to do this)
    // These need to use ORIGINAL fitness
    // sorted_species.qsort(order_species);
    sortedSpeciesIt.sort(
      (a, b) => a.organisms.first.origFitness.compareTo(
        b.organisms.first.origFitness,
      ),
    );

    curSpecies = sortedSpeciesIt.first;

    // Because the list is sorted from best to worst then the "first" is the best.
    bestSpeciesNum = curSpecies.id;

    // DEBUG marker of the best of pop
    var firstOrg = curSpecies.organisms.first;
    firstOrg.popChamp = true;

    if (firstOrg.origFitness > highestFitness) {
      highestFitness = firstOrg.origFitness;
      highestLastChanged = 0;
      // neat.log("NEW POPULATION RECORD FITNESS: ", highestFitness);
    } else {
      highestLastChanged++;
      // neat.log("generations since last population fitness record (highest_last_changed, highest_fitness): ", highest_last_changed, highest_fitness);
    }

    // Check for stagnation- if there is stagnation, perform delta-coding
    if (highestLastChanged >= neat.dropoffAge + 5) {
      //    cout<<"PERFORMING DELTA CODING"<<endl;

      highestLastChanged = 0;

      halfPop = (neat.popSize / 2).toInt();

      //    cout<<"halfPop"<<halfPop<<" popSize-halfpop: "<<popSize-halfPop<<endl;
      curSpecies = sortedSpeciesIt.first;

      curSpecies.organisms.first.superChampOffspring = halfPop;
      curSpecies.expectedOffspring = halfPop;
      curSpecies.ageOfLastImprovement = curSpecies.age;

      var end = sortedSpeciesIt.next();

      if (!end) {
        curSpecies = sortedSpeciesIt.current;
        curSpecies.organisms.first.superChampOffspring = neat.popSize - halfPop;
        curSpecies.expectedOffspring = neat.popSize - halfPop;
        curSpecies.ageOfLastImprovement = curSpecies.age;

        end = sortedSpeciesIt.next();

        // Get rid of all species under the first 2
        while (!end) {
          sortedSpeciesIt.current.expectedOffspring = 0;
          end = sortedSpeciesIt.next();
        }
      } else {
        curSpecies = sortedSpeciesIt.first;
        curSpecies.organisms.first.superChampOffspring +=
            neat.popSize - halfPop;
        curSpecies.expectedOffspring = neat.popSize - halfPop;
      }
    }
    // STOLEN BABIES:  The system can take expected offspring away from
    //   worse species and give them to superior species depending on
    //   the system parameter babiesStolen (when babiesStolen > 0)
    else if (neat.babiesStolen > 0) {
      // Take away a constant number of expected offspring from the worst few species
      // In Dart, reducing a growable list's length automatically truncates
      // elements from the end:
      // final int toRemove = neat.babiesStolen.clamp(0, sortedSpecies.length);
      // sortedSpecies.length -= toRemove;

      stolenBabies = 0;
      sortedSpeciesIt.end();

      while (stolenBabies < neat.babiesStolen && !sortedSpeciesIt.isRevBegin) {
        // neat.log(
        //   "Considering Species (id, age): ",
        //   curSpecies.id,
        //   curSpecies.age,
        // );
        // neat.log("Expected offspring ", curSpecies.expectedOffspring);
        if (curSpecies.age > 5 && curSpecies.expectedOffspring > 2) {
          // neat.log("STEALING!");
          // This species has enough to finish off the stolen pool
          if (curSpecies.expectedOffspring - 1 >=
              neat.babiesStolen - stolenBabies) {
            curSpecies.expectedOffspring -= neat.babiesStolen - stolenBabies;
            stolenBabies = neat.babiesStolen;
          }
          // Not enough here to complete the pool of stolen
          else {
            stolenBabies += curSpecies.expectedOffspring - 1;
            curSpecies.expectedOffspring = 1;
          }
        }

        sortedSpeciesIt.prev();

        // if (stolenBabies > 0) {
        //   neat.logValue("stolen babies so far: ", stolenBabies, false);
        // }
      }

      // Determine the exact number that will be given to the top three
      // They get , in order, 1/5 1/5 and 1/10 of the stolen babies
      oneFifthStolen = (neat.babiesStolen / 5).toInt();
      oneTenthStolen = (neat.babiesStolen / 10).toInt();

      // Mark the best champions of the top species to be the super champs
      // who will take on the extra offspring for cloning or mutant cloning
      // Don't give to dying species even if they are champs
      var atIndex = sortedSpeciesIt.findIfAt(
        sortedSpeciesIt.index,
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      // Concentrate A LOT on the number one species
      if (atIndex >= 0) {
        curSpecies = sortedSpeciesIt.speciesFrom(atIndex);

        // Concentrate A LOT on the number one species
        if (stolenBabies >= oneFifthStolen) {
          curSpecies.organisms.first.superChampOffspring = oneFifthStolen;
          curSpecies.expectedOffspring += oneFifthStolen;
          stolenBabies -= oneFifthStolen;
          // neat.log("Gave: (oneFifthStolen, id): ", oneFifthStolen, curSpecies.id);
          // neat.log(
          //   "The best superchamp is: ",
          //   curSpecies.organisms.first.gnome.genomeId,
          // );

          sortedSpeciesIt.next();
        }
      }

      // Don't give to dying species even if they are champs
      var speIndex = sortedSpeciesIt.findIfAt(
        sortedSpeciesIt.index,
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      if (speIndex >= 0) {
        if (stolenBabies >= oneFifthStolen) {
          curSpecies = sortedSpeciesIt.speciesFrom(speIndex);
          curSpecies.organisms.first.superChampOffspring = oneFifthStolen;
          curSpecies.expectedOffspring += oneFifthStolen;
          stolenBabies -= oneFifthStolen;
          // neat.log("Gave: (stolenBabies, id): ", stolenBabies, curSpecies.id);
          sortedSpeciesIt.next();
        }
      }

      // Don't give to dying species even if they are champs
      speIndex = sortedSpeciesIt.findIfAt(
        sortedSpeciesIt.index,
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      if (speIndex >= 0) {
        if (stolenBabies >= oneTenthStolen) {
          curSpecies = sortedSpeciesIt.speciesFrom(speIndex);
          curSpecies.organisms.first.superChampOffspring = oneTenthStolen;
          curSpecies.expectedOffspring += oneTenthStolen;
          stolenBabies -= oneTenthStolen;
          // neat.log("Gave: (stolenBabies, id): ", stolenBabies, curSpecies.id);
          sortedSpeciesIt.next();
        }
      }

      // Don't give to dying species even if they are champs
      speIndex = sortedSpeciesIt.findIfAt(
        sortedSpeciesIt.index,
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      while (stolenBabies > 0 && sortedSpeciesIt.isIndexAtEnd(speIndex)) {
        // Randomize a little which species get boosted by a super champ
        curSpecies = sortedSpeciesIt.speciesFrom(speIndex);

        if (neat.randFloat() > 0.1) {
          if (stolenBabies > 3) {
            curSpecies.organisms.first.superChampOffspring = 3;
            curSpecies.expectedOffspring += 3;
            stolenBabies -= 3;
            // neat.log("Gave 3 babies to Species: ", curSpecies.id);
          } else {
            // cout<<"3 or less babies available"<<endl;
            curSpecies.organisms.first.superChampOffspring = stolenBabies;
            curSpecies.expectedOffspring += stolenBabies;
            // neat.log("Gave: (babies to Species, id): ", stolenBabies, curSpecies.id);
            stolenBabies = 0;
          }
        }

        sortedSpeciesIt.next();

        // Don't give to dying species even if they are champs
        speIndex = sortedSpeciesIt.findIfAt(
          sortedSpeciesIt.index,
          (spe) => spe.lastImproved() <= neat.dropoffAge,
        );
      }

      // cout<<"Done giving back babies"<<endl;

      // If any stolen babies aren't taken, give them to species #1's champ
      if (stolenBabies > 0) {
        // neat.log("Not all given back, giving to best Species");

        curSpecies = sortedSpeciesIt.first;
        curSpecies.organisms.first.superChampOffspring += stolenBabies;
        curSpecies.expectedOffspring += stolenBabies;
        stolenBabies = 0;
      }
    }

    // Kill off all Organisms marked for death.  The remainder
    // will be allowed to reproduce.
    // curorg = organisms.begin();
    // var organismsIt = OrganismsIteratorList(neat, organisms);
    // organismsIt.begin();

    // Kill off all Organisms marked for death. The remainder
    // will be allowed to reproduce.
    organisms.removeWhere((org) {
      if (org.eliminate) {
        org.species.removeOrg(org); // Remove from its Species
        return true; // Removes from organisms master list
      }
      return false; // Keeps it in master list
    });

    // neat.log("Performing reproduction");
    // Perform reproduction.  Reproduction is done on a per-Species
    // basis.  (So this could be paralellized potentially.)
    sortedSpeciesIt.begin();
    int lastId = sortedSpeciesIt.current.id;

    while (!sortedSpeciesIt.isEnd) {
      sortedSpeciesIt.current.reproduce(
        neat,
        generation,
        this,
        sortedSpeciesIt.list,
      );

      // Set the current species to the id of the last species checked
      // (the iterator must be reset because there were possibly vector
      // insertions during reproduce)
      var curspecies2 = species.iterator;
      int index = 0;
      while (curspecies2.moveNext()) {
        if (curspecies2.current.id == lastId) {
          sortedSpeciesIt.index = index;
          index++;
        }
      }

      sortedSpeciesIt.next();

      // Record where we are
      if (!sortedSpeciesIt.isEnd) {
        lastId = sortedSpeciesIt.current.id;
      }
    }

    // neat.log("Reproduction Complete");

    // Destroy and remove the old generation from the organisms and species
    // Loop through organisms collection.
    //    remove organism from organism's species
    //    remove organism from collection
    // ===========================
    // =========================================================================
    // POST-REPRODUCTION: Rebuild master list, remove empty species, age survivors
    // =========================================================================
    orgCount = 0;

    // 1. Clear old generation organisms list (Dart GC handles memory cleanup)
    organisms.clear();

    // 2. Remove all empty Species (extinct species)
    species.removeWhere((s) => s.organisms.isEmpty);

    // 3. Age surviving Species & rebuild the master organisms list for the new generation
    // NUMBER THEM as they are added to the list.
    for (final curSpecies in species) {
      // Age any Species that is not newly created in this generation
      if (curSpecies.novel) {
        curSpecies.novel = false;
      } else {
        curSpecies.age++;
      }

      // Go through the organisms of the curspecies and add them to
      // the master list
      // Rebuild the master organisms list
      for (final curOrg in curSpecies.organisms) {
        curOrg.species = curSpecies;
        curOrg.gnome.genomeId = orgCount++;
        organisms.add(curOrg);
      }
    }

    // DEBUG: Checking the top organism's duplicate in the next gen
    // This prints the champ's child to the screen
    bestOk = false;

    for (final spe in species) {
      if (spe.id == bestSpeciesNum) bestOk = true;
    }

    if (!bestOk) {
      neat.log("ERROR: THE BEST SPECIES DIED!");
    } else {
      neat.logValue("The best survived: ", bestSpeciesNum, false);
    }

    for (final org in organisms) {
      if (org.popChampChild) {
        neat.logValue(
          "At end of reproduction cycle, the child of the pop champ is: ",
          org.gnome.genomeId,
          false,
        );
      }
    }

    if (stolenBabies > 0) {
      neat.logValue("stolenBabies at end: ", stolenBabies, false);
    }

    neat.log("########## Population::epoch END ############");

    return true;
  }

  bool rankWithinSpecies() {
    // Add each Species in this generation to the snapshot
    for (final s in species) {
      s.rank();
    }

    return true;
  }
}
