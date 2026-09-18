import 'package:flutter/foundation.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/simulation/experiment_xor.dart';

class Simulation extends ChangeNotifier {
  late Neat neat;
  late ExperimentXor exor;

  Simulation();

  Future<void> initialize() async {
    neat = Neat();
    neat.initialize();

    neat.loadNeatParams("assets/p2test.ne");
    await neat.openLog("/media/RAMDisk/neatdart.log");
    neat.log("NeatDart log");

    exor = ExperimentXor();
    exor.initialize(neat, 1);

    notifyListeners();
  }

  Future<void> flushLog() => neat.flushLog();
  Future<void> closeLog() => neat.closeLog();

  void run() {
    exor.runExperiment(neat);
  }
}
