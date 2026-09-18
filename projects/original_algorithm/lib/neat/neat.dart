import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:math' as mat;

import 'package:flutter/foundation.dart';
import 'package:mt19937/mt19937.dart';

class Neat {
  /// The number of parameters used in a trait.
  /// This is a constant used to size lists where needed.
  static const int numTraitParams = 8;

  int experiment = 0;

  double traitParamMutProb = 0.0;
  double traitMutationPower = 0.0; // Power of mutation on a signle trait param
  // Amount that mutationNum changes for a trait change inside a link
  double linktraitMutSig = 0.0;
  // Amount a mutationNum changes on a link connecting a node that changed its trait
  double nodetraitMutSig = 0.0;
  double weightMutPower = 0.0; // The power of a linkweight mutation
  // Prob. that a link mutation which doesn't have to be recurrent will be made recurrent
  double recurProb = 0.0;
  double disjointCoeff = 0.0;
  double excessCoeff = 0.0;
  double mutdiffCoeff = 0.0;
  double compatThreshold = 0.0;
  double ageSignificance = 0.0; // How much does age matter?
  double survivalThresh = 0.0; // Percent of average fitness for survival
  double mutateOnlyProb = 0.0; // Prob. of a non-mating reproduction
  double mutateRandomTraitProb = 0.0;
  double mutateLinkTraitProb = 0.0;
  double mutateNodeTraitProb = 0.0;
  double mutateLinkWeightsProb = 0.0;
  double mutateToggleEnableProb = 0.0;
  double mutateGeneReenableProb = 0.0;
  double mutateAddNodeProb = 0.0;
  double mutateAddLinkProb = 0.0;
  double interspeciesMateRate = 0.0; // Prob. of a mate being outside species
  double mateMultipointProb = 0.0;
  double mateMultipointAvgProb = 0.0;
  double mateSinglepointProb = 0.0;
  double mateOnlyProb = 0.0; // Prob. of mating without mutation
  // Probability of forcing selection of ONLY links that are naturally recurrent
  double recurOnlyProb = 0.0;

  int popSize = 0; // Size of population
  int dropoffAge = 0; // Age where Species starts to be penalized
  // Number of tries mutateAddLink will attempt to find an open link
  int newlinkTries = 0;
  int printEvery = 0; // Tells to print population to file every n generations
  int babiesStolen = 0; // The number of babies to siphen off to the champions
  int numRuns = 0;
  // Used in case the output is somehow truncated from the network
  int networkAbortCount = 0;

  // Network activation sigmoid function slope parameter
  double networkActivateSigmoidSlope = 0;
  // Network activation sigmoid function constant parameter
  double networkActivateSigmoidConstant = 0;
  double organismFitnessMeasure = 0; // Measure of fitness for organisms

  // =================================================================
  // Randoms
  // =================================================================
  int randomSeed = 13163;

  /// The maximum value for a 32-bit signed integer (2^31 - 1).
  static const int maxInt32 = 2147483647;

  /// The Mersenne Twister random number generator.
  late RandomMt19937 random;

  Neat();

  void initialize() {
    random = RandomMt19937(seed: randomSeed);
  }

  /// Returns a random floating point number between 0.0 and 1.0.
  double randF() => random.nextDouble();

  /// Returns a random integer between 0 and maxInt32 (inclusive).
  /// Note: nextInt's upper bound is exclusive, so we add 1 if the library
  /// can handle it, otherwise we just use maxInt32.
  int randI() => random.nextInt(maxInt32);

  /// Returns either 1 or -1 randomly.
  int randPosNeg() {
    // Use nextBool() for a clear and efficient random choice.
    return random.nextBool() ? 1 : -1;
  }

  int randInt(int x, int y) {
    int rand = randI() % (y - x + 1) + x;
    // log("randInt: ", rand);
    return rand;
  }

  double randFloat() {
    double rand = randF(); // / double.maxFinite;
    // log("rand: ", rand);
    return rand;
  }

  double gaussRand() {
    int iset = 0;
    double gset = 0.0;
    double fac, rsq, v1, v2;

    if (iset == 0) {
      do {
        double randG1 = randFloat();
        double randG2 = randFloat();
        // log("(randG1,randG2): ", randG1, randG2);
        v1 = 2.0 * randG1 - 1.0;
        v2 = 2.0 * randG2 - 1.0;
        rsq = v1 * v1 + v2 * v2;
      } while (rsq >= 1.0 || rsq == 0.0);
      fac = mat.sqrt(-2.0 * mat.log(rsq) / rsq);
      gset = v1 * fac;
      iset = 1;
      return v2 * fac;
    } else {
      iset = 0;
      return gset;
    }
  }

  // SIGMOID FUNCTION ********************************
  // This is a signmoidal activation function, which is an S-shaped squashing function
  // It smoothly limits the amplitude of the output of a neuron to between 0 and 1
  // It is a helper to the neural-activation function get_active_out
  // It is made inline so it can execute quickly since it is at every non-sensor
  // node in a network.
  // NOTE:  In order to make node insertion in the middle of a link possible,
  // the signmoid can be shifted to the right and more steeply sloped:
  // slope=4.924273
  // constant= 2.4621365
  // These parameters optimize mean squared error between the old output,
  // and an output of a node inserted in the middle of a link between
  // the old output and some other node.
  // When not right-shifted, the steepened slope is closest to a linear
  // ascent as possible between -0.5 and 0.5
  double fSigmoid(double activesum, double slope, double constant) {
    // RIGHT SHIFTED ---------------------------------------------------------
    // return (1/(1+(exp(-(slope*activesum-constant))))); //ave 3213 clean on 40 runs of p2m and 3468 on another 40
    // 41394 with 1 failure on 8 runs

    // LEFT SHIFTED ----------------------------------------------------------
    // return (1/(1+(exp(-(slope*activesum+constant))))); //original setting ave 3423 on 40 runs of p2m, 3729 and 1 failure also

    // PLAIN SIGMOID ---------------------------------------------------------
    // return (1/(1+(exp(-activesum)))); //3511 and 1 failure

    // LEFT SHIFTED NON-STEEPENED---------------------------------------------
    // return (1/(1+(exp(-activesum-constant)))); //simple left shifted

    // NON-SHIFTED STEEPENED
    return (1 / (1 + (mat.exp(-(slope * activesum))))); // Compressed
  }

  double hebbian(
    double weight,
    double maxWeight,
    double activeIn,
    double activeOut,
    double hebbRate,
    double preRate,
    double postRate,
  ) {
    bool neg = false;
    double delta = 0.0;

    double topWeight = 0.0;

    if (maxWeight < 5.0) maxWeight = 5.0;

    if (weight > maxWeight) weight = maxWeight;

    if (weight < -maxWeight) weight = -maxWeight;

    if (weight < 0) {
      neg = true;
      weight = -weight;
    }

    topWeight = weight + 2.0;
    if (topWeight > maxWeight) topWeight = maxWeight;

    if (!(neg)) {
      // if (true) {
      delta =
          hebbRate * (maxWeight - weight) * activeIn * activeOut +
          preRate * (topWeight) * activeIn * (activeOut - 1.0);

      return weight + delta;
    } else {
      // In the inhibatory case, we strengthen the synapse when output is low and
      // input is high
      delta =
          preRate *
              (maxWeight - weight) *
              activeIn *
              (1.0 - activeOut) + //"unhebb"
          -hebbRate * (topWeight + 2.0) * activeIn * activeOut + // anti-hebbian
          0;

      return -(weight + delta);
    }
  }

  // =================================================================
  // Log
  // =================================================================

  // Log to a file
  IOSink? _logSink;
  Timer? _flushTimer;

  /// Opens a log file at the given path for writing.
  ///
  /// Any existing file will be overwritten.
  Future<void> openLog(String filePath) async {
    try {
      // Ensure any previously opened file sink is closed.
      await closeLog();
      final file = File(filePath);
      _logSink = file.openWrite(mode: FileMode.write);

      // Periodically flush every 2 seconds
      _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _logSink?.flush();
      });
    } catch (e) {
      // In a real application, you might use a more robust logging package
      // or error handling strategy.
      if (kDebugMode) {
        print('Error opening log file: $e');
      }
    }
  }

  /// Writes a message to the log file, followed by a newline.
  void log(String message) {
    _logSink?.writeln(message);
  }

  /// Manually flushes buffered log entries to disk.
  Future<void> flushLog() async {
    if (kDebugMode) {
      print('Flushing log file');
    }
    await _logSink?.flush();
  }

  /// Flushes and closes the log file stream
  Future<void> closeLog() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
    if (kDebugMode) {
      print('Closed log file');
    }
  }

  void logValue(String message, int value, bool enabled) {
    if (enabled) {
      log("$message: $value");
    }
  }

  void logValue2(String message, int value, int value2, bool enabled) {
    if (enabled) {
      log("$message: $value, $value2");
    }
  }

  void logDbl(String message, double value, bool enabled) {
    if (enabled) {
      log("$message: $value");
    }
  }

  void loadNeatParams(String s) async {
    // 1. Load the raw text from the .ne asset
    final String fileContent = await rootBundle.loadString(
      'lib/assets/p2test.ne',
    );

    // 2. Split into lines for your NEAT parsers
    final List<String> lines = fileContent.split('\n');

    var fields = lines[0].split(' ');
    experiment = int.parse(fields[1]);

    fields = lines[1].split(' ');
    traitParamMutProb = double.parse(fields[1]);

    fields = lines[2].split(' ');
    traitMutationPower = double.parse(fields[1]);

    fields = lines[3].split(' ');
    linktraitMutSig = double.parse(fields[1]);

    fields = lines[4].split(' ');
    nodetraitMutSig = double.parse(fields[1]);

    fields = lines[5].split(' ');
    weightMutPower = double.parse(fields[1]);

    fields = lines[6].split(' ');
    recurProb = double.parse(fields[1]);

    fields = lines[7].split(' ');
    disjointCoeff = double.parse(fields[1]);

    fields = lines[8].split(' ');
    excessCoeff = double.parse(fields[1]);

    fields = lines[9].split(' ');
    mutdiffCoeff = double.parse(fields[1]);

    fields = lines[10].split(' ');
    compatThreshold = double.parse(fields[1]);

    fields = lines[11].split(' ');
    ageSignificance = double.parse(fields[1]);

    fields = lines[12].split(' ');
    survivalThresh = double.parse(fields[1]);

    fields = lines[13].split(' ');
    mutateOnlyProb = double.parse(fields[1]);

    fields = lines[14].split(' ');
    mutateRandomTraitProb = double.parse(fields[1]);

    fields = lines[15].split(' ');
    mutateLinkTraitProb = double.parse(fields[1]);

    fields = lines[16].split(' ');
    mutateNodeTraitProb = double.parse(fields[1]);

    fields = lines[17].split(' ');
    mutateLinkWeightsProb = double.parse(fields[1]);

    fields = lines[18].split(' ');
    mutateToggleEnableProb = double.parse(fields[1]);

    fields = lines[19].split(' ');
    mutateGeneReenableProb = double.parse(fields[1]);

    fields = lines[20].split(' ');
    mutateAddNodeProb = double.parse(fields[1]);

    fields = lines[21].split(' ');
    mutateAddLinkProb = double.parse(fields[1]);

    fields = lines[22].split(' ');
    interspeciesMateRate = double.parse(fields[1]);

    fields = lines[23].split(' ');
    mateMultipointProb = double.parse(fields[1]);

    fields = lines[24].split(' ');
    mateMultipointAvgProb = double.parse(fields[1]);

    fields = lines[25].split(' ');
    mateSinglepointProb = double.parse(fields[1]);

    fields = lines[26].split(' ');
    mateOnlyProb = double.parse(fields[1]);

    fields = lines[27].split(' ');
    recurOnlyProb = double.parse(fields[1]);

    fields = lines[28].split(' ');
    popSize = int.parse(fields[1]);

    fields = lines[29].split(' ');
    dropoffAge = int.parse(fields[1]);

    fields = lines[30].split(' ');
    newlinkTries = int.parse(fields[1]);

    fields = lines[31].split(' ');
    printEvery = int.parse(fields[1]);

    fields = lines[32].split(' ');
    babiesStolen = int.parse(fields[1]);

    fields = lines[33].split(' ');
    numRuns = int.parse(fields[1]);

    fields = lines[34].split(' ');
    networkActivateSigmoidSlope = double.parse(fields[1]);

    fields = lines[35].split(' ');
    networkActivateSigmoidConstant = double.parse(fields[1]);

    fields = lines[36].split(' ');
    networkAbortCount = int.parse(fields[1]);

    fields = lines[37].split(' ');
    organismFitnessMeasure = double.parse(fields[1]);
  }
}
