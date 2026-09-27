import 'package:flutter/foundation.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/simulation/experiment_xor.dart';

class Simulation extends ChangeNotifier {
  late Neat neat;
  late ExperimentXor exor;

  Simulation();

  Future<void> initialize(int generationsToRun) async {
    neat = Neat();
    neat.initialize();

    await neat.loadNeatParams("assets/p2test.ne");
    await neat.openLog("/media/RAMDisk/neatdart.log");
    neat.log("NeatDart log");

    exor = ExperimentXor();
    await exor.initialize(neat, generationsToRun);

    notifyListeners();
  }

  Future<void> flushLog() => neat.flushLog();
  Future<void> closeLog() => neat.closeLog();

  Future<void> runSingleExperiment() async {
    await exor.runExperiment(neat);
    await neat.flushLog();
  }

  Future<void> runSimulation() async {
    // Runs a series of experiments until a winner is found or commanded
    // to stop, or number of runs met.
    try {
      do {
        neat.log("Running experiment: ${exor.experimentCnt}");
        if (kDebugMode) print("Running experiment: ${exor.experimentCnt}");

        await exor.runExperiment(neat);
        neat.log(
          "Experiment complete: Winner? ${exor.winnerFound ? "Yes" : "No"}",
        );
        if (kDebugMode) {
          print(
            "Experiment complete: Winner? ${exor.winnerFound ? "Yes" : "No"}",
          );
        }
        await neat.flushLog();
      } while (!exor.winnerFound && /*!paused &&*/
          exor.experimentCnt < neat.numRuns);

      showReport(neat);
    } finally {
      await neat.flushLog();
    }
  }

  void showReport(Neat neat) {
    exor.postTest(neat);
  }
}
