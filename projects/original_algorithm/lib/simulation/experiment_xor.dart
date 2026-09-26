import 'dart:math';

import 'package:flutter/services.dart';
import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/network.dart';
import 'package:original_algorithm/neat/organism.dart';
import 'package:original_algorithm/neat/population.dart';
import 'package:original_algorithm/simulation/experiment.dart';

class ExperimentXor extends Experiment {
  late Population pop;
  int id = 0;

  List<int> evals = []; // Hold records for each run
  List<int> genes = [];
  List<int> nodes = [];
  int winnernum = 0;
  int winnergenes = 0;
  int winnernodes = 0;
  // For averaging
  int totalevals = 0;
  int totalgenes = 0;
  int totalnodes = 0;

  int gens = 0;

  late Genome startGenome;

  @override
  void initialize(Neat neat, int gens) async {
    pop = Population();
    this.gens = gens;

    // Allocate fixed-size lists sized by neat.numRuns filled with 0
    evals = List<int>.filled(neat.numRuns, 0);
    genes = List<int>.filled(neat.numRuns, 0);
    nodes = List<int>.filled(neat.numRuns, 0);

    final String fileContent = await rootBundle.loadString(
      'lib/assets/xorstartgenes',
    );

    final List<String> lines = fileContent.split('\n');

    var fields = lines[0].split(' ');
    id = int.parse(fields[1]);

    startGenome = Genome.makeFromFile(neat, id, lines);
  }

  @override
  bool runExperiment(Neat neat) {
    spawnPopulation(neat);

    neat.log("Running Experiment: START $experimentCnt", true);

    for (generationCnt = 0; generationCnt <= gens; generationCnt++) {
      winnerFound = runGeneration(neat, generationCnt);
      if (winnerFound) break;
    }

    neat.log("Running Experiment: END $experimentCnt", true);

    experimentCnt++;

    return winnerFound;
  }

  bool runGeneration(Neat neat, int gen) {
    neat.log("=======================================================");
    neat.log("Running Generation (id): $gen", true);

    winnerFound = executeGen(neat, gen);

    return winnerFound;
  }

  bool executeGen(Neat neat, int genID) {
    bool winnerFound = false;

    neat.log("=============================================", true);
    neat.log("=== Epoch Beginning: Expr: $experimentCnt, GenId: $genID", true);
    neat.log("=============================================");
    String fileName = "gen_$genID";

    var (bool win, int winnum, int wingenes, int winnodes) = epoch(
      neat,
      pop,
      genID,
      fileName,
      winnernum,
      winnergenes,
      winnernodes,
    );
    // Check for success
    if (win) {
      // Collect Stats on end of experiment
      evals[experimentCnt] = neat.popSize * (genID - 1) + winnernum;
      genes[experimentCnt] = winnergenes;
      nodes[experimentCnt] = winnernodes;
      winnerFound = true;
    }

    neat.log("=============================================");
    neat.log("=== Epoch Complete: GenId: $genID", true);
    neat.log("=============================================", true);

    return winnerFound;
  }

  (bool win, int winnernum, int winnergenes, int winnernodes) epoch(
    Neat neat,
    Population pop,
    int generation,
    String filename,
    int winnernum,
    int winnergenes,
    int winnernodes,
  ) {
    bool win = false;

    // Evaluate each organism on a test
    for (var org in pop.organisms) {
      if (evaluate(neat, org)) {
        win = true;
        winnernum = org.gnome.genomeId;
        winnergenes = org.gnome.extrons();
        winnernodes = org.gnome.nodes.length;
        if (winnernodes == 5) {
          // You could dump out optimal genomes here if desired
          //(*curorg).gnome.print_to_filename("xor_optimal");
          neat.log("DUMPED OPTIMAL: ${org.gnome.genomeId}", true);
          // print_Genome_tofile((*curorg).gnome, "xor_optimal")
          // cout<<"DUMPED OPTIMAL"<<endl;
        }
      }
    }

    // Average and max their fitnesses for dumping to file and snapshot
    for (final s in pop.species) {
      // This experiment control routine issues commands to collect ave
      // and max fitness, as opposed to having the snapshot do it,
      // because this allows flexibility in terms of what time
      // to observe fitnesses at

      s.computeAverageFitness();
      s.computeMaxFitness();
    }

    if (win) {
      var winners = [];
      for (final org in pop.organisms) {
        if (org.winner) {
          // neat.log("WINNER IS # ${org.gnome.genomeId}", true);
          winners.add(org.gnome.genomeId);

          // Prints the winner to file
          // IMPORTANT: This causes generational file output!
          // print_Genome_tofile((*curorg).gnome, "xor_winner");
        }
      }
      var ids = winners.join(",");
      neat.log("Winners: $ids");
    }

    pop.epoch(neat, generation);

    return (win, winnernum, winnergenes, winnernodes);
  }

  bool evaluate(Neat neat, Organism org) {
    List<double> out = [0.0, 0.0, 0.0, 0.0]; // The four outputs
    // double this_out; // The current output
    double errorsum;

    bool success = false; // Check for successful activation
    // int numNodes; // Used to figure out how many nodes
    // should be visited during activation

    int relax; // Activates until relaxation

    // The four possible input combinations to xor
    // The first number is for biasing
    final List<List<double>> inP = [
      [1.0, 0.0, 1.0], // XOR: 1 ^ 0 ==> 1
      [0.0, 1.0, 1.0], // XOR: 0 ^ 1 ==> 1
      [1.0, 1.0, 1.0], // XOR: 1 ^ 1 ==> 0
      [0.0, 0.0, 1.0], // XOR: 0 ^ 0 ==> 0
    ];

    Network net = org.net;

    // numNodes = org.gnome.nodes.length;
    // neat.log("How many nodes to visit: " << numnodes);

    // The max depth of the network to be activated
    int netDepth = 10; // Recurrent networks may need more activations
    // neat.log("Evaluate Network DEPTH: " << net_depth);

    // Load and activate the network on each input
    for (int count = 0; count <= 3; count++) {
      net.loadSensors(inP[count]);

      // use depth to ensure relaxation
      for (relax = 0; relax <= netDepth; relax++) {
        success = net.activate(neat);
      }

      var outputStart = net.outputs.first;

      out[count] = outputStart.activation;

      net.flush();
    }

    if (success) {
      errorsum =
          (out[0].abs() +
          (1.0 - out[1]).abs() +
          (1.0 - out[2]).abs() +
          out[3].abs());
      org.fitness = pow(4.0 - errorsum, 2).toDouble();
      org.error = errorsum;
      // neat.log("Evaluate: new fitness: ${org.fitness}", true);
    } else {
      // The network is flawed (shouldn't happen)
      errorsum = 999.0;
      org.fitness = neat.organismFitnessMeasure;
      neat.log("Evaluate: The network is flawed (shouldn't happen)");
    }

    // neat.log("Org Genome Id " << org.gnome.genome_id << "                                     error: " << errorsum << " Outputs: [" << out[0] << " " << out[1] << " " << out[2] << " " << out[3] << "]");
    // neat.log("Org Genome Id " << org.gnome.genome_id << "                                     fitness: " << org.fitness);

    if ((out[0] < 0.5) &&
        (out[1] >= 0.5) &&
        (out[2] >= 0.5) &&
        (out[3] < 0.5)) {
      org.winner = true;
      return true;
    } else {
      org.winner = false;
      return false;
    }
  }

  void spawnPopulation(Neat neat) {
    // Spawn the Population and run it
    neat.log("Spawning Population off Genome");

    // neat.disableLog();
    // std::cout << "start_genome: " << start_genome.genome_id << ", pop_size: " << neat.pop_size << std::endl;
    pop = Population.makeFromGenome(neat, startGenome, neat.popSize);

    neat.log("Verifying Spawned Pop");
    pop.verify();
  }
}
