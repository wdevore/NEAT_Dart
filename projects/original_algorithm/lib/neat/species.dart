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
  late List<Organism> organisms; // The organisms in the Species
  // std::vector<Organism*> reproduction_pool;  //The organisms for reproduction- NOT NEEDED
  // If this is too long ago, the Species will goes extinct
  int ageOfLastImprovement = 0;
  double averageEst =
      0.0; // When playing real-time allows estimating average fitness

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
    // neat.log("########## Species::reproduce START ############");
    int curorgIndex = 0;

    int poolsize = 0; // The number of Organisms in the old generation

    int orgNum = 0; // Random variable

    Organism mom; // Parent Organisms
    Organism dad;
    Organism baby; // The new Organism

    Genome newGenome; // For holding baby's genes

    int curspeciesIndex = 0; // For adding baby
    int curspeciesEndIndex = pop.species.length;
    Species newspecies; // For babies in new Species
    Organism? comporg; // For Species determination through comparison

    Species randspecies; // For mating outside the Species
    double randMult = 0.0;
    int randSpeciesNum = 0;

    bool outside = false;

    bool found = false; // When a Species is found

    bool champDone = false; // Flag the preservation of the champion

    Organism theChamp;

    int giveup = 0; // For giving up finding a mate outside the species

    bool mutStructBaby = false;
    bool mateBaby = false;

    // The weight mutation power is species specific depending on its age
    double mutPower = neat.weightMutPower;

    int linkCount = 0;
    int nodeCount = 0;

    // Compute total fitness of species for a roulette wheel
    // Note: You don't get much advantage from a roulette here
    //  because the size of a species is relatively small.
    //  But you can use it by using the roulette code here
    // for(curorg=organisms.begin();curorg!=organisms.end();++curorg) {
    //   total_fitness+=(*curorg).fitness;
    // }

    // Check for a mistake
    if (expectedOffspring > 0 && organisms.isEmpty) {
      // neat.log("ERROR:  ATTEMPT TO REPRODUCE OUT OF EMPTY SPECIES");
      return false;
    }

    poolsize = organisms.length - 1;

    theChamp = organisms.last;

    // Create the designated number of offspring for the Species
    // one at a time
    for (var count = 0; count < expectedOffspring; count++) {
      mutStructBaby = false;
      mateBaby = false;

      outside = false;

      // Debug Trap
      if (expectedOffspring > neat.popSize) {
        // neat.log("ALERT: EXPECTED OFFSPRING = ", expected_offspring);
      }

      // If we have a super_champ (Population champion), finish off some special clones
      if ((theChamp.superChampOffspring) > 0) {
        mom = theChamp;
        newGenome = mom.gnome.duplicate(neat, count);

        // Most superchamp offspring will have their connection weights mutated only
        // The last offspring will be an exact duplicate of this super_champ
        // Note: Superchamp offspring only occur with stolen babies!
        //       Settings used for published experiments did not use this
        if (theChamp.superChampOffspring > 1) {
          if ((neat.randFloat() < 0.8) || (neat.mutateAddLinkProb == 0.0)) {
            // ABOVE LINE IS FOR:
            // Make sure no links get added when the system has link adding disabled
            newGenome.mutateLinkWeights(neat, mutPower, 1.0, Mutator.gaussian);
            // neat.log("called mutate_link_weights.");
          } else {
            // Sometimes we add a link to a superchamp
            newGenome.genesis(neat, generation);
            newGenome.mutateAddLink(
              neat,
              (pop.innovations),
              pop.curInnovNum,
              neat.newlinkTries,
            );
            mutStructBaby = true;
            // neat.log("called mutate_add_link.");
          }
        }

        baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);

        if (theChamp.superChampOffspring == 1) {
          if (theChamp.popChamp) {
            // neat.log("The new org baby's genome is ", baby.gnome.genome_id);
            baby.popChampChild = true;
            baby.highFit = mom.origFitness;
          }
        }

        theChamp.superChampOffspring--;
      }
      // If we have a Species champion, just clone it
      else if (!champDone && expectedOffspring > 5) {
        mom = theChamp; // Mom is the champ

        newGenome = mom.gnome.duplicate(neat, count);
        // neat.log("mom.gnome.duplicate: ", newGenome.genome_id);

        // Baby is just like mommy
        baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);

        champDone = true;
      }
      // First, decide whether to mate or mutate
      // If there is only one organism in the pool, then always mutate
      else if ((neat.randFloat() < neat.mutateOnlyProb) || poolsize == 0) {
        // Choose the random parent
        // neat.log("Choose the random parent: poolsize: ", poolsize);

        // RANDOM PARENT CHOOSER
        orgNum = neat.randInt(0, poolsize);
        curorgIndex = 0;
        for (var orgcount = 0; orgcount < orgNum; orgcount++) {
          ++curorgIndex;
        }

        ////Roulette Wheel
        // marble=randfloat()*total_fitness;
        // curorg=organisms.begin();
        // spin=(*curorg).fitness;
        // while(spin<marble) {
        //++curorg;

        ////Keep the wheel spinning
        // spin+=(*curorg).fitness;
        // }
        ////Finished roulette
        //

        mom = organisms[curorgIndex];

        newGenome = mom.gnome.duplicate(neat, count);

        // Do the mutation depending on probabilities of various mutations

        if (neat.randFloat() < neat.mutateAddNodeProb) {
          newGenome.mutateAddNode(
            neat,
            pop.innovations,
            pop.curNodeId,
            pop.curInnovNum,
          );
          mutStructBaby = true;
          nodeCount++;
          // neat.log("mutate_add_node: ", nodeCount);
        } else if (neat.randFloat() < neat.mutateAddLinkProb) {
          newGenome.genesis(neat, generation);
          newGenome.mutateAddLink(
            neat,
            pop.innovations,
            pop.curInnovNum,
            neat.newlinkTries,
          );

          mutStructBaby = true;
          linkCount++;
          // if (linkCount == 74 || linkCount == 73)
          //     std::cout << "break at " << linkCount << std::endl;
          // neat.log("mutate_add_link: ", linkCount);
        }
        // NOTE:  A link CANNOT be added directly after a node was added because the phenotype
        //        will not be appropriately altered to reflect the change
        else {
          // If we didn't do a structural mutation, we do the other kinds
          // neat.log("Without mating");

          if (neat.randFloat() < neat.mutateRandomTraitProb) {
            // neat.log("mutate_random_trait");
            newGenome.mutateRandomTrait(neat);
          }

          if (neat.randFloat() < neat.mutateLinkTraitProb) {
            // neat.log("mutate_link_trait");
            newGenome.mutateLinkTrait(neat, 1);
          }

          if (neat.randFloat() < neat.mutateNodeTraitProb) {
            // neat.log("mutate_node_trait");
            newGenome.mutateNodeTrait(neat, 1);
          }

          if (neat.randFloat() < neat.mutateLinkWeightsProb) {
            // neat.log("mutate_link_weights");
            newGenome.mutateLinkWeights(neat, mutPower, 1.0, Mutator.gaussian);
          }

          if (neat.randFloat() < neat.mutateToggleEnableProb) {
            // neat.log("mutate_toggle_enable");
            newGenome.mutateToggleEnable(neat, 1);
          }

          if (neat.randFloat() < neat.mutateGeneReenableProb) {
            // neat.log("mutate_gene_reenable");
            newGenome.mutateGeneReenable();
          }
        }

        baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
      }
      // Otherwise we should mate
      else {
        // Choose the random mom
        // neat.log("choose mom");

        orgNum = neat.randInt(0, poolsize);
        curorgIndex = 0;

        for (var orgcount = 0; orgcount < orgNum; orgcount++) {
          ++curorgIndex;
        }

        ////Roulette Wheel
        // marble=randfloat()*total_fitness;
        // curorg=organisms.begin();
        // spin=(*curorg).fitness;
        // while(spin<marble) {
        //++curorg;

        ////Keep the wheel spinning
        // spin+=(*curorg).fitness;
        // }
        ////Finished roulette
        //

        mom = organisms[curorgIndex];
        // Choose random dad

        if (neat.randFloat() > neat.interspeciesMateRate) {
          // Mate within Species
          // neat.log("choose dad");

          orgNum = neat.randInt(0, poolsize);
          curorgIndex = 0;
          for (var orgcount = 0; orgcount < orgNum; orgcount++) {
            ++curorgIndex;
          }

          ////Use a roulette wheel
          // marble=randfloat()*total_fitness;
          // curorg=organisms.begin();
          // spin=(*curorg).fitness;
          // while(spin<marble) {
          //++curorg;
          // }

          ////Keep the wheel spinning
          // spin+=(*curorg).fitness;
          // }
          ////Finished roulette
          //

          dad = organisms[curorgIndex];
        } else {
          // Mate outside Species
          randspecies = this;
          // neat.log("mate outside species");

          // Select a random species
          giveup = 0; // Give up if you cant find a different Species
          while (randspecies == this && (giveup < 5)) {
            // This old way just chose any old species
            // randspeciesnum=randint(0,(pop.species).size()-1);

            // Choose a random species tending towards better species
            randMult = neat.gaussRand() / 4;
            if (randMult > 1.0) randMult = 1.0;
            // This tends to select better species
            randSpeciesNum = (randMult * (sortedSpecies.length - 1.0) + 0.5)
                .floor();

            curorgIndex = 0;
            for (var spcount = 0; spcount < randSpeciesNum; spcount++) {
              ++curorgIndex;
            }

            randspecies = sortedSpecies[curorgIndex];

            ++giveup;
          }

          // OLD WAY: Choose a random dad from the random species
          // Select a random dad from the random Species
          // NOTE:  It is possible that a mating could take place
          //        here between the mom and a baby from the NEW
          //        generation in some other Species
          // orgnum=randint(0,(randspecies.organisms).size()-1);
          // curorg=(randspecies.organisms).begin();
          // for(orgcount=0;orgcount<orgnum;orgcount++)
          //   ++curorg;
          // dad=(*curorg);

          // New way: Make dad be a champ from the random species
          dad = randspecies.organisms.first;

          outside = true;
        }

        // Perform mating based on probabilities of differrent mating types
        if (neat.randFloat() < neat.mateMultipointProb) {
          newGenome = mom.gnome.mateMultipoint(
            neat,
            dad.gnome,
            count,
            mom.origFitness,
            dad.origFitness,
            outside,
          );
          // neat.log("mate_multipoint");
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
          // neat.log("mate_multipoint_avg");
        } else {
          newGenome = mom.gnome.mateSinglePoint(neat, dad.gnome, count);
          // neat.log("mate_singlepoint");
        }

        mateBaby = true;

        // Determine whether to mutate the baby's Genome
        // This is done randomly or if the mom and dad are the same organism
        if ((neat.randFloat() > neat.mateOnlyProb) ||
            (dad.gnome.genomeId == mom.gnome.genomeId) ||
            (dad.gnome.compatibility(neat, mom.gnome) == 0.0)) {
          // Do the mutation depending on probabilities of
          // various mutations
          if (neat.randFloat() < neat.mutateAddNodeProb) {
            newGenome.mutateAddNode(
              neat,
              pop.innovations,
              pop.curNodeId,
              pop.curInnovNum,
            );
            // neat.log("mutate_add_node");
            mutStructBaby = true;
          } else if (neat.randFloat() < neat.mutateAddLinkProb) {
            newGenome.genesis(neat, generation);
            newGenome.mutateAddLink(
              neat,
              pop.innovations,
              pop.curInnovNum,
              neat.newlinkTries,
            );
            // neat.log("mutate_add_link");

            mutStructBaby = true;
          } else {
            // Only do other mutations when not doing sturctural mutations
            // neat.log("With mating");

            if (neat.randFloat() < neat.mutateRandomTraitProb) {
              // neat.log("mutate_random_trait");
              newGenome.mutateRandomTrait(neat);
            }

            if (neat.randFloat() < neat.mutateLinkTraitProb) {
              // neat.log("mutate_link_trait");
              newGenome.mutateLinkTrait(neat, 1);
            }

            if (neat.randFloat() < neat.mutateNodeTraitProb) {
              // neat.log("mutate_node_trait");
              newGenome.mutateNodeTrait(neat, 1);
            }

            if (neat.randFloat() < neat.mutateLinkWeightsProb) {
              // neat.log("mutate_link_weights");
              newGenome.mutateLinkWeights(
                neat,
                mutPower,
                1.0,
                Mutator.gaussian,
              );
            }

            if (neat.randFloat() < neat.mutateToggleEnableProb) {
              // neat.log("mutate_toggle_enable");
              newGenome.mutateToggleEnable(neat, 1);
            }

            if (neat.randFloat() < neat.mutateGeneReenableProb) {
              // neat.log("mutate_gene_reenable");
              newGenome.mutateGeneReenable();
            }
          }

          // Create the baby
          baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
        } else {
          // Create the baby without mutating first
          baby = Organism.makeFromGenome(neat, 0.0, newGenome, generation);
        }
      }

      // Add the baby to its proper Species
      // If it doesn't fit a Species, create a new one

      baby.mutStructBaby = mutStructBaby;
      baby.mateBaby = mateBaby;

      if (pop.species.isEmpty) {
        // Create the first species
        newspecies = Species.makeFromNovel(++pop.lastSpecies, true);
        pop.species.add(newspecies);

        newspecies.addOrganism(neat, baby); // Add the baby
        baby.species = newspecies; // Point the baby to its species
      } else {
        comporg = pop.species[curspeciesIndex].first();
        found = false;
        while (curspeciesIndex != curspeciesEndIndex && !found) {
          if (comporg == null) {
            // Keep searching for a matching species
            ++curspeciesIndex;
            if (curspeciesIndex != curspeciesEndIndex) {
              comporg = pop.species[curspeciesIndex].first();
            }
          } else if (baby.gnome.compatibility(neat, comporg.gnome) <
              neat.compatThreshold) {
            // Found compatible species, so add this organism to it
            pop.species[curspeciesIndex].addOrganism(neat, baby);
            // Point organism to its species
            baby.species = pop.species[curspeciesIndex];
            found = true; // Note the search is over
          } else {
            // Keep searching for a matching species
            ++curspeciesIndex;
            if (curspeciesIndex != curspeciesEndIndex) {
              comporg = pop.species[curspeciesIndex].first();
            }
          }
        }

        // If we didn't find a match, create a new species
        if (found == false) {
          newspecies = Species.makeFromNovel(++pop.lastSpecies, true);

          // neat.log("CREATING NEW SPECIES ", pop.last_species);
          pop.species.add(newspecies);
          newspecies.addOrganism(neat, baby); // Add the baby
          baby.species = newspecies; // Point baby to its species
        }
      }
    } // End for loop

    if (linkCount > 0) {
      neat.logValue("Links added during reproduction: ", linkCount, false);
    }
    if (nodeCount > 0) {
      neat.logValue("Nodes added during reproduction: ", nodeCount, false);
    }

    neat.log("########## Species::reproduce END ############");

    return true;
  }

  bool rank() {
    // organisms.qsort(order_orgs);
    organisms.sort((a, b) => a.fitness.compareTo(b.fitness));

    return true;
  }
}
