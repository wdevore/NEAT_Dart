import 'package:original_algorithm/neat/neat.dart';

abstract class Experiment {
  int experimentCnt = 0; // How many experiments are run.
  int generationCnt = 0; // How may generations are run for each experiment.
  bool winnerFound = false;

  Experiment();

  Future<void> initialize(Neat neat, int gens);
  Future<bool> runExperiment(Neat neat);
  Future<bool> runGeneration(Neat neat, int gen);
  void postTest(Neat neat);
}
