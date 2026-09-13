import 'package:original_algorithm/neat/link.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/trait.dart';

enum Nodetype { unset, neuron, sensor }

enum Nodeplace { unset, hidden, input, output, bias }

enum Functype { unset, sigmoid }

/// @brief
/// A NODE is either a NEURON or a SENSOR.
///
///  - If it's a sensor, it can be loaded with a value for output
///
///  - If it's a neuron, it has a list of its incoming input signals (List<Link> is used)
///
/// Use an activation count to avoid flushing
class NNode {
  // keeps track of which activation the node is currently in
  int activationCount = 0;
  // Holds the previous step's activation for recurrency
  double lastActivation = 0.0;
  // Holds the activation BEFORE the prevous step's
  double lastActivation2 = 0.0;

  // This is necessary for a special recurrent case when the innode
  // of a recurrent link is one time step ahead of the outnode.
  // The innode then needs to send from TWO time steps ago
  Trait? nodeTrait; // Points to a trait of parameters

  int traitId = 0; // identify the trait derived by this node

  NNode? dup; // Used for Genome duplication

  NNode? analogue; // Used for Gene decoding

  // The NNode cannot compute its own output- something is overriding it
  bool override = false;

  // Contains the activation value that will override this node's activation
  double overrideValue = 0.0;

  // When frozen, cannot be mutated (meaning its trait pointer is fixed)
  bool frozen = false;

  // type is either SIGMOID ..or others that can be added
  Functype ftype = Functype.unset;
  // type is either NEURON or SENSOR
  Nodetype type = Nodetype.unset;

  double activeSum = 0.0; // The incoming activity before being processed
  double activation = 0.0; // The total activation entering the NNode
  bool activeFlag = false; // To make sure outputs are active

  // NOT USED IN NEAT - covered by "activation" above
  double output = 0.0; // Output of the NNode- the value in the NNode

  // ************ LEARNING PARAMETERS ***********
  // The following parameters are for use in
  //   neurons that learn through habituation,
  //   sensitization, or Hebbian-type processes

  List<double> params = [];

  // A list of pointers to incoming weighted signals from other nodes
  List<Link> incoming = [];
  // A list of pointers to links carrying this node's signal
  List<Link> outgoing = [];

  // These members are used for graphing with GTK+/GDK
  late List<double> rowLevels; // Depths from output where this node appears

  int row = 0; // Final row decided upon for drawing this NNode in
  int yPos = 0;
  int xPos = 0;

  // A node can be given an identification number for saving in files
  int nodeId = 0;

  double depth = 0.0; // The depth of the node in the network

  Nodeplace genNodeLabel = Nodeplace.unset; // Used for genetic marking of nodes

  NNode();

  factory NNode.makeFromNeat(Neat neat) {
    var node = NNode()..params = List.filled(Neat.numTraitParams, 0.0);

    return node;
  }

  factory NNode.makeFromType(Nodetype ntype, int nodeId) {
    var node = NNode()
      ..activeFlag = false
      ..activeSum = 0
      ..activation = 0
      ..output = 0
      ..lastActivation = 0
      ..lastActivation2 = 0
      // NEURON or SENSOR type
      ..type = ntype
      // Inactive upon creation
      ..activationCount = 0
      ..nodeId = nodeId
      ..ftype = Functype.sigmoid
      ..nodeTrait = null
      ..genNodeLabel = Nodeplace.hidden
      ..dup = null
      ..analogue = null
      ..frozen = false
      ..traitId = 1
      ..override = false;

    return node;
  }

  factory NNode.makeFromPlacement(
    Nodetype ntype,
    int nodeId,
    Nodeplace placement,
  ) {
    var node = NNode.makeFromType(ntype, nodeId);

    node.genNodeLabel = placement;

    return node;
  }

  // incoming and outgoing are not copied as they represent the phenotype network structure
  factory NNode.makeFromTrait(NNode node, Trait? trait) {
    var nde = NNode()
      ..activeFlag = false
      ..activeSum = 0
      ..activation = 0
      ..output = 0
      ..lastActivation = 0
      ..lastActivation2 = 0
      // Inactive upon creation
      ..type = node.type
      ..activationCount = 0
      ..nodeId = node.nodeId
      ..ftype = Functype.sigmoid
      ..nodeTrait = trait
      ..genNodeLabel = node.genNodeLabel
      ..dup = null
      ..analogue = null
      ..frozen = false;

    nde.traitId = trait?.traitId ?? 1;

    nde.override = false;

    return nde;
  }

  factory NNode.makeCopy(NNode node) {
    var nde = NNode()
      ..activeFlag = node.activeFlag
      ..activeSum = node.activeSum
      ..activation = node.activation
      ..output = node.output
      ..lastActivation = node.lastActivation
      ..lastActivation2 = node.lastActivation2
      // NEURON or SENSOR type
      ..type = node.type
      // Inactive upon creation
      ..activationCount = node.activationCount
      ..nodeId = node.nodeId
      ..ftype = node.ftype
      ..nodeTrait = node.nodeTrait
      ..genNodeLabel = node.genNodeLabel
      ..dup = node.dup
      ..analogue = node.analogue
      ..frozen = node.frozen
      ..traitId = node.traitId
      ..override = node.override
      ..depth = node.depth;

    return nde;
  }

  factory NNode.makeFromLine(String argLine, List<Trait> traits) {
    // This regex finds all number-like sequences of digits and dots.
    final RegExp numRegExp = RegExp(r'[\d\.]+');
    final matches = numRegExp.allMatches(argLine).map((m) => m[0]!).toList();

    // Expecting 8 numbers after the "node" keyword.
    if (!argLine.trim().startsWith('node') || matches.length < 4) {
      // In a real application, throwing a FormatException would be better.
      // For now, we return an empty/default Gene.
      throw FormatException('Invalid node line: $argLine');
    }

    var nde = NNode();

    // Parse all values from the matched strings.
    nde.nodeId = int.parse(matches[1]);
    nde.traitId = int.parse(matches[2]);
    var type = int.parse(matches[3]);
    switch (type) {
      case 0:
        nde.type = Nodetype.neuron;
        break;
      case 1:
        nde.type = Nodetype.sensor;
        break;
      default:
        nde.type = Nodetype.unset;
        break;
    }

    var genLabel = int.parse(matches[4]);
    switch (genLabel) {
      case 0:
        nde.genNodeLabel = Nodeplace.hidden;
        break;
      case 1:
        nde.genNodeLabel = Nodeplace.input;
        break;
      case 2:
        nde.genNodeLabel = Nodeplace.output;
        break;
      case 3:
        nde.genNodeLabel = Nodeplace.bias;
        break;
      default:
        nde.genNodeLabel = Nodeplace.unset;
        break;
    }

    // Get the Sensor Identifier and Parameter String
    // mySensor = SensorRegistry::getSensor(id, param);
    nde.frozen = false; // TODO: Maybe change

    if (nde.traitId == 0) {
      nde.nodeTrait = null;
    } else {
      // TODO convert to try/catch
      nde.nodeTrait = traits.firstWhere((t) => t.traitId == nde.traitId);
      nde.traitId = nde.nodeTrait!.traitId;
    }

    return nde;
  }

  bool isSensor() {
    return type == Nodetype.sensor;
  }

  bool isNeuron() {
    return type == Nodetype.neuron;
  }

  bool loadSensor(double value) {
    if (isSensor()) {
      // Time delay memory
      lastActivation2 = lastActivation;
      lastActivation = activation;

      activationCount++; // Puts sensor into next time-step
      activation = value;
      return true;
    } else {
      return false;
    }
  }

  // Return activation currently in node, if it has been activated, for step
  double getActiveOut() {
    return (activationCount > 0) ? activation : 0.0;
  }

  // Return activation currently in node from PREVIOUS (time-delayed) time step,
  // if there is one
  double getActiveOutTd() {
    return (activationCount > 1) ? lastActivation : 0.0;
  }

  // Tell whether node has been overridden
  bool overridden() {
    return override;
  }

  // Set activation to the override value and turn off override
  void activateOverride() {
    activation = overrideValue;
    override = false;
  }

  // Note: NEAT keeps track of which links are recurrent and which
  // are not even though this is unnecessary for activation.
  // It is useful to do so for 2 other reasons:
  // 1. It makes networks visualization of recurrent networks possible
  // 2. It allows genetic control of the proportion of connections
  //    that may become recurrent

  // Add an incoming connection a node
  void addIncoming(Neat neat, NNode feednode, double weight, bool recurrent) {
    var newlink = Link.makeFromNodes(neat, weight, feednode, this, recurrent);
    incoming.add(newlink);
    feednode.outgoing.add(newlink);
  }

  // Nonrecurrent version
  void addIncomingNonRecurrent(Neat neat, NNode feednode, double weight) {
    return addIncoming(neat, feednode, weight, false);
  }

  // This recursively flushes everything leading into and including this NNode,
  // including recurrencies
  void flushback() {
    // A sensor should not flush black
    if (!isSensor()) {
      if (activationCount > 0) {
        activationCount = 0;
        activation = 0;
        lastActivation = 0;
        lastActivation2 = 0;
      }

      // Flush back recursively
      for (var link in incoming) {
        // Flush the link itself (For future learning parameters possibility)
        link.addedWeight = 0;

        if (link.inNode != null) {
          if (link.inNode!.activationCount > 0) {
            link.inNode!.flushback();
          }
        }
      }
    } else {
      // Flush the SENSOR
      activationCount = 0;
      activation = 0;
      lastActivation = 0;
      lastActivation2 = 0;
    }
  }

  // This recursively checks everything leading into and including this NNode,
  // including recurrencies
  // Useful for debugging
  void flushbackCheck(List<NNode> seenlist) {
    if (!isSensor()) {
      // std::cout<<"ALERT: "<<this<<" has activation count "<<activation_count<<std::endl;
      // std::cout<<"ALERT: "<<this<<" has activation  "<<activation<<std::endl;
      // std::cout<<"ALERT: "<<this<<" has last_activation  "<<last_activation<<std::endl;
      // std::cout<<"ALERT: "<<this<<" has last_activation2  "<<last_activation2<<std::endl;

      // if (activation_count > 0)
      // {
      //     std::cout << "ALERT: " << this << " has activation count " << activation_count << std::endl;
      // }

      // if (activation > 0)
      // {
      //     std::cout << "ALERT: " << this << " has activation  " << activation << std::endl;
      // }

      // if (last_activation > 0)
      // {
      //     std::cout << "ALERT: " << this << " has last_activation  " << last_activation << std::endl;
      // }

      // if (last_activation2 > 0)
      // {
      //     std::cout << "ALERT: " << this << " has last_activation2  " << last_activation2 << std::endl;
      // }

      for (var link in incoming) {
        if (link.inNode != null) {
          try {
            seenlist.firstWhere(
              (n) =>
                  n.nodeId ==
                  ((link.inNode == null) ? -1 : link.inNode!.nodeId),
            );

            seenlist.add(link.inNode!);
            link.inNode!.flushbackCheck(seenlist);
          } on StateError {
            // No Node found
          }
        }
      }
    } else {
      // Flush_check the SENSOR
      // std::cout << "sALERT: " << this << " has activation count " << activation_count << std::endl;
      // std::cout << "sALERT: " << this << " has activation  " << activation << std::endl;
      // std::cout << "sALERT: " << this << " has last_activation  " << last_activation << std::endl;
      // std::cout << "sALERT: " << this << " has last_activation2  " << last_activation2 << std::endl;

      // if (activation_count > 0)
      // {
      //     std::cout << "ALERT: " << this << " has activation count " << activation_count << std::endl;
      // }

      // if (activation > 0)
      // {
      //     std::cout << "ALERT: " << this << " has activation  " << activation << std::endl;
      // }

      // if (last_activation > 0)
      // {
      //     std::cout << "ALERT: " << this << " has last_activation  " << last_activation << std::endl;
      // }

      // if (last_activation2 > 0)
      // {
      //     std::cout << "ALERT: " << this << " has last_activation2  " << last_activation2 << std::endl;
      // }
    }
  }

  // Reserved for future system expansion
  void deriveTrait(Neat neat, Trait? currentTrait) {
    if (currentTrait != null) {
      params = currentTrait.params;
      traitId = currentTrait.traitId;
    } else {
      params = List.filled(Neat.numTraitParams, 0.0);
      traitId = 1;
    }
  }

  void overrideOutput(double newOutput) {
    overrideValue = newOutput;
    override = true;
  }

  bool sensorLoad(double value) {
    if (type == Nodetype.sensor) {
      // Time delay memory
      lastActivation2 = lastActivation;
      lastActivation = activation;

      activationCount++; // Puts sensor into next time-step
      activation = value;
      return true;
    } else {
      return false;
    }
  }
}
