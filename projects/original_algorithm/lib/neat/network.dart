import 'package:original_algorithm/neat/genome.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/nnode.dart';

/// @brief
/// A NETWORK is a LIST of input NODEs and a LIST of output NODEs
///
///     The point of the network is to define a single entity which can evolve
///     or learn on its own, even though it may be part of a larger framework
class Network {
  int numNodes = 0; // The number of nodes in the net (-1 means not yet counted)
  int numLinks = 0; // The number of links in the net (-1 means not yet counted)

  late List<NNode> allNodes; // A list of all the nodes

  int inputIndexIter = 0;
  int inputIndexEndIter = 0;

  late Genome genoType; // Allows Network to be matched with its Genome

  String name = ""; // Every Network or subNetwork can have a name
  late List<NNode> inputs; // NNodes that input into the network
  late List<NNode> outputs; // Values output by the network

  int netId = 0; // Allow for a network id

  double maxweight = 0.0; // Maximum weight in network for adaptation purposes

  bool adaptable = false; // Tells whether network can adapt or not

  Network();

  factory Network.makeUnAdaptable(
    List<NNode> inputs,
    List<NNode> outputs,
    List<NNode> allNodes,
    int netId,
  ) {
    return Network.makeAdaptable(inputs, outputs, allNodes, netId, false);
  }

  factory Network.makeAdaptable(
    List<NNode> inputs,
    List<NNode> outputs,
    List<NNode> allNodes,
    int netId,
    bool adaptable,
  ) {
    var net = Network()
      ..inputs = inputs
      ..outputs = outputs
      ..allNodes = allNodes
      ..name = ""
      ..numLinks = -1
      ..numNodes = -1
      ..netId = netId
      ..adaptable = adaptable;

    return net;
  }

  factory Network.makeEmpty(int netId) {
    return Network.makeEmptyAdaptable(netId, false);
  }

  factory Network.makeEmptyAdaptable(int netId, bool adaptable) {
    var net = Network()
      ..name = ""
      ..numLinks = -1
      ..numNodes = -1
      ..netId = netId
      ..adaptable = adaptable;

    return net;
  }

  factory Network.makeCopy(Network network) {
    var net = Network();

    // Copy inputs & outputs
    net.inputs = List.of(network.inputs);
    net.outputs = List.of(network.outputs);

    // Initialize and append
    net.allNodes = [];
    net.allNodes.addAll(net.inputs);
    net.allNodes.addAll(net.outputs);

    if (network.name.isNotEmpty) {
      net.name = network.name;
    } else {
      net.name = "";
    }

    net.numNodes = network.numNodes;
    net.numLinks = network.numLinks;
    net.netId = network.netId;
    net.adaptable = network.adaptable;

    return net;
  }

  // If all output are not active then return true
  bool outputsoff() {
    for (var curnode in outputs) {
      if (curnode.activationCount == 0) {
        return true;
      }
    }

    return false;
  }

  (bool isRecur, int count) isRecurrent(
    NNode potinNode,
    NNode potoutNode,
    int count,
    int thresh,
  ) {
    int countR = count++; // Count the node as visited

    if (countR > thresh) {
      // Short out the whole thing- loop detected
      return (false, countR);
    }

    if (potinNode == potoutNode) {
      return (true, countR);
    } else {
      // Check back on all links...
      for (var curlink in potinNode.incoming) {
        // But skip links that are already recurrent
        // We want to check back through the forward flow of signals only
        if (!curlink.isRecurrent) {
          var (isRecur, countO) = isRecurrent(
            curlink.inNode!,
            potoutNode,
            count,
            thresh,
          );
          if (isRecur) {
            return (true, countO);
          }
        }
      }

      return (false, countR);
    }
  }

  // Activates the net such that all outputs are active
  // Returns true on success;
  bool activate(Neat neat) {
    // neat.log("Network::activate START");

    double addAmount = 0.0; // For adding to the activesum
    bool oneTime = false; // Make sure we at least activate once
    // Used in case the output is somehow truncated from the network
    int abortCount = 0;

    // Keep activating until all the outputs have become active
    //(This only happens on the first activation, because after that they
    //  are always active)

    // NEW WAY: Sort nodes by depth
    List<NNode> sortedNodes = allNodes;
    sortedNodes.sort((a, b) => a.depth.compareTo(b.depth));

    for (var n in sortedNodes) {
      n.activeFlag = false;
    }

    while (outputsoff() || !oneTime) {
      abortCount++;

      if (abortCount == neat.networkAbortCount) {
        // neat.log("Inputs disconnected from output!");
        return false;
      }
      // neat.log("Outputs are off");

      // For each node, compute the sum of its incoming activation
      for (var curNode in sortedNodes) {
        // Ignore SENSORS
        // neat.log("On node ", curNode.nodeId);
        if (!curNode.isSensor()) {
          curNode.activeSum = 0;
          // This will tell us if it has any active inputs
          curNode.activeFlag = false;

          // For each incoming connection, add the activity from the connection to the activesum
          for (var curLink in curNode.incoming) {
            // Handle possible time delays
            if (!curLink.timeDelay) {
              addAmount = curLink.weight * curLink.inNode!.getActiveOut();

              if (curLink.inNode!.activeFlag || curLink.inNode!.isSensor()) {
                curNode.activeFlag = true;
              }

              curNode.activeSum += addAmount;
              // neat.log("1) Node (amount, nodeid) ", add_amount, curnode.node_id);
              // neat.log("  (activesum,from node) ", curnode.activesum, curlink.in_node.node_id);
            } else {
              // Input over a time delayed connection
              addAmount = curLink.weight * curLink.inNode!.getActiveOutTd();
              curNode.activeSum += addAmount;
              // neat.log("2) Node (amount, nodeid) ", add_amount, curnode.node_id);
              // neat.log("  (activesum,from link) ", curnode.activesum, curlink.in_node.node_id);
            }
          } // End for over incoming links
        } // End if (curnode.type != SENSOR)
      } // End for over all nodes

      // Now activate all the non-sensor nodes off their incoming activation
      for (var curNode in sortedNodes) {
        if (!curNode.isSensor()) {
          // Only activate if some active input came in
          if (curNode.activeFlag) {
            // neat.log("(Activating , with): ", curnode.node_id, curnode.activesum);

            // Keep a memory of activations for potential time delayed connections
            curNode.lastActivation2 = curNode.lastActivation;
            curNode.lastActivation = curNode.activation;

            // If the node is being overrided from outside,
            // stick in the override value
            if (curNode.overridden()) {
              // Set activation to the override value and turn off override
              curNode.activateOverride();
            } else {
              // Now run the net activation through an activation function
              if (curNode.ftype == Functype.sigmoid) {
                // Sigmoidal activation- see comments under fsigmoid
                curNode.activation = neat.fSigmoid(
                  curNode.activeSum,
                  neat.networkActivateSigmoidSlope,
                  neat.networkActivateSigmoidConstant,
                );
              }
            }
            // neat.log("node activation: ", curNode.activation);

            // Increment the activation_count
            // First activation cannot be from nothing!!
            curNode.activationCount++;
          }
        }
      }

      oneTime = true;
    }

    if (adaptable) {
      // neat.log("ADAPTING");
      // ADAPTATION:  Adapt weights based on activations
      for (var curNode in allNodes) {
        // Ignore SENSORS
        // neat.log("Ignore SENSORS: On node ", curnode.node_id);

        if (!curNode.isSensor()) {
          // For each incoming connection, perform adaptation based on the trait of the connection
          for (var curLink in curNode.incoming) {
            if ((curLink.traitId == 2) ||
                (curLink.traitId == 3) ||
                (curLink.traitId == 4)) {
              // In the recurrent case we must take the last activation of the input for calculating hebbian changes
              if (curLink.isRecurrent) {
                curLink.weight = neat.hebbian(
                  curLink.weight,
                  maxweight,
                  curLink.inNode!.lastActivation,
                  curLink.outNode!.getActiveOut(),
                  curLink.params[0],
                  curLink.params[1],
                  curLink.params[2],
                );
              } else {
                // non-recurrent case
                curLink.weight = neat.hebbian(
                  curLink.weight,
                  maxweight,
                  curLink.inNode!.getActiveOut(),
                  curLink.outNode!.getActiveOut(),
                  curLink.params[0],
                  curLink.params[1],
                  curLink.params[2],
                );
              }
            }
          }
        }
      }
    } // end if (adaptable)
    // neat.log("Network::activate END");

    // ==========
    return true;
  }

  // Add an input
  void addInput(NNode inNode) {
    inputs.add(inNode);
  }

  int inputStart() {
    inputIndexIter = 0;
    inputIndexEndIter = inputs.length;
    return 1;
  }

  int loadIn(double d) {
    inputs[inputIndexIter].sensorLoad(d);
    inputIndexIter++;
    if (inputIndexIter == inputIndexEndIter) {
      return 0;
    } else {
      return 1;
    }
  }

  // Takes an array of sensor values and loads it into SENSOR inputs ONLY
  double loadSensors(double sensvals) {
    for (var sensPtr in inputs) {
      // only load values into SENSORS (not BIASes)
      if (sensPtr.isSensor()) {
        sensPtr.sensorLoad(sensvals);
        sensvals++;
      }
    }
    return sensvals;
  }
}
