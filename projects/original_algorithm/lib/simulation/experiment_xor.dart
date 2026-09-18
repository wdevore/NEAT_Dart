import 'package:flutter/services.dart';
import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/neat.dart';
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

    return winnerFound;
  }

  void spawnPopulation(Neat neat) {
    // Spawn the Population and run it
    neat.log("Spawning Population off Genome");

    // neat.disableLog();
    // std::cout << "start_genome: " << start_genome->genome_id << ", pop_size: " << neat.pop_size << std::endl;
    pop = Population.makeFromGenome(neat, startGenome, neat.popSize);

    neat.log("Verifying Spawned Pop");
    pop.verify();
  }
}
