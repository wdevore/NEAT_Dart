import 'package:original_algorithm/neat/neat.dart';

abstract class Experiment {
  int experimentCnt = 0; // How many experiments are run.
  int generationCnt = 0; // How may generations are run for each experiment.
  bool winnerFound = false;

  Experiment();

  void initialize(Neat neat, int gens);
  bool runExperiment(Neat neat);
}
