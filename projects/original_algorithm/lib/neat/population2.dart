import 'package:collection/collection.dart';
import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/iterator_species_list.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/species.dart';

class Population2 {
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

  Population2();

  // ================================================
  // Factories
  // ================================================
  // Construct off of a single spawning Genome
  factory Population2.makeFromGenome(Neat neat, Genome g, int size) {
    var newPop = Population2();

    newPop.winnerGen = 0;
    newPop.highestFitness = 0.0;
    newPop.highestLastChanged = 0;
    newPop.spawn(neat, g, size);

    return newPop;
  }

  factory Population2.makeFromWithoutMutation(
    Neat neat,
    Genome g,
    int size,
    double power,
  ) {
    var newPop = Population2();

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

  bool speciate2(Neat neat) {
    // neat.log("Population::speciate START OrgSize: ", (int)organisms.size());

    int curspeciesIndex = 0; // Steps through species
    int curspeciesEndIndex = species.length;
    Organism? comporg; // Organism for comparison
    Species newspecies; // For adding a new species

    int counter = 0; // Species counter
    curspeciesIndex = 0;

    // Step through all existing organisms
    for (var curOrg in organisms) {
      // For each organism, search for a species it is compatible to

      if (species.isEmpty) {
        // Create the first species
        newspecies = Species.makeFromID(++counter);
        species.add(newspecies);
        newspecies.addOrganism(neat, curOrg); // Add the current organism
        // neat.log("Adding organism to Species: ", (int)species.size());
        curOrg.species = newspecies; // Point organism to its species
      } else {
        comporg = species[curspeciesIndex].first();
        while (comporg != null && curspeciesIndex != curspeciesEndIndex) {
          if (curOrg.gnome.compatibility(neat, comporg.gnome) <
              neat.compatThreshold) {
            // Found compatible species, so add this organism to it
            species[curspeciesIndex].addOrganism(neat, curOrg);
            // Point organism to its species
            curOrg.species = species[curspeciesIndex];
            comporg = null; // Note the search is over
          } else {
            // Keep searching for a matching species
            ++curspeciesIndex;
            if (curspeciesIndex != curspeciesEndIndex) {
              comporg = species[curspeciesIndex].first();
            }
          }
        }

        // If we didn't find a match, create a new species
        if (comporg != null) {
          newspecies = Species.makeFromID(++counter);
          species.add(newspecies);
          newspecies.addOrganism(neat, curOrg); // Add the current organism
          curOrg.species = newspecies; // Point organism to its species
        }
      }
    }

    lastSpecies = counter; // Keep track of highest species

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

    int pause = 0;

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
    int numSpeciesTarget = 4;
    int numSpecies = species.length;
    // ============================

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

    if ((generation % 30) == 0) curSpecies.obliterate = true;

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

    // ===========================
    return true;
  }

  bool epoch2(Neat neat, int generation) {
    Species curSpecies;
    int curSpeciesIndex = 0;
    int curSpeciesEndIndex = 0;

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

    int pause;

    // Rights to make babies can be stolen from inferior species
    // and given to their superiors, in order to concentrate exploration on
    // the best species
    int NUM_STOLEN = neat.babiesStolen; // Number of babies to steal
    int oneFifthStolen = 0;
    int oneTenthStolen = 0;

    // Species sorted by max fit org in Species
    List<Species> sortedSpecies = [];
    // Babies taken from the bad species and given to the champs
    int stolenBabies = 0;

    int halfPop = 0;

    // Used in debugging to see why (if) best species dies
    int bestSpeciesNum = 0;
    bool bestOk = false;

    // We can try to keep the number of species constant at this number
    int numSpeciesTarget = 4;
    int numSpecies = species.length;

    // Stick the Species pointers into a new Species list for sorting
    // neat.log("Species in population: ", (int)(species.size()));

    sortedSpecies = List.of(species);
    // for (var s in species) {
    //   sortedSpecies.add(s);
    // }

    // Sort the Species by max fitness (Use an extra list to do this)
    // These need to use ORIGINAL fitness
    // sorted_species.qsort(order_species);
    // std::sort(sorted_species.begin(), sorted_species.end(), order_species);
    sortedSpecies.sort(
      (a, b) => a.organisms.first.origFitness.compareTo(
        b.organisms.first.origFitness,
      ),
    );
    curSpeciesEndIndex = sortedSpecies.length - 1;

    // Flag the lowest performing species over age 20 every 30 generations
    // NOTE: THIS IS FOR COMPETITIVE COEVOLUTION STAGNATION DETECTION

    // Find the last species that is not young
    // for (var r = sortedSpecies.length - 1; r >= 0; r--) {
    //   // Index version:
    //   int curSpeciesIndex = (r < 0) ? 0 : r;
    //   curSpecies = sortedSpecies[curSpeciesIndex];
    // }
    final index = sortedSpecies.lastIndexWhere((spe) => spe.age >= 20);

    // If not found (-1), fallback to the first element (index 0)
    curSpecies = (index == -1) ? sortedSpecies.first : sortedSpecies[index];

    // neat.log("Found species: ", (*it).id);

    if ((generation % 30) == 0) curSpecies.obliterate = true;

    // neat.logValue("Number of Species: ", numSpecies, true);

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
        neat.log("WARNING: Found no Best Species");
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
        // cin>>pause;
        for (var s in species) {
          s.expectedOffspring = 0;
        }
        if (bestSpecies != null) bestSpecies.expectedOffspring = totalOrganisms;
      }
    }
    // Sort the Species by max fitness (Use an extra list to do this)
    // These need to use ORIGINAL fitness
    // sorted_species.qsort(order_species);
    sortedSpecies.sort(
      (a, b) => a.organisms.first.origFitness.compareTo(
        b.organisms.first.origFitness,
      ),
    );

    bestSpeciesNum = sortedSpecies.first.id;

    // for (var s in sortedSpecies) {
    //   // Print out for Debugging/viewing what's going on
    //   neat.log("(Species, Organisms): ", s.id, s.organisms.length);
    //   neat.log(
    //     "(Fitness, last improved): ",
    //     s.organisms.first.origFitness,
    //     (s.age - s.ageOfLastImprovement),
    //   );
    //   neat.log("(Age, Avg Fitness): ", s.age, s.aveFitness);
    // }

    // Check for Population-level stagnation
    curSpecies = sortedSpecies[curSpeciesIndex];

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
      curSpecies = sortedSpecies.first;

      curSpecies.organisms.first.superChampOffspring = halfPop;
      curSpecies.expectedOffspring = halfPop;
      curSpecies.ageOfLastImprovement = curSpecies.age;

      curSpeciesIndex++;

      if (curSpeciesIndex != curSpeciesEndIndex) {
        curSpecies = sortedSpecies[curSpeciesIndex];
        curSpecies.organisms.first.superChampOffspring = neat.popSize - halfPop;
        curSpecies.expectedOffspring = neat.popSize - halfPop;
        curSpecies.ageOfLastImprovement = curSpecies.age;

        curSpeciesIndex++;

        // Get rid of all species under the first 2
        while (curSpeciesIndex != curSpeciesEndIndex) {
          curSpecies = sortedSpecies[curSpeciesIndex];
          curSpecies.expectedOffspring = 0;

          curSpeciesIndex++;
        }
      } else {
        curSpecies = sortedSpecies.first;
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
      // curspecies = sortedSpecies.end();
      // curspecies--;

      curSpeciesIndex = sortedSpecies.length - 1;
      curSpeciesEndIndex = 0;
      while (stolenBabies < NUM_STOLEN &&
          curSpeciesIndex != curSpeciesEndIndex) {
        curSpecies = sortedSpecies[curSpeciesIndex];
        // neat.log(
        //   "Considering Species (id, age): ",
        //   curSpecies.id,
        //   curSpecies.age,
        // );
        // neat.log("Expected offspring ", curSpecies.expectedOffspring);
        if (curSpecies.age > 5 && curSpecies.expectedOffspring > 2) {
          // neat.log("STEALING!");

          // This species has enough to finish off the stolen pool
          if (curSpecies.expectedOffspring - 1 >= NUM_STOLEN - stolenBabies) {
            curSpecies.expectedOffspring -= NUM_STOLEN - stolenBabies;
            stolenBabies = NUM_STOLEN;
          }
          // Not enough here to complete the pool of stolen
          else {
            stolenBabies += curSpecies.expectedOffspring - 1;
            curSpecies.expectedOffspring = 1;
          }
        }

        curSpeciesIndex--;

        // if (stolenBabies > 0) {
        //   neat.logValue("stolen babies so far: ", stolenBabies, false);
        // }
      }

      // cout<<"STOLEN BABIES: "<<stolenBabies<<endl;

      // Mark the best champions of the top species to be the super champs
      // who will take on the extra offspring for cloning or mutant cloning
      curSpecies = sortedSpecies.first;

      // Determine the exact number that will be given to the top three
      // They get , in order, 1/5 1/5 and 1/10 of the stolen babies
      oneFifthStolen = (neat.babiesStolen / 5).toInt();
      oneTenthStolen = (neat.babiesStolen / 10).toInt();

      // Don't give to dying species even if they are champs
      var curSpe = sortedSpecies.firstWhereOrNull(
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      // Concentrate A LOT on the number one species
      if (stolenBabies >= oneFifthStolen && curSpe != null) {
        curSpecies = curSpe;

        curSpecies.organisms.first.superChampOffspring = oneFifthStolen;
        curSpecies.expectedOffspring += oneFifthStolen;
        stolenBabies -= oneFifthStolen;
        // neat.log("Gave: (oneFifthStolen, id): ", oneFifthStolen, curSpecies.id);
        // neat.log(
        //   "The best superchamp is: ",
        //   curSpecies.organisms.first.gnome.genomeId,
        // );

        // Print this champ to file "champ" for observation if desired
        // IMPORTANT:  This causes generational file output
        // print_Genome_tofile((*((curSpecies.organisms).begin()))->gnome,"champ");

        // curspecies++;
      }

      // Don't give to dying species even if they are champs
      curSpe = sortedSpecies.firstWhereOrNull(
        (spe) => spe.lastImproved() <= neat.dropoffAge,
      );

      if (curSpe != null) {
        curSpecies = curSpe;

        if (stolenBabies >= oneFifthStolen) {
          curSpecies.organisms.first.superChampOffspring = oneFifthStolen;
          curSpecies.expectedOffspring += oneFifthStolen;
          stolenBabies -= oneFifthStolen;
          // neat.log("Gave: (stolenBabies, id): ", stolenBabies, curSpecies.id);
          // curspecies++;
        }
      }
    }
    return true;
  }
}
