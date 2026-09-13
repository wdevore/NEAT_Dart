import 'package:original_algorithm/neat/gene.dart';
import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/neat.dart';
import 'package:original_algorithm/neat/network.dart';
import 'package:collection/collection.dart';
import 'package:original_algorithm/neat/nnode.dart';
import 'package:original_algorithm/neat/trait.dart';

enum Mutator { unset, gaussian, coldgaussian }

/// @brief
/// A Genome is the primary source of genotype information used to create
/// a phenotype.  It contains 3 major constituents:
///
///  1) A list of Traits
///
///  2) A list of NNodes pointing to a Trait from (1)
///
///  3) A list of Genes with Links that point to Traits from (1)
///
///(1) Reserved parameter space for future use
///
///(2) NNode specifications
///
///(3) Is the primary source of innovation in the evolutionary Genome.
///    Each Gene in (3) has a marker telling when it arose historically.
///    Thus, these Genes can be used to speciate the population, and the
///    list of Genes provide an evolutionary history of innovation and
///    link-building.
class Genome2 {
  int genomeId = 0;

  List<Trait> traits = []; // parameter conglomerations
  List<NNode> nodes = []; // List of NNodes for the Network
  List<Gene> genes = []; // List of innovation-tracking genes

  // Allows Genome to be matched with its Network. Constructed in genesis()
  late Network phenotype;

  Genome2();

  // Adds a new gene that has been created through a mutation in the
  // *correct order* into the list of genes in the genome
  void addGene(List<Gene> glist, Gene g) {
    // Use lowerBound from package:collection to find the insertion point.
    // This performs a binary search, which is very efficient (O(log n)).
    final index = lowerBound(
      glist,
      g,
      compare: (a, b) => a.innovationNum.compareTo(b.innovationNum),
    );

    // Insert the gene at the found index to maintain sort order.
    glist.insert(index, g);
  }

  // Inserts a NNode into a given ordered list of NNodes in order
  void addNode(List<NNode> nlist, NNode n) {
    // Use lowerBound from package:collection to find the insertion point.
    // This performs a binary search, which is very efficient (O(log n)).
    final index = lowerBound(
      nlist,
      n,
      compare: (a, b) => a.nodeId.compareTo(b.nodeId),
    );

    // Insert the node at the found index to maintain sort order.
    nlist.insert(index, n);
  }

  bool mutateAddLink(
    Neat neat,
    List<Innovation> innovations,
    double currentInnovation,
    int tries,
  ) {
    int nodeNum1 = 0;
    int nodeNum2 = 0; // Random node numbers
    // NNode theNode1, thenode2; // Random node iterators
    int nodeCount = 0; // Counter for finding nodes
    // Iterates over attempts to find an unconnected pair of nodes
    int tryCount = 0;
    late NNode nodeP1; // Pointers to the nodes // TODO: check if used
    late NNode nodeP2; // Pointers to the nodes
    // List<Gene>::iterator thegene;             // Searches for existing link
    bool found = false; // Tells whether an open pair was found
    // List<Innovation>::iterator theinnov;      // For finding a historical match
    bool recurrentFlag = false; // Indicates whether proposed link is recurrent
    late Gene newGene; // The new Gene

    int traitNum = 0; // Random trait finder
    // List<Trait>::iterator thetrait;

    double newWeight = 0.0; // The new weight for the new link

    bool done = false;
    bool doRecur = false;
    bool loopRecur = false;
    int firstNonsensor = 0;

    // These are used to avoid getting stuck in an infinite loop checking
    // for recursion
    // Note that we check for recursion to control the frequency of
    // adding recurrent links rather than to prevent any paricular
    // kind of error
    int thresh = (nodes.length) * (nodes.length);
    int count = 0;

    // Make attempts to find an unconnected pair
    tryCount = 0;

    // Decide whether to make this recurrent
    doRecur = neat.randFloat() < neat.recurOnlyProb;

    // Find the first non-sensor so that the toNode won't look at sensors as
    // possible destinations
    // indexWhere returns the first index that satisfies the condition, or -1.
    firstNonsensor = nodes.indexWhere((node) => !node.isSensor());

    // Handle the case where all nodes are sensors (indexWhere returns -1)
    if (firstNonsensor == -1) {
      // All nodes are sensors, so we can't add a link.
      return false;
    }

    // Here is the recurrent finder loop- it is done separately
    if (doRecur) {
      while (tryCount < tries) {
        // Some of the time try to make a recur loop
        loopRecur = neat.randFloat() > 0.5 ? true : false;

        if (loopRecur) {
          nodeNum1 = neat.randInt(firstNonsensor, nodes.length - 1);
          nodeNum2 = nodeNum1;
        } else {
          // Choose random nodenums
          nodeNum1 = neat.randInt(0, nodes.length - 1);
          nodeNum2 = neat.randInt(firstNonsensor, nodes.length - 1);
        }

        // Directly access elements by their index.
        nodeP1 = nodes[nodeNum1];
        nodeP2 = nodes[nodeNum2];

        // Check if the proposed link is valid.
        // A link is invalid if the target is a sensor, or if the exact
        // recurrent link already exists in the genome.
        // The link is invalid if the output node is a sensor OR if any gene
        // exists where the in-node, out-node, and recurrent flag all match.
        final bool linkInvalid =
            nodeP2.isSensor() ||
            genes.any(
              (gene) =>
                  gene.link.inNode == nodeP1 &&
                  gene.link.outNode == nodeP2 &&
                  gene.link.isRecurrent,
            );

        // If the link is invalid, increment the try count and try again.
        if (linkInvalid) {
          tryCount++;
        } else {
          // Use depth to check for recurrency
          recurrentFlag = nodeP1.depth > nodeP2.depth;

          // Exit if the network is faulty (contains an infinite loop)
          // NOTE: A loop doesn't really matter
          // if (count>thresh) {
          //   cout<<"LOOP DETECTED DURING A RECURRENCY CHECK"<<std::endl;
          //   return false;
          // }

          // Make sure it finds the right kind of link (recur)
          if (!recurrentFlag) {
            tryCount++;
          } else {
            tryCount = tries;
            found = true;
          }
        }
      }
    } else {
      // Loop to find a non-recurrent link
      while (tryCount < tries) {
        // Choose random nodenums
        // Find the first node
        nodeNum1 = neat.randInt(0, nodes.length - 1);
        nodeNum2 = neat.randInt(firstNonsensor, nodes.length - 1);

        // Directly access elements by their index.
        nodeP1 = nodes[nodeNum1];
        nodeP2 = nodes[nodeNum2];

        final bool linkInvalid =
            nodeP2.isSensor() ||
            genes.any(
              (gene) =>
                  gene.link.inNode == nodeP1 &&
                  gene.link.outNode == nodeP2 &&
                  gene.link.isRecurrent,
            );

        // If the link is invalid, increment the try count and try again.
        if (linkInvalid) {
          tryCount++;
        } else {
          // Use depth to check for recurrency
          recurrentFlag = nodeP1.depth > nodeP2.depth;

          // Exit if the network is faulty (contains an infinite loop)
          if (count > thresh) {
            // cout<<"LOOP DETECTED DURING A RECURRENCY CHECK"<<std::endl;
            // return false;
          }

          // Make sure it finds the right kind of link (recurrent or not)
          if (recurrentFlag) {
            tryCount++;
          } else {
            tryCount = tries;
            found = true;
          }
        }
      }
    }

    // Continue only if an open link was found
    if (found) {
      // If it was supposed to be recurrent, make sure it gets labeled that way
      if (doRecur) {
        recurrentFlag = true;
      }

      // Search: The firstWhereOrNull call searches the innovations list.
      // It returns the first innovation that matches all the criteria
      // (link type, input/output nodes, and recurrent status) or null if no match is found.
      // Look for a historical innovation that matches this link
      final existingInnov = innovations.firstWhereOrNull(
        (innov) =>
            innov.innovationType == Innovtype.newLink &&
            innov.nodeInId == nodeP1.nodeId &&
            innov.nodeOutId == nodeP2.nodeId &&
            innov.recurrentFlag == recurrentFlag,
      );

      if (existingInnov == null) {
        // This is a novel innovation
        // Choose a random trait
        traitNum = traits[neat.randInt(0, traits.length - 1)].traitId;

        // Choose a random weight
        newWeight = neat.randPosNeg() * neat.randFloat() * neat.weightMutPower;

        // Create the new innovation and add it to the list
        final newInnov = Innovation.makeAsNewLinkRecurrentType(
          nodeP1.nodeId,
          nodeP2.nodeId,
          currentInnovation,
          newWeight,
          traitNum,
          recurrentFlag,
        );
        innovations.add(newInnov);

        // Create the new gene
        newGene = Gene.makeFromNodes(
          neat,
          newWeight,
          nodeP1,
          nodeP2,
          recurrentFlag,
          currentInnovation,
          0,
        );

        currentInnovation++;
      } else {
        // A matching innovation was found, so we reuse its historical data
        newGene = Gene.makeFromNodes(
          neat,
          existingInnov.newWeight,
          nodeP1,
          nodeP2,
          recurrentFlag,
          existingInnov.innovationNum1,
          0,
        );
      }

      // Now add the new Genes to the Genome
      addGene(genes, newGene);
      return true;
    } else {
      return false;
    }
  }
}
