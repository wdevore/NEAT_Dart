import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/network.dart';
import 'package:original_algorithm/neat/species.dart';

class Organism {
  double fitness = 0.0; // A measure of fitness for the Organism
  // A fitness measure that won't change during adjustments
  double origFitness = 0.0;
  double error = 0.0; // Used just for reporting purposes
  bool winner = false; // Win marker (if needed for a particular task)
  late Network net; // The Organism's phenotype
  late Genome gnome; // The Organism's genotype
  late Species species; // The Organism's Species
  double expectedOffspring = 0.0; // Number of children this Organism may have
  int generation = 0; // Tells which generation this Organism is from
  bool eliminate = false; // Marker for destruction of inferior Organisms
  bool champion = false; // Marks the species champ
  // Number of reserved offspring for a population leader
  int superChampOffspring = 0;
  bool popChamp = false; // Marks the best in population
  // Marks the duplicate child of a champion (for tracking purposes)
  bool popChampChild = false;
  double highFit = 0.0; // DEBUG variable- high fitness of champ
  // When playing in real-time allows knowing the maturity of an individual
  int timeAlive = 0;

  // Track its origin- for debugging or analysis- we can tell how the organism was born
  bool mutStructBaby = false;
  bool mateBaby = false;

  // MetaData for the object
  String metadata = "";
  bool modified = false;

  Organism();

  factory Organism.makeFromGenome(
    Neat neat,
    double fit,
    Genome g,
    int gen, {
    String md = "",
  }) {
    var newOrg = Organism();

    newOrg.fitness = fit;
    newOrg.origFitness = fit;
    newOrg.gnome = g;
    newOrg.net = g.genesis(neat, g.genomeId);
    // newOrg.net = newOrg.update_phenotype(neat);
    // newOrg.species; // Start it in no Species. Note shared pointers default to nullptr
    newOrg.expectedOffspring = 0;
    newOrg.generation = gen;
    newOrg.eliminate = false;
    newOrg.error = 0;
    newOrg.winner = false;
    newOrg.champion = false;
    newOrg.superChampOffspring = 0;

    // If md is null, then we don't have metadata, otherwise we do have metadata so copy it over
    newOrg.metadata = md;

    newOrg.timeAlive = 0;

    // DEBUG vars
    newOrg.popChamp = false;
    newOrg.popChampChild = false;
    newOrg.highFit = 0;
    newOrg.mutStructBaby = false;
    newOrg.mateBaby = false;

    newOrg.modified = true;

    return newOrg;
  }

  factory Organism.makeCopy(Neat neat, Organism org) {
    var newOrg = Organism();

    newOrg.fitness = org.fitness;
    newOrg.origFitness = org.origFitness;
    newOrg.gnome = Genome.makeCopy(neat, org.gnome); // Associative relationship
    newOrg.net = Network.makeCopy(org.net); // Associative relationship
    newOrg.species = org.species; // Delegation relationship
    newOrg.expectedOffspring = org.expectedOffspring;
    newOrg.generation = org.generation;
    newOrg.eliminate = org.eliminate;
    newOrg.error = org.error;
    newOrg.winner = org.winner;
    newOrg.champion = org.champion;
    newOrg.superChampOffspring = org.superChampOffspring;

    newOrg.metadata = org.metadata;

    newOrg.timeAlive = org.timeAlive;
    newOrg.popChamp = org.popChamp;
    newOrg.popChampChild = org.popChampChild;
    newOrg.highFit = org.highFit;
    newOrg.mutStructBaby = org.mutStructBaby;
    newOrg.mateBaby = org.mateBaby;

    newOrg.modified = false;

    return newOrg;
  }

  Network updatePhenotype(Neat neat) {
    // Recreate the phenotype off the new genotype.
    // The old phenotype is automatically deallocated by the shared_ptr's assignment operator.
    net = gnome.genesis(neat, gnome.genomeId);

    modified = true;

    return net;
  }
}
