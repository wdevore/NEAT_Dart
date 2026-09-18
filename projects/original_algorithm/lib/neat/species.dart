import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/population.dart';

class Species {
  int id = 0;
  int age = 0; // The age of the Species
  double aveFitness = 0.0; // The average fitness of the Species
  double maxFitness = 0.0; // Max fitness of the Species
  double maxFitnessEver = 0.0; // The max it ever had
  int expectedOffspring = 0;
  bool novel = false;
  bool checked = false;
  bool obliterate =
      false; // Allows killing off in competitive coevolution stagnation
  List<Organism> organisms = []; // The organisms in the Species
  // std::vector<Organism*> reproduction_pool;  //The organisms for reproduction- NOT NEEDED
  // If this is too long ago, the Species will goes extinct
  int ageOfLastImprovement = 0;
  // When playing real-time allows estimating average fitness
  double averageEst = 0.0;

  Species();

  factory Species.makeFromID(int id) {
    var newSpecies = Species();

    newSpecies.id = id;
    newSpecies.age = 1;
    newSpecies.aveFitness = 0.0;
    newSpecies.expectedOffspring = 0;
    newSpecies.novel = false;
    newSpecies.ageOfLastImprovement = 0;
    newSpecies.maxFitness = 0;
    newSpecies.maxFitnessEver = 0;
    newSpecies.obliterate = false;

    newSpecies.averageEst = 0;

    return newSpecies;
  }

  factory Species.makeFromNovel(int id, bool novel) {
    var newSpecies = Species();

    newSpecies.id = id;
    newSpecies.age = 1;
    newSpecies.aveFitness = 0.0;
    newSpecies.expectedOffspring = 0;
    newSpecies.novel = novel;
    newSpecies.ageOfLastImprovement = 0;
    newSpecies.maxFitness = 0;
    newSpecies.maxFitnessEver = 0;
    newSpecies.obliterate = false;

    newSpecies.averageEst = 0;

    return newSpecies;
  }

  bool addOrganism(Neat neat, Organism o) {
    organisms.add(o);
    // neat.log("Species::addOIanism: ", (int)organisms.size());

    return true;
  }

  Organism first() {
    return organisms.first;
  }

  void adjustFitness(Neat neat) {
    // neat.log("########## Species::adjust_fitness ############");
    // neat.log("organisms count: ", (int)organisms.size());
    // neat.log("Species (id, last improved): ", id, (age - ageOIlast_improvement));
    // neat.log("steps ago when it moved up to: ", max_fitness_ever);

    int ageDebt = (age - ageOfLastImprovement + 1) - neat.dropoffAge;

    if (ageDebt == 0) ageDebt = 1;

    for (var curOrg in organisms) {
      // Remember the original fitness before it gets modified
      curOrg.origFitness = curOrg.fitness;

      // Make fitness decrease after a stagnation point dropoff_age
      // Added an if to keep species pristine until the dropoff point
      // obliterate is used in competitive coevolution to mark stagnation
      // by obliterating the worst species over a certain age
      if ((ageDebt >= 1) || obliterate) {
        // Possible graded dropoff
        //(curorg.fitness)=(curorg.fitness)*(-atan(age_debt));

        // Extreme penalty for a long period of stagnation (divide fitness by 100)
        curOrg.fitness = curOrg.fitness * 0.01;
        // neat.log("OBLITERATE Species (id,age): ", id, age);
        // neat.log("dropped fitness to ", (curorg.fitness));
      }

      // Give a fitness boost up to some young age (niching)
      // The age_significance parameter is a system parameter
      //   if it is 1, then young species get no fitness boost
      if (age <= 10) curOrg.fitness = curOrg.fitness * neat.ageSignificance;

      // neat.log("Checking fitness: ", curOrg.fitness);
      // Do not allow negative fitness
      if (curOrg.fitness < 0.0) curOrg.fitness = 0.0001;

      // Share fitness with the species
      curOrg.fitness = curOrg.fitness / organisms.length;
      // neat.log("Sharing fitness: ", curOrg.fitness);
    }

    // Sort the population and mark for death those after survival_thresh*pop_size
    // organisms.qsort(orderOIs);
    organisms.sort((a, b) => a.fitness.compareTo(b.fitness));

    // Update ageOIlast_improvement here
    var begin = organisms.first;
    if (begin.origFitness > maxFitnessEver) {
      ageOfLastImprovement = age;
      maxFitnessEver = begin.origFitness;
    }

    // Decide how many get to reproduce based on survival_thresh * pop_size
    // Adding 1.0 ensures that at least one will survive
    int numParents = (neat.survivalThresh * organisms.length + 1.0).floor();

    // Mark for death those who are ranked too low to be parents
    if (organisms.isNotEmpty) {
      organisms.first.champion = true; // Mark the champ as such

      for (var i = numParents; i < organisms.length; ++i) {
        organisms[i].eliminate = true; // Mark for elimination
      }
    }
  }

  double computeAverageFitness() {
    if (organisms.isEmpty) {
      aveFitness = 0.0;
    } else {
      double total = 0.0;

      for (var curOrg in organisms) {
        total += curOrg.fitness;
      }
      aveFitness = total / organisms.length;
    }

    return aveFitness;
  }

  double computeMaxFitness() {
    double max = 0.0;

    for (var curOrg in organisms) {
      if ((curOrg.fitness) > max) max = curOrg.fitness;
    }

    maxFitness = max;

    return max;
  }

  double countOffspring(double skim) {
    int eOIntpart; // The floor of an organism's expected offspring
    double eOIracpart; // Expected offspring fractional part
    double skimIntpart; // The whole offspring in the skim

    expectedOffspring = 0;

    for (var curOrg in organisms) {
      eOIntpart = curOrg.expectedOffspring.floor();
      eOIracpart = curOrg.expectedOffspring.remainder(1.0);

      expectedOffspring += eOIntpart;

      // Skim off the fractional offspring
      skim += eOIracpart;

      // NOTE:  Some precision is lost by computer
      //        Must be remedied later
      if (skim > 1.0) {
        skimIntpart = skim.floorToDouble();
        expectedOffspring += skimIntpart.toInt();
        skim -= skimIntpart;
      }
    }

    return skim;
  }

  // Compute generations since last improvement
  int lastImproved() {
    return age - ageOfLastImprovement;
  }

  bool removeOrg(Organism org) {
    if (organisms.isEmpty) {
      // std::cout << "ALERT: Attempt to remove nonexistent Organism from Species" << std::endl;
      return false;
    }

    int index = organisms.indexOf(org);
    if (index == -1) {
      // Not Found
      // cout<<"ALERT: Attempt to remove nonexistent Organism from Species"<<endl;
      return false;
    } else {
      organisms.removeAt(index);
      return true;
    }
  }

  Organism? getChamp() {
    double champFitness = -1.0;
    Organism? theChamp;

    for (var curorg in organisms) {
      // TODO: Remove DEBUG code
      // cout<<"searching for champ...looking at org "<<(*curorg).gnome.genome_id<<" fitness: "<<(*curorg).fitness<<endl;
      if (curorg.fitness > champFitness) {
        theChamp = curorg;
        champFitness = theChamp.fitness;
      }
    }

    // cout<<"returning champ #"<<theChamp.gnome.genome_id<<endl;

    return theChamp;
  }

  bool reproduce(
    Neat neat,
    int generation,
    Population pop,
    List<Species> sortedSpecies,
  ) {
    if (expectedOffspring > 0 && organisms.isEmpty) {
      return false;
    }

    final theChamp = organisms.last;
    bool champPreserved = false;

    // Create the designated number of offspring for this species
    for (int count = 0; count < expectedOffspring; count++) {
      Organism baby;

      // 1. Superchamp offspring (stolen babies)
      if (theChamp.superChampOffspring > 0) {
        baby = _createSuperChampOffspring(
          neat,
          generation,
          pop,
          theChamp,
          count,
        );
      }
      // 2. Species champion preservation (clone without mutation if species is large enough)
      else if (!champPreserved && expectedOffspring > 5) {
        baby = _preserveChampion(neat, generation, theChamp, count);
        champPreserved = true;
      }
      // 3. Asexual reproduction (Mutation only)
      else if (neat.randFloat() < neat.mutateOnlyProb ||
          organisms.length <= 1) {
        baby = _createMutatedOffspring(neat, generation, pop, count);
      }
      // 4. Sexual reproduction (Mating + optional mutation)
      else {
        baby = _createMatedOffspring(
          neat,
          generation,
          pop,
          sortedSpecies,
          count,
        );
      }

      // 5. Place baby into its compatible species (or spawn a new species)
      _speciateBaby(neat, pop, baby);
    }

    return true;
  }

  // 1. Superchamp Offspring
  Organism _createSuperChampOffspring(
    Neat neat,
    int generation,
    Population pop,
    Organism theChamp,
    int count,
  ) {
    final newGenome = theChamp.gnome.duplicate(neat, count);
    bool mutStruct = false;

    if (theChamp.superChampOffspring > 1) {
      if (neat.randFloat() < 0.8 || neat.mutateAddLinkProb == 0.0) {
        newGenome.mutateLinkWeights(
          neat,
          neat.weightMutPower,
          1.0,
          Mutator.gaussian,
        );
      } else {
        newGenome.genesis(neat, generation);
        newGenome.mutateAddLink(
          neat,
          pop.innovations,
          pop.curInnovNum,
          neat.newlinkTries,
        );
        mutStruct = true;
      }
    }

    final baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
    baby.mutStructBaby = mutStruct;

    if (theChamp.superChampOffspring == 1 && theChamp.popChamp) {
      baby.popChampChild = true;
      baby.highFit = theChamp.origFitness;
    }

    theChamp.superChampOffspring--;
    return baby;
  }

  // 2. Preserve Species Champion
  Organism _preserveChampion(
    Neat neat,
    int generation,
    Organism theChamp,
    int count,
  ) {
    final newGenome = theChamp.gnome.duplicate(neat, count);
    return Organism.makeFromGenome(neat, 0.0, newGenome, generation);
  }

  // 3. Asexual Reproduction (Mutation Only)
  Organism _createMutatedOffspring(
    Neat neat,
    int generation,
    Population pop,
    int count,
  ) {
    final mom = organisms[neat.randInt(0, organisms.length - 1)];
    final newGenome = mom.gnome.duplicate(neat, count);

    final bool mutStruct = _applyMutations(neat, pop, newGenome, generation);

    final baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
    baby.mutStructBaby = mutStruct;
    return baby;
  }

  // 4. Sexual Reproduction (Mating)
  Organism _createMatedOffspring(
    Neat neat,
    int generation,
    Population pop,
    List<Species> sortedSpecies,
    int count,
  ) {
    final mom = organisms[neat.randInt(0, organisms.length - 1)];
    Organism dad;
    bool outside = false;

    // Intraspecies vs Interspecies mating
    if (neat.randFloat() > neat.interspeciesMateRate ||
        sortedSpecies.length <= 1) {
      dad = organisms[neat.randInt(0, organisms.length - 1)];
    } else {
      // Pick a dad from another species (tending towards better species)
      final otherSpecies = _selectRandomOtherSpecies(neat, sortedSpecies);
      dad = otherSpecies.organisms.first;
      outside = true;
    }

    // Perform Crossover
    final Genome newGenome;
    if (neat.randFloat() < neat.mateMultipointProb) {
      newGenome = mom.gnome.mateMultipoint(
        neat,
        dad.gnome,
        count,
        mom.origFitness,
        dad.origFitness,
        outside,
      );
    } else if (neat.randFloat() <
        (neat.mateMultipointAvgProb /
            (neat.mateMultipointAvgProb + neat.mateSinglepointProb))) {
      newGenome = mom.gnome.mateMultipointAvg(
        neat,
        dad.gnome,
        count,
        mom.origFitness,
        dad.origFitness,
        outside,
      );
    } else {
      newGenome = mom.gnome.mateSinglePoint(neat, dad.gnome, count);
    }

    // Optional mutation after mating
    bool mutStruct = false;
    final bool isSameParent =
        dad.gnome.genomeId == mom.gnome.genomeId ||
        dad.gnome.compatibility(neat, mom.gnome) == 0.0;
    if (neat.randFloat() > neat.mateOnlyProb || isSameParent) {
      mutStruct = _applyMutations(neat, pop, newGenome, generation);
    }

    final baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
    baby.mateBaby = true;
    baby.mutStructBaby = mutStruct;
    return baby;
  }

  Species _selectRandomOtherSpecies(Neat neat, List<Species> sortedSpecies) {
    for (int attempts = 0; attempts < 5; attempts++) {
      final double randMult = (neat.gaussRand() / 4.0).clamp(0.0, 1.0);
      final int idx = (randMult * (sortedSpecies.length - 1.0) + 0.5)
          .floor()
          .clamp(0, sortedSpecies.length - 1);
      if (sortedSpecies[idx] != this) {
        return sortedSpecies[idx];
      }
    }
    return this;
  }

  // 5. Common Mutation Dispatcher
  bool _applyMutations(
    Neat neat,
    Population pop,
    Genome genome,
    int generation,
  ) {
    if (neat.randFloat() < neat.mutateAddNodeProb) {
      genome.mutateAddNode(
        neat,
        pop.innovations,
        pop.curNodeId,
        pop.curInnovNum,
      );
      return true;
    } else if (neat.randFloat() < neat.mutateAddLinkProb) {
      genome.genesis(neat, generation);
      genome.mutateAddLink(
        neat,
        pop.innovations,
        pop.curInnovNum,
        neat.newlinkTries,
      );
      return true;
    } else {
      if (neat.randFloat() < neat.mutateRandomTraitProb) {
        genome.mutateRandomTrait(neat);
      }
      if (neat.randFloat() < neat.mutateLinkTraitProb) {
        genome.mutateLinkTrait(neat, 1);
      }
      if (neat.randFloat() < neat.mutateNodeTraitProb) {
        genome.mutateNodeTrait(neat, 1);
      }
      if (neat.randFloat() < neat.mutateLinkWeightsProb) {
        genome.mutateLinkWeights(
          neat,
          neat.weightMutPower,
          1.0,
          Mutator.gaussian,
        );
      }
      if (neat.randFloat() < neat.mutateToggleEnableProb) {
        genome.mutateToggleEnable(neat, 1);
      }
      if (neat.randFloat() < neat.mutateGeneReenableProb) {
        genome.mutateGeneReenable();
      }
      return false;
    }
  }

  // 6. Speciate Newborn Baby
  void _speciateBaby(Neat neat, Population pop, Organism baby) {
    final int originalCount = pop.species.length;

    for (int i = 0; i < originalCount; i++) {
      final curSpecies = pop.species[i];
      final compOrg = curSpecies.first();

      if (baby.gnome.compatibility(neat, compOrg.gnome) <
          neat.compatThreshold) {
        curSpecies.addOrganism(neat, baby);
        baby.species = curSpecies;
        return;
      }
    }

    // No compatible species found: spawn a new novel species
    final newSpecies = Species.makeFromNovel(++pop.lastSpecies, true);
    pop.species.add(newSpecies);
    newSpecies.addOrganism(neat, baby);
    baby.species = newSpecies;
  }

  bool rank() {
    // organisms.qsort(order_orgs);
    organisms.sort((a, b) => a.fitness.compareTo(b.fitness));

    return true;
  }
}
