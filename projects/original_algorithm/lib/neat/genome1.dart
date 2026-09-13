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
class Genome1 {
  int genomeId = 0;

  List<Trait> traits = []; // parameter conglomerations
  List<NNode> nodes = []; // List of NNodes for the Network
  List<Gene> genes = []; // List of innovation-tracking genes

  // Allows Genome1 to be matched with its Network. Constructed in genesis()
  late Network phenotype;

  Genome1();

  factory Genome1.makeFromSpecs(
    int id,
    List<Trait> traits,
    List<NNode> nodes,
    List<Gene> genes,
  ) {
    var newGenome = Genome1()
      ..genomeId = id
      ..traits = traits
      ..nodes = nodes
      ..genes = genes;
    return newGenome;
  }

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
    // Iterates over attempts to find an unconnected pair of nodes
    int tryCount = 0;
    late NNode nodeP1; // Pointers to the nodes // TODO: check if used
    late NNode nodeP2; // Pointers to the nodes
    // List<Gene>::iterator thegene;             // Searches for existing link
    bool found = false; // Tells whether an open pair was found
    bool recurrentFlag = false; // Indicates whether proposed link is recurrent
    late Gene newGene; // The new Gene

    int traitNum = 0; // Random trait finder

    double newWeight = 0.0; // The new weight for the new link

    bool doRecur = false;
    bool loopRecur = false;
    int firstNonsensor = 0;

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

        // See if a recur link already exists  ALSO STOP AT END OF GENES!!!!
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
        nodeNum1 = neat.randInt(0, nodes.length - 1);
        nodeNum2 = neat.randInt(firstNonsensor, nodes.length - 1);

        // Directly access elements by their index.
        // Find the first node
        nodeP1 = nodes[nodeNum1];
        // Find the second node
        nodeP2 = nodes[nodeNum2];

        // See if a link already exists  ALSO STOP AT END OF GENES!!!!
        final bool linkInvalid =
            !nodeP2.isSensor() ||
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
          // if (count > thresh) {
          //   // cout<<"LOOP DETECTED DURING A RECURRENCY CHECK"<<std::endl;
          //   // return false;
          // }

          // Make sure it finds the right kind of link (recurrent or not)
          if (recurrentFlag) {
            tryCount++;
          } else {
            tryCount = tries;
            found = true;
          }
        }
      }
    } // End of normal link finding loop

    // Continue only if an open link was found
    if (found) {
      // If it was supposed to be recurrent, make sure it gets labeled that way
      if (doRecur) {
        recurrentFlag = true;
      }

      // Use firstWhereOrNull to find a historical innovation for this link.
      final existingInnov = innovations.firstWhereOrNull(
        (innov) =>
            innov.innovationType == Innovtype.newLink &&
            innov.nodeInId == nodeP1.nodeId &&
            innov.nodeOutId == nodeP2.nodeId &&
            innov.recurrentFlag == recurrentFlag,
      );

      if (existingInnov == null) {
        // CASE 1: This is a novel innovation.
        // Choose a random trait for the new gene.
        traitNum = traits[neat.randInt(0, traits.length - 1)].traitId;

        // Choose a random weight for the new link.
        newWeight = neat.randPosNeg() * neat.randFloat() * neat.weightMutPower;

        // Create the new innovation and add it to the master list.
        final newInnov = Innovation.makeAsNewLinkRecurrentType(
          nodeP1.nodeId,
          nodeP2.nodeId,
          currentInnovation,
          newWeight,
          traitNum,
          recurrentFlag,
        );
        innovations.add(newInnov);

        // Create the new gene using the new innovation number.
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
        // CASE 2: A matching innovation was found.
        // Reuse its historical data to create the new gene.
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
      addGene(genes, newGene); // Adds the gene in correct order
      return true;
    } else {
      return false;
    }
  }

  void mutateAddSensor(
    Neat neat,
    List<Innovation> innovations,
    double currentInnovation,
  ) {
    List<NNode> sensors = [];
    List<NNode> outputs = [];
    NNode sensor;

    double newWeight = 0.0;
    Gene newGene;

    bool found = false;

    int traitNum = 0;

    // Find all the sensors and outputs
    for (var node in nodes) {
      if (node.isSensor()) {
        sensors.add(node);
      } else if (node.genNodeLabel == Nodeplace.output) {
        outputs.add(node);
      }
    }

    // eliminate from contention any sensors that are already connected
    // A sensor is removed if it is already connected to all available output nodes.
    // sensors.removeWhere((sensor) { ... });:
    // This is the main method. It will iterate through each sensor in the sensors
    // list and remove it if the code block inside returns true.
    // outputs.every((output) => ...):
    // This is the core of the condition. The every method checks if every single
    // element in the outputs list satisfies the given test. It's a very concise way to ask,
    // "Is the following true for all outputs?"
    // genes.any((gene) => ...):
    // This is the test performed for each output. The any method checks if at
    // least one gene in the genes list satisfies the condition. It's how we
    // check for the existence of a specific link.
    // The Full Condition:
    // Putting it all together, the code reads like this:
    // "Remove a sensor if every output has any enabled gene connecting that sensor to that output."
    sensors.removeWhere((sensor) {
      // If there are no outputs, no sensor can be fully connected.
      if (outputs.isEmpty) {
        return false;
      }

      // Check if this sensor is connected to EVERY output node.
      // The `every` method returns true if the condition is met for all elements.
      return outputs.every(
        (output) => genes.any(
          (gene) =>
              gene.link.inNode == sensor &&
              gene.link.outNode == output &&
              gene.expressed,
        ),
      );
    });

    // If all sensors are connected, quit
    if (sensors.isEmpty) {
      return;
    }

    // Pick randomly from remaining sensors
    sensor = sensors[neat.randInt(0, sensors.length - 1)];

    // Add new links to chosen sensor, avoiding redundancy
    for (var output in outputs) {
      found = false;

      for (var gene in genes) {
        if (gene.link.inNode == sensor && gene.link.outNode == output) {
          found = true;
        }
      }

      // Record the innovation
      if (!found) {
        // First, search for a matching historical innovation without iterating.
        final existingInnov = innovations.firstWhereOrNull(
          (innov) =>
              innov.innovationType == Innovtype.newLink &&
              innov.nodeInId == sensor.nodeId &&
              innov.nodeOutId == output.nodeId &&
              !innov.recurrentFlag,
        );

        if (existingInnov == null) {
          // CASE 1: This is a novel innovation.
          // Choose a random trait and weight.
          traitNum = traits[neat.randInt(0, traits.length - 1)].traitId;
          newWeight =
              neat.randPosNeg() * neat.randFloat() * neat.weightMutPower;

          // Create the new innovation and add it to the master list.
          final newInnov = Innovation.makeAsNewLinkType(
            sensor.nodeId,
            output.nodeId,
            currentInnovation,
            newWeight,
            traitNum,
          );
          innovations.add(newInnov);

          // Create the new gene using the new innovation number.
          newGene = Gene.makeFromNodes(
            neat,
            newWeight,
            sensor,
            output,
            false, // Not recurrent
            currentInnovation,
            0,
          );

          currentInnovation++;
        } else {
          // CASE 2: A matching innovation was found.
          // Reuse its historical data to create the new gene.
          newGene = Gene.makeFromNodes(
            neat,
            existingInnov.newWeight,
            sensor,
            output,
            false,
            existingInnov.innovationNum1,
            0,
          );
        }

        addGene(genes, newGene); // adds the gene in correct order
      }
    }
  }

  Genome1 mateMultipoint(
    Neat neat,
    Genome1 g,
    int genomeid,
    double fitness1,
    double fitness2,
    bool interspeciesFlag,
  ) {
    // The baby Genome will contain these new Traits, NNodes, and Genes
    List<Trait> newTraits = [];
    List<NNode> newNodes = [];
    List<Gene> newGenes = [];

    // iterators for moving through the two parents' genes
    Iterator<Gene>? p1Gene;
    Iterator<Gene>? p2Gene;
    // Innovation numbers for genes inside parents' Genomes
    double p1Innov = 0.0;
    double p2Innov = 0.0;
    late Gene chosenGene; // Gene chosen for baby to inherit
    int traitNum; // Number of trait new gene points to
    NNode iNode; // NNodes connected to the chosen Gene
    NNode oNode;
    NNode newInode;
    NNode newOnode;

    bool disable = false; // Set to true if we want to disabled a chosen gene

    disable = false;
    Gene newGene;

    // Tells if the first genome (this one) has better fitness or not
    bool p1Better = false;

    bool skip = false;

    // First, average the Traits from the 2 parents to form the baby's Traits
    // It is assumed that trait lists are the same length
    // In the future, may decide on a different method for trait mating
    for (int i = 0; i < traits.length; ++i) {
      var newTrait = Trait.makeByAverage(neat, traits[i], (g.traits[i]));
      newTraits.add(newTrait);
    }

    // Figure out which genome is better
    // The worse genome should not be allowed to add extra structural baggage
    // If they are the same, use the smaller one's disjoint and excess genes only
    if (fitness1 == fitness2) {
      if (genes.length < (g.genes.length)) {
        p1Better = true;
      } else {
        p1Better = false;
      }
    } else {
      p1Better = fitness1 > fitness2;
    }

    // NEW 3/17/03 Make sure all sensors and outputs are included
    for (var currentNode in g.nodes) {
      if ((currentNode.genNodeLabel == Nodeplace.input) ||
          (currentNode.genNodeLabel == Nodeplace.bias) ||
          (currentNode.genNodeLabel == Nodeplace.output)) {
        int nodeTraitNum;
        if (currentNode.nodeTrait != null) {
          nodeTraitNum = 0;
        } else {
          nodeTraitNum = currentNode.nodeTrait!.traitId - traits.first.traitId;
        }

        // Create a new node off the sensor or output
        newOnode = NNode.makeFromTrait(currentNode, newTraits[nodeTraitNum]);
        newOnode.depth = currentNode.depth;

        // Add the new node
        nodeInsert(newNodes, newOnode);
      }
    }

    // Now move through the Genes of each parent until both genomes end
    p1Gene = genes.iterator;
    p2Gene = g.genes.iterator;

    while (!((p1Gene.current == genes.last) &&
        (p2Gene.current == g.genes.last))) {
      skip = false; // Default to not skipping a chosen gene

      if (p1Gene.current == genes.last) {
        chosenGene = p2Gene.current;
        p2Gene.moveNext();
        if (p1Better) skip = true; // Skip excess from the worse genome
      } else if (p2Gene.current == (g.genes).last) {
        chosenGene = p2Gene.current;
        p2Gene.moveNext();
        if (!p1Better) skip = true; // Skip excess from the worse genome
      } else {
        // Extract current innovation numbers
        p1Innov = p1Gene.current.innovationNum;
        p2Innov = p2Gene.current.innovationNum;

        if (p1Innov == p2Innov) {
          if (neat.randFloat() < 0.5) {
            chosenGene = p1Gene.current;
          } else {
            chosenGene = p2Gene.current;
          }

          // If one is disabled, the corresponding gene in the offspring
          // will likely be disabled
          if (((p1Gene.current.expressed) == false) ||
              ((p2Gene.current.expressed) == false)) {
            if (neat.randFloat() < 0.75) disable = true;
          }

          p1Gene.moveNext();
          p2Gene.moveNext();
        } else if (p1Innov < p2Innov) {
          chosenGene = p1Gene.current;
          p1Gene.moveNext();

          if (!p1Better) skip = true;
        } else if (p2Innov < p1Innov) {
          chosenGene = p2Gene.current;
          p2Gene.moveNext();

          if (p1Better) skip = true;
        }
      }

      //Uncomment this line to let growth go faster (from both parents excesses)
      // skip=false;

      //For interspecies mating, allow all genes through:
      // if (interspec_flag)
      //     skip=false;

      // Check to see if the chosenGene conflicts with an already chosen gene
      // i.e. do they represent the same link
      final curGene2 = newGenes.firstWhereOrNull(
        (gene) =>
            (gene.link.inNode!.nodeId == chosenGene.link.inNode!.nodeId &&
                gene.link.outNode!.nodeId == chosenGene.link.outNode!.nodeId &&
                gene.link.isRecurrent == chosenGene.link.isRecurrent) ||
            (gene.link.inNode!.nodeId == chosenGene.link.outNode!.nodeId &&
                gene.link.outNode!.nodeId == chosenGene.link.inNode!.nodeId &&
                !gene.link.isRecurrent &&
                !chosenGene.link.isRecurrent),
      );

      if (curGene2 != null && curGene2 != newGenes.last) {
        skip = true; // Links conflicts, abort adding
      }

      if (!skip) {
        // Now add the chosenGene to the baby

        // First, get the trait pointer
        if (!(chosenGene.link.linkTrait != null)) {
          traitNum = traits.first.traitId - 1;
        } else {
          // The subtracted number normalizes depending on whether traits start counting at 1 or 0
          traitNum = chosenGene.link.linkTrait!.traitId - traits.first.traitId;
        }

        // Next check for the nodes, add them if not in the baby Genome already
        iNode = chosenGene.link.inNode!;
        oNode = chosenGene.link.outNode!;

        // Check for iNode in the newnodes list
        if (iNode.nodeId < oNode.nodeId) {
          // ====== inode before onode ============

          // Checking for inode's existence
          var curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == iNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the input node doesn't exist so we have to add it
            // (normalized trait number for new NNode)

            int nodeTraitNum;
            if (iNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = iNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newInode = NNode.makeFromTrait(iNode, newTraits[nodeTraitNum]);
            newInode.depth = iNode.depth;
            nodeInsert(newNodes, newInode);
          } else {
            newInode = curnode;
          }

          // Checking for onode's existence
          curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == oNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the output node doesn't exist so we have to add it
            // normalized trait number for new NNode
            int nodeTraitNum;
            if (oNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = oNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newOnode = NNode.makeFromTrait(oNode, newTraits[nodeTraitNum]);
            newOnode.depth = oNode.depth;
            nodeInsert(newNodes, newOnode);
          } else {
            newOnode = curnode;
          }
        }
        // If the onode has a higher id than the inode we want to add it first
        else {
          // ====== onode before 1node ============

          // Checking for onode's existence
          var curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == oNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the output node doesn't exist so we have to add it
            // normalized trait number for new NNode
            int nodeTraitNum;
            if (oNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = oNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newOnode = NNode.makeFromTrait(oNode, newTraits[nodeTraitNum]);
            newOnode.depth = oNode.depth;
            nodeInsert(newNodes, newOnode);
          } else {
            newOnode = curnode;
          }

          // Checking for inode's existence
          curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == iNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the input node doesn't exist so we have to add it
            // (normalized trait number for new NNode)

            int nodeTraitNum;
            if (iNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = iNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newInode = NNode.makeFromTrait(iNode, newTraits[nodeTraitNum]);
            newInode.depth = iNode.depth;
            nodeInsert(newNodes, newInode);
          } else {
            newInode = curnode;
          }
        } // End NNode checking section- NNodes are now in new Genome

        // Add the Gene
        newGene = Gene.makeFromGene(
          neat,
          chosenGene,
          newTraits[traitNum],
          newInode,
          newOnode,
        );

        if (disable) {
          newGene.expressed = false;
          disable = false;
        }

        newGenes.add(newGene);
      }
    }

    var newGenome = Genome1.makeFromSpecs(
      genomeid,
      newTraits,
      newNodes,
      newGenes,
    );

    // Return the baby Genome
    return newGenome;
  }

  void nodeInsert(List<NNode> nlist, NNode n) {
    // Use lowerBound from package:collection to find the insertion point.
    // This performs a binary search, which is very efficient (O(log n)).
    final index = lowerBound(
      nlist,
      n,
      compare: (a, b) => a.nodeId.compareTo(b.nodeId),
    );

    // Insert the gene at the found index to maintain sort order.
    nlist.insert(index, n);
  }

  Genome1 mateMultipointAvg(
    Neat neat,
    Genome1 g,
    int genomeId,
    double fitness1,
    double fitness2,
    bool interspecFlag,
  ) {
    // The baby Genome will contain these new Traits, NNodes, and Genes
    List<Trait> newTraits = [];
    List<NNode> newNodes = [];
    List<Gene> newGenes = [];

    Trait newTrait;

    Iterator<Gene> curGene2; // Checking for link duplication

    // iterators for moving through the two parents' genes
    Iterator<Gene> p1Gene;
    Iterator<Gene> p2Gene;

    double p1Innov; // Innovation numbers for genes inside parents' Genomes
    double p2Innov;
    late Gene chosenGene; // Gene chosen for baby to inherit
    int traitNum; // Number of trait new gene points to
    NNode iNode; // NNodes connected to the chosen Gene
    NNode oNode;
    NNode newInode;
    NNode newOnode;

    int nodeTraitNum; // Trait number for a NNode

    // This Gene is used to hold the average of the two genes to be averaged
    Gene avgGene;

    Gene newGene;

    bool skip;

    bool p1Better; // Designate the better genome

    // First, average the Traits from the 2 parents to form the baby's Traits
    // It is assumed that trait lists are the same length
    // In future, could be done differently
    for (int i = 0; i < traits.length; ++i) {
      newTrait = Trait.makeByAverage(neat, traits[i], g.traits[i]);
      newTraits.add(newTrait);
    }

    // Set up the avgGene
    avgGene = Gene.makeFromTrait(neat, null, 0, null, null, false, 0, 0);

    // NEW 3/17/03 Make sure all sensors and outputs are included
    for (var curnode in g.nodes) {
      if ((curnode.genNodeLabel == Nodeplace.input) ||
          (curnode.genNodeLabel == Nodeplace.output) ||
          (curnode.genNodeLabel == Nodeplace.bias)) {
        if (curnode.nodeTrait == null) {
          nodeTraitNum = 0;
        } else {
          nodeTraitNum = curnode.nodeTrait!.traitId - traits.first.traitId;
        }

        // Create a new node off the sensor or output
        newOnode = NNode.makeFromTrait(curnode, newTraits[nodeTraitNum]);
        newOnode.depth = curnode.depth;

        // Add the new node
        nodeInsert(newNodes, newOnode);
      }
    }

    // Figure out which genome is better
    // The worse genome should not be allowed to add extra structural baggage
    // If they are the same, use the smaller one's disjoint and excess genes only
    if (fitness1 > fitness2) {
      p1Better = true;
    } else if (fitness1 == fitness2) {
      if (genes.length < g.genes.length) {
        p1Better = true;
      } else {
        p1Better = false;
      }
    } else {
      p1Better = false;
    }

    // Now move through the Genes of each parent until both genomes end
    p1Gene = genes.iterator;
    p2Gene = g.genes.iterator;

    while (!((p1Gene.current == genes.last) &&
        p2Gene.current == g.genes.last)) {
      avgGene.expressed = true; // Default to enabled

      skip = false;

      if (p1Gene.current == genes.last) {
        chosenGene = p2Gene.current;

        p2Gene.moveNext();

        if (p1Better) skip = true;
      } else if (p2Gene.current == g.genes.last) {
        chosenGene = p1Gene.current;

        p1Gene.moveNext();

        if (!p1Better) skip = true;
      } else {
        // Extract current innovation numbers
        p1Innov = p1Gene.current.innovationNum;
        p2Innov = p2Gene.current.innovationNum;

        if (p1Innov == p2Innov) {
          // Average them into the avgGene
          if (neat.randFloat() > 0.5) {
            avgGene.link.linkTrait = p1Gene.current.link.linkTrait;
          } else {
            avgGene.link.linkTrait = p2Gene.current.link.linkTrait;
          }

          // WEIGHTS AVERAGED HERE
          avgGene.link.weight =
              (p1Gene.current.link.weight + p2Gene.current.link.weight) / 2.0;

          if (neat.randFloat() > 0.5) {
            avgGene.link.inNode = p1Gene.current.link.inNode;
          } else {
            avgGene.link.inNode = p2Gene.current.link.inNode;
          }

          if (neat.randFloat() > 0.5) {
            avgGene.link.outNode = p1Gene.current.link.outNode;
          } else {
            avgGene.link.outNode = p2Gene.current.link.outNode;
          }

          if (neat.randFloat() > 0.5) {
            avgGene.link.isRecurrent = p1Gene.current.link.isRecurrent;
          } else {
            avgGene.link.isRecurrent = p2Gene.current.link.isRecurrent;
          }

          avgGene.innovationNum = p1Gene.current.innovationNum;
          avgGene.mutationNum =
              (p1Gene.current.mutationNum + p2Gene.current.mutationNum) / 2.0;

          if (((p1Gene.current.expressed) == false) ||
              ((p2Gene.current.expressed) == false)) {
            if (neat.randFloat() < 0.75) {
              avgGene.expressed = false;
            }
          }

          chosenGene = avgGene;
          p1Gene.moveNext();
          p2Gene.moveNext();
        } else if (p1Innov < p2Innov) {
          chosenGene = p1Gene.current;

          p1Gene.moveNext();

          if (!p1Better) skip = true;
        } else if (p2Innov < p1Innov) {
          chosenGene = p2Gene.current;

          p2Gene.moveNext();

          if (p1Better) skip = true;
        }
      }

      // Check to see if the chosenGene conflicts with an already chosen gene
      // i.e. do they represent the same link
      curGene2 = newGenes.iterator;

      while ((curGene2.current != newGenes.last)) {
        if ((curGene2.current.link.inNode!.nodeId ==
                    chosenGene.link.inNode!.nodeId) &&
                (curGene2.current.link.outNode!.nodeId ==
                    chosenGene.link.outNode!.nodeId) &&
                (curGene2.current.link.isRecurrent ==
                    chosenGene.link.isRecurrent) ||
            (curGene2.current.link.outNode!.nodeId ==
                    chosenGene.link.inNode!.nodeId) &&
                (curGene2.current.link.inNode!.nodeId ==
                    chosenGene.link.outNode!.nodeId) &&
                (!curGene2.current.link.isRecurrent &&
                    !chosenGene.link.isRecurrent)) {
          skip = true;
        }

        curGene2.moveNext();
      }

      if (!skip) {
        // Now add the chosengene to the baby

        // First, get the trait pointer
        if (chosenGene.link.linkTrait == null) {
          traitNum = traits.first.traitId - 1;
        } else {
          // The subtracted number normalizes depending on whether traits start counting at 1 or 0
          traitNum = chosenGene.link.linkTrait!.traitId - traits.first.traitId;
        }

        // Next check for the nodes, add them if not in the baby Genome already
        iNode = chosenGene.link.inNode!;
        oNode = chosenGene.link.outNode!;

        // Check for inode in the newnodes list
        if (iNode.nodeId < oNode.nodeId) {
          var curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == iNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the node doesn't exist so we have to add it
            // normalized trait number for new NNode

            if (iNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = iNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newInode = NNode.makeFromTrait(iNode, newTraits[nodeTraitNum]);
            newInode.depth = iNode.depth;

            nodeInsert(newNodes, newInode);
          } else {
            newInode = curnode;
          }

          curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == oNode.nodeId,
          );

          if (curnode == null) {
            if (oNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = oNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newOnode = NNode.makeFromTrait(oNode, newTraits[nodeTraitNum]);
            newOnode.depth = oNode.depth;

            nodeInsert(newNodes, newOnode);
          } else {
            newOnode = curnode;
          }
        } // If the onode has a higher id than the inode we want to add it first
        else {
          // Checking for onode's existence
          var curnode = newNodes.firstWhereOrNull(
            (node) => node.nodeId == oNode.nodeId,
          );

          if (curnode == null) {
            // Here we know the node doesn't exist so we have to add it
            // normalized trait number for new NNode
            if (oNode.nodeTrait == null) {
              nodeTraitNum = 0;
            } else {
              nodeTraitNum = oNode.nodeTrait!.traitId - traits.first.traitId;
            }

            newOnode = NNode.makeFromTrait(oNode, newTraits[nodeTraitNum]);
            newOnode.depth = oNode.depth;

            nodeInsert(newNodes, newOnode);
          } else {
            newOnode = curnode;
          }
        }

        var curnode = newNodes.firstWhereOrNull(
          (node) => node.nodeId == iNode.nodeId,
        );

        // Checking for inode's existence
        if (curnode == null) {
          // Here we know the node doesn't exist so we have to add it
          // normalized trait number for new NNode

          if (iNode.nodeTrait == null) {
            nodeTraitNum = 0;
          } else {
            nodeTraitNum = iNode.nodeTrait!.traitId - traits.first.traitId;
          }

          newInode = NNode.makeFromTrait(iNode, newTraits[nodeTraitNum]);
          newInode.depth = iNode.depth;

          nodeInsert(newNodes, newInode);
        } else {
          newInode = curnode;
        } // End NNode checking section- NNodes are now in new Genome

        // Add the Gene
        newGene = Gene.makeFromGene(
          neat,
          chosenGene,
          newTraits[traitNum],
          newInode,
          newOnode,
        );

        newGenes.add(newGene);
      } // End if which checked for link duplicationb
    }

    var newGenome = Genome1.makeFromSpecs(
      genomeId,
      newTraits,
      newNodes,
      newGenes,
    );

    // Return the baby Genome
    return newGenome;
  }

  Genome1 mateSinglePoint(Neat neat, Genome1 g, int genomeId) {
    // The baby Genome will contain these new Traits, NNodes, and Genes
    List<Trait> newTraits = [];
    List<NNode> newNodes = [];
    List<Gene> newGenes = [];

    // iterators for moving through the two parents' genes
    Iterator<Gene> p1Gene;
    Iterator<Gene> p2Gene;
    Iterator<Gene> stopper; // To tell when finished
    Iterator<Gene> p2Stop;
    Iterator<Gene> p1Stop;
    // Innovation numbers for genes inside parents' Genomes
    double p1Innov = 0.0;
    double p2Innov = 0.0;
    Gene chosenGene; // Gene chosen for baby to inherit
    int traitNum = 0; // Number of trait new gene points to
    NNode iNode; // NNodes connected to the chosen Gene
    NNode oNode;
    NNode newInode;
    NNode newOnode;
    // curnode; For checking if NNodes exist already
    int nodeTraitNum = 0; // Trait number for a NNode

    int crosspoint = 0; // The point in the Genome to cross at
    int geneCounter = 0; // Counts up to the crosspoint
    bool skip = false; // Used for skipping unwanted genes

    // First, average the Traits from the 2 parents to form the baby's Traits
    // It is assumed that trait lists are the same length
    for (int i = 0; i < traits.length; ++i) {
      var newTrait = Trait.makeByAverage(
        neat,
        traits[i],
        g.traits[i],
      ); // Construct by averaging

      newTraits.add(newTrait);
    }

    // Set up the avgene
    // This Gene is used to hold the average of the two genes to be averaged
    var avgGene = Gene.makeFromTrait(neat, null, 0, null, null, false, 0, 0);

    // Determine which genome is smaller to find the valid range for the crosspoint.
    // "this" = parent 1
    // g.genes = parent 2
    final bool g1IsSmaller = genes.length < g.genes.length;
    final int smallerSize = g1IsSmaller ? genes.length : g.genes.length;

    // If the smaller genome is empty, mating is not possible.
    if (smallerSize == 0) {
      // In a real implementation, you might return null or an empty genome.
      // For now, we'll just exit.
      return Genome1.makeFromSpecs(genomeId, newTraits, newNodes, newGenes);
    }

    // Calculate a random crossover point within the smaller genome's size.
    crosspoint = neat.randInt(0, smallerSize - 1);

    // Get iterators for both parents. There's no need for "end" iterators in Dart.
    // The loop condition will be based on the boolean result of `moveNext()`.
    if (g1IsSmaller) {
      p1Gene = genes.iterator;
      p2Gene = g.genes.iterator;
    } else {
      p2Gene = genes.iterator;
      p1Gene = g.genes.iterator;
    }

    geneCounter = 0; // Ready to count towards crosspoint

    skip = false; // Default to not skip a Gene
    // Note that we skip when we are on the wrong Genome before
    // crossing

    // Pick the chosengene depending on whether we've crossed yet
    // Now move through the Genes of each parent until both genomes end
    // Mate up to the crossover point, taking genes from the first parent.
    while (geneCounter < crosspoint && p1Gene.moveNext() && p2Gene.moveNext()) {
      chosenGene = p1Gene.current;
      // In a full implementation, you would add logic here to create
      // a copy of the chosenGene and its nodes for the new genome.
      newGenes.add(Gene.makeCopy(neat, chosenGene));
      geneCounter++;
    }

    // After the crossover point, take all remaining genes from the second parent.
    while (p2Gene.moveNext()) {
      chosenGene = p2Gene.current;
      // Add logic here to create a copy of the chosenGene and its nodes.
      newGenes.add(Gene.makeCopy(neat, chosenGene));
    }

    // The code below would be part of a full implementation to build the final genome.
    // For now, it demonstrates how the created genes would be used.
    var newGenome = Genome1.makeFromSpecs(
      genomeId,
      newTraits,
      newNodes, // Note: newNodes is currently empty, needs to be populated
      newGenes,
    );

    return newGenome;
  }
}
