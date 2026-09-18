import 'package:flutter/foundation.dart';
import 'package:original_algorithm/neat/gene.dart';
import 'package:original_algorithm/neat/innovation.dart';
import 'package:original_algorithm/neat/iterator_genes_list.dart';
import 'package:original_algorithm/neat/iterator_innovations_list.dart';
import 'package:original_algorithm/neat/link.dart';
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
class Genome {
  int genomeId = 0;

  List<Trait> traits = []; // parameter conglomerations
  List<NNode> nodes = []; // List of NNodes for the Network
  List<Gene> genes = []; // List of innovation-tracking genes

  // Allows Genome to be matched with its Network. Constructed in genesis()
  Network? phenoType;

  Genome();

  factory Genome.makeCopy(Neat neat, Genome genome) {
    var newGenome = Genome()..genomeId = genome.genomeId;

    for (var trait in genome.traits) {
      var newTrait = Trait.makeCopy(trait);
      newGenome.traits.add(newTrait);
    }

    // Duplicating nodes
    for (final curNode in genome.nodes) {
      // First, find the trait that this node points to
      final assocTrait = curNode.nodeTrait == null
          ? null
          : newGenome.traits.firstWhereOrNull(
              (t) => t.traitId == curNode.nodeTrait!.traitId,
            );

      final newNode = NNode.makeFromTrait(curNode, assocTrait);
      curNode.dup = newNode; // Remember this node's old copy
      newGenome.nodes.add(newNode);
    }

    // Duplicate Genes
    for (final curGene in genome.genes) {
      // First find the nodes connected by the gene's link
      var iNode = curGene.link.inNode!.dup!;
      var oNode = curGene.link.outNode!.dup!;

      final assocTrait = curGene.link.linkTrait == null
          ? null
          : newGenome.traits.firstWhereOrNull(
              (t) => t.traitId == curGene.link.linkTrait!.traitId,
            );

      final newGene = Gene.makeFromGene(
        neat,
        curGene,
        assocTrait,
        iNode,
        oNode,
      );
      newGenome.genes.add(newGene);
    }

    return newGenome;
  }

  factory Genome.makeFromSpecs(
    int id,
    List<Trait> traits,
    List<NNode> nodes,
    List<Gene> genes,
  ) {
    var newGenome = Genome()
      ..genomeId = id
      ..traits = traits
      ..nodes = nodes
      ..genes = genes;
    return newGenome;
  }

  factory Genome.makeFromLinks(
    Neat neat,
    int id,
    List<Trait> traits,
    List<NNode> nodes,
    List<Link> links,
  ) {
    var newGenome = Genome()
      ..genomeId = id
      ..traits = traits
      ..nodes = nodes;

    // We go through the links and turn them into original genes.
    for (var link in links) {
      var gene = Gene.makeFromTrait(
        neat,
        link.linkTrait,
        link.weight,
        link.inNode,
        link.outNode,
        link.isRecurrent,
        1.0,
        0.0,
      );
      newGenome.genes.add(gene);
    }

    return newGenome;
  }

  factory Genome.makeFromTypes(
    Neat neat,
    int numIn,
    int numOut,
    int numHidden,
    int type,
  ) {
    var newGenome = Genome();

    // Temporary lists of nodes
    List<NNode> inputs = [];
    List<NNode> outputs = [];
    List<NNode> hidden = [];
    late NNode bias; // Remember the bias

    // For creating the new genes
    NNode newnode;
    Gene newgene;
    Trait newtrait;

    double innovation = 0.0;
    double weight = 0.0;
    double mutationNum = 0.0;

    // Assign the id 0
    newGenome.genomeId = 0;

    // Create a dummy trait (this is for future expansion of the system)
    newtrait = Trait.makeFromParams(neat, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    newGenome.traits.add(newtrait);

    // Adjust hidden number
    numHidden = type == 0 ? 0 : numIn * numOut;

    // Create the inputs and outputs

    // Build the input nodes
    for (var ncount = 1; ncount <= numIn; ncount++) {
      if (ncount < numIn) {
        newnode = NNode.makeFromPlacement(
          Nodetype.sensor,
          ncount,
          Nodeplace.input,
        );
      } else {
        newnode = NNode.makeFromPlacement(
          Nodetype.sensor,
          ncount,
          Nodeplace.bias,
        );
        bias = newnode;
      }

      // newnode.nodetrait=newtrait;
      newnode.depth = 0.0;

      // Add the node to the list of nodes
      newGenome.nodes.add(newnode);
      inputs.add(newnode);
    }

    // Build the hidden nodes
    for (var ncount = numIn + 1; ncount <= numIn + numHidden; ncount++) {
      newnode = NNode.makeFromPlacement(
        Nodetype.neuron,
        ncount,
        Nodeplace.hidden,
      );
      // newnode.nodetrait=newtrait;
      newnode.depth = 0.5; // Hidden nodes at depth 0.5
      // Add the node to the list of nodes
      newGenome.nodes.add(newnode);
      hidden.add(newnode);
    }

    // Build the output nodes
    for (
      var ncount = numIn + numHidden + 1;
      ncount <= numIn + numHidden + numOut;
      ncount++
    ) {
      newnode = NNode.makeFromPlacement(
        Nodetype.neuron,
        ncount,
        Nodeplace.output,
      );
      // newnode.nodetrait=newtrait;
      newnode.depth = 1.0;
      // Add the node to the list of nodes
      newGenome.nodes.add(newnode);
      outputs.add(newnode);
    }

    // Create the links depending on the type
    if (type == 0) {
      // Just connect inputs straight to outputs

      innovation = 1;

      // Loop over the outputs
      for (var outputNode in outputs) {
        // Loop over the inputs
        for (var inputNode in inputs) {
          // Connect each input to each output
          newgene = Gene.makeFromTraitRecurrent(
            neat,
            newtrait,
            weight,
            inputNode,
            outputNode,
            innovation,
            mutationNum,
          );

          // Add the gene to the genome
          newGenome.genes.add(newgene);

          innovation++;
        }
      }
    } // end type 0
    // ===___===___===___===___===___===___===___===___===___===___
    // A split link from each input to each output
    else if (type == 1) {
      innovation = 1; // Start the gene number counter

      // One hidden for ever input-output pair
      var hiddenNode = hidden.iterator;

      // Loop over the outputs
      for (var outputNode in outputs) {
        // Loop over the inputs
        for (var inputNode in inputs) {
          // Connect Input to hidden
          newgene = Gene.makeFromTraitNonRecurrent(
            neat,
            newtrait,
            weight,
            inputNode,
            outputNode,
            innovation,
            mutationNum,
          );

          // Add the gene to the genome
          newGenome.genes.add(newgene);

          innovation++; // Next gene

          // Connect hidden to output
          newgene = Gene.makeFromTraitNonRecurrent(
            neat,
            newtrait,
            weight,
            hiddenNode.current,
            outputNode,
            innovation,
            mutationNum,
          );
          // Add the gene to the genome
          newGenome.genes.add(newgene);

          hiddenNode.moveNext(); // Next hidden node
          innovation++; // Next gene (new innovation)
        }
      }
    } // end type 1
    // ===___===___===___===___===___===___===___===___===___===___
    // Fully connected
    else if (type == 2) {
      innovation = 1; // Start gene counter at 1

      // ==========================================
      // Connect all inputs to all hidden nodes
      // ==========================================
      for (var hiddenNode in hidden) {
        // Loop over the inputs
        for (var inputNode in inputs) {
          // Connect each input to each hidden
          newgene = Gene.makeFromTraitNonRecurrent(
            neat,
            newtrait,
            weight,
            inputNode,
            hiddenNode,
            innovation,
            mutationNum,
          );

          // Add the gene to the genome
          newGenome.genes.add(newgene);

          innovation++;
        }
      }

      // ==========================================
      // Connect all hidden units to all outputs
      // ==========================================
      for (var outputNode in outputs) {
        // Loop over the inputs
        for (var hiddenNode in hidden) {
          // Connect each input to each hidden
          newgene = Gene.makeFromTraitNonRecurrent(
            neat,
            newtrait,
            weight,
            hiddenNode,
            outputNode,
            innovation,
            mutationNum,
          );

          // Add the gene to the genome
          newGenome.genes.add(newgene);

          innovation++;
        }
      }

      // ==========================================
      // Connect the bias to all outputs
      // ==========================================
      for (var outputNode in outputs) {
        newgene = Gene.makeFromTraitNonRecurrent(
          neat,
          newtrait,
          weight,
          bias,
          outputNode,
          innovation,
          mutationNum,
        );

        // Add the gene to the genome
        newGenome.genes.add(newgene);

        innovation++;
      }

      // ==========================================
      // Recurrently connect the hidden nodes
      // ==========================================
      for (var hiddenNode1 in hidden) {
        // Loop Over all Hidden
        for (var hiddenNode2 in hidden) {
          // Connect each hidden to each hidden
          newgene = Gene.makeFromTraitRecurrent(
            neat,
            newtrait,
            weight,
            hiddenNode2,
            hiddenNode1,
            innovation,
            mutationNum,
          );

          // Add the gene to the genome
          newGenome.genes.add(newgene);

          innovation++;
        }
      }
    } // end type 2

    return newGenome;
  }

  factory Genome.makeFromFile(Neat neat, int id, List<String> lines) {
    var genome = Genome()..genomeId = id;

    List<String> fields;
    for (var i = 1; i < lines.length - 1; i++) {
      fields = lines[i].split(' ');

      if (fields.isEmpty) continue;

      if (kDebugMode) print("${fields[0]} line");

      if (fields[0] == "genomeend") {
        int idCheck = int.parse(fields[1]);
        if (idCheck != genome.genomeId) {
          if (kDebugMode) {
            print(
              "ERROR: id mismatch in genome. Got: $idCheck Expected: ${genome.genomeId}",
            );
          }
        }
        break;
      }
      // Ignore genomestart if it hasn't been gobbled yet
      else if (fields[0] == "genomestart") {
        if (kDebugMode) print("genomestart\n");
      }
      // Read in a trait
      else if (fields[0] == "trait") {
        // Allocate the new trait
        var newtrait = Trait.makeFromLine(neat, lines[i]);

        // Add the trait to the list of traits
        genome.traits.add(newtrait);
      }
      // Read in a node
      else if (fields[0] == "node") {
        // Allocate the new node
        var node = NNode.makeFromLine(lines[i], genome.traits);

        // Add the node to the list of nodes
        genome.nodes.add(node);
      }
      // Read in a gene
      else if (fields[0] == "gene") {
        // Allocate the new gene
        var gene = Gene.makeFromLine(
          neat,
          lines[i],
          genome.traits,
          genome.nodes,
        );

        // Add the gene to the genome
        genome.genes.add(gene);
      }
    }

    return genome;
  }

  int getLastNodeId() {
    if (nodes.isEmpty) {
      return -1; // Or handle as an error, returning -1 is an error
    }
    return nodes.last.nodeId + 1;
  }

  double getLastGeneInnovnum() {
    if (genes.isEmpty) {
      return -1.0; // Or handle as an error, returning -1 is an error
    }
    return genes.last.innovationNum + 1;
  }

  Network genesis(Neat neat, int id) {
    // neat.log("########### Genome.genesis ############ ID: ", id);

    // Compute the maximum weight for adaptation purposes
    double maxweight = 0.0;

    // Inputs and outputs will be collected here for the network
    // All nodes are collected in an all_list-
    // this will be used for later safe destruction of the net
    List<NNode> inList = [];
    List<NNode> outList = [];
    List<NNode> allList = [];

    // Create the nodes
    for (var curNode in nodes) {
      var newnode = NNode.makeFromType(curNode.type, curNode.nodeId);

      // Derive the node parameters from the trait pointed to
      var curtrait = curNode.nodeTrait;
      newnode.deriveTrait(neat, curtrait);

      // Check for input or output designation of node
      if ((curNode.genNodeLabel) == Nodeplace.input) {
        inList.add(newnode);
      } else if ((curNode.genNodeLabel) == Nodeplace.bias) {
        inList.add(newnode);
      } else if ((curNode.genNodeLabel) == Nodeplace.output) {
        outList.add(newnode);
      }

      // Keep track of all nodes, not just input and output
      allList.add(newnode);

      // Have the node specifier point to the node it generated
      curNode.analogue = newnode;
    }

    // Create the links by iterating through the genes
    for (var curgene in genes) {
      // Only create the link if the gene is expressedd/expressed
      if (curgene.expressed) {
        var curlink = curgene.link;
        var inode = curlink.inNode!.analogue;
        var onode = curlink.outNode!.analogue;
        // NOTE: This line could be run through a recurrency check if desired
        //  (no need to in the current implementation of NEAT)
        var newlink = Link.makeFromNodes(
          neat,
          curlink.weight,
          inode,
          onode,
          curlink.isRecurrent,
        );

        onode!.incoming.add(newlink);
        inode!.outgoing.add(newlink);

        newlink.deriveTrait(neat, curlink.linkTrait);

        // Keep track of maximum weight
        double weightMag = (newlink.weight).abs();
        if (weightMag > maxweight) {
          maxweight = weightMag;
        }
      }
    }

    // The new network
    var newnet = Network.makeUnAdaptable(inList, outList, allList, id);

    // Attach genotype and phenotype together
    // A Network can still hold a shared_ptr to its Genome
    newnet.genoType = this;

    phenoType = newnet;

    newnet.maxweight = maxweight;

    return newnet;
  }

  Genome duplicate(Neat neat, int newId) {
    // neat.log("########### Genome::duplicate START ############ ID: ", newId);

    // Collections for the new Genome
    List<Trait> traitsDup = [];
    List<NNode> nodesDup = [];
    List<Gene> genesDup = [];

    // Duplicate the traits
    for (var trait in traits) {
      var newtrait = Trait.makeCopy(trait);
      traitsDup.add(newtrait);
    }

    // Duplicate NNodes
    for (var node in nodes) {
      Trait? assocTrait;
      // First, find the trait that this node points to
      if (node.nodeTrait != null) {
        final it = traitsDup.firstWhereOrNull(
          (t) => t.traitId == node.nodeTrait!.traitId,
        );

        if (it != null) {
          assocTrait = it;
        }
      }

      var newnode = NNode.makeFromTrait(node, assocTrait);

      node.dup = newnode; // Remember this node's old copy
      nodesDup.add(newnode);
    }

    // Duplicate Genes
    for (var gene in genes) {
      Trait? assocTrait;
      // First find the nodes connected by the gene's link
      var iNode = gene.link.inNode!.dup;
      var oNode = gene.link.outNode!.dup;

      // Get a pointer to the trait expressed by this gene
      var traitptr = gene.link.linkTrait;
      if (traitptr != null) {
        final it = traitsDup.firstWhereOrNull(
          (t) => t.traitId == traitptr.traitId,
        );

        if (it != null) {
          assocTrait = it;
        }
      }

      var newgene = Gene.makeFromGene(neat, gene, assocTrait, iNode, oNode);
      genesDup.add(newgene);
    }

    // Finally, return the genome
    var newgenome = Genome.makeFromSpecs(newId, traitsDup, nodesDup, genesDup);
    // neat.log("########### Genome::duplicate END ############ ID: ", newId);

    return newgenome;
  }

  bool verify() {
    // Check each gene's nodes
    for (var gene in genes) {
      var iNode = gene.link.inNode;
      var oNode = gene.link.outNode;

      // Look for inode
      //             final it = traitsDup.firstWhereOrNull(
      //   (t) => t.traitId == node.nodeTrait!.traitId,
      // );
      if (!nodes.contains(iNode)) {
        return false;
      }

      if (!nodes.contains(oNode)) {
        return false;
      }

      // If the list is kept sorted (like in
      // addGene
      //  and
      // addNode
      // ):
      // Use binarySearch from package:collection:
      //
      //       final index = binarySearch(
      //   glist,
      //   targetGene,
      //   compare: (a, b) => a.innovationNum.compareTo(b.innovationNum),
      // ); // returns -1 if not found, or the exact index if found
    }

    // Check for NNodes being out of order
    int lastId = 0;
    for (var node in nodes) {
      if (node.nodeId < lastId) {
        return false;
      }
      lastId = node.nodeId;
    }

    // Make sure there are no duplicate genes
    // for (var gene1 in genes) {
    //   for (var gene2 in genes) {
    //     if (gene1 != gene2 &&
    //         (gene1.link.isRecurrent == gene2.link.isRecurrent) &&
    //         (gene1.link.inNode!.nodeId == gene2.link.inNode!.nodeId) &&
    //         (gene1.link.outNode!.nodeId == gene2.link.outNode!.nodeId)) {
    //       // Duplicate gene found, which might indicate an issue.
    //       // Depending on the desired strictness, you might return false here.
    //       // std::cout << "Duplicate Gene found: in(" << gene1.link.inNode!.nodeId << ") out(" << gene1.link.outNode!.nodeId << ")" << std::endl;
    //     }
    //   }
    // }

    // Check for 2 non-expressed/disables in a row
    // Note:  Again, this is not necessarily a bad sign
    if (nodes.length >= 500) {
      bool prevDisabled = false;
      for (var gene in genes) {
        if (!gene.expressed && prevDisabled) {
          // cout<<"ALERT: 2 DISABLES IN A ROW: "<<this<<endl;
        }
        prevDisabled = !gene.expressed;
      }
    }

    return true;
  }

  void mutateRandomTrait(Neat neat) {
    // neat.log("Genome::mutate_randomTrait: size= ", (int)traits.length);
    // Choose a random traitNum
    int traitNum = neat.randInt(0, traits.length - 1);

    // Retrieve the trait and mutate it. Trait to be mutated
    traits[traitNum].mutate(neat);

    // TRACK INNOVATION? (future possibility)
  }

  void mutateLinkTrait(Neat neat, int times) {
    for (var loop = 1; loop <= times; loop++) {
      // Choose a random traitnum for attachment
      int traitNum = neat.randInt(0, traits.length - 1);
      var thetrait = traits[traitNum];

      // Choose a random gene to mutate
      int genenum = neat.randInt(0, genes.length - 1);
      var thegene = genes[genenum];

      // Do not alter frozen genes
      if (!thegene.frozen) {
        thegene.link.linkTrait = thetrait; // Attachment
      }
    }
  }

  void mutateNodeTrait(Neat neat, int times) {
    for (var loop = 1; loop <= times; loop++) {
      // Choose a random trait number
      int traitnum = neat.randInt(0, traits.length - 1);

      // Choose a random node number
      int nodenum = neat.randInt(0, nodes.length - 1);

      var thenode = nodes[nodenum];
      // Do not mutate frozen nodes
      if (!thenode.frozen) {
        var thetrait = traits[traitnum];

        // set the trait to point to the new trait
        thenode.nodeTrait = thetrait;
      }
    }
  }

  void mutateLinkWeights(
    Neat neat,
    double power,
    double rate,
    Mutator mutType,
  ) {
    var severe = neat.randFloat() > 0.5;

    // Go through all the Genes and perturb their link's weights
    double num = 0.0;
    var geneTotal = genes.length;
    var endpart = geneTotal * 0.8;
    // powermod=randposneg()*power*randfloat();  //Make power of mutation random
    // powermod=randfloat();
    var powermod = 1.0;

    // Loop on all genes  (ORIGINAL METHOD)
    for (var curgene in genes) {
      // Possibility: Have newer genes mutate with higher probability
      // Only make mutation power vary along genome if it's big enough
      // if (geneTotal>=10.0) {
      // This causes the mutation power to go up towards the end up the genome
      // powermod=((power-0.7)/geneTotal)*num+0.7;
      // }
      // else powermod=power;

      // The following if determines the probabilities of doing cold gaussian
      // mutation, meaning the probability of replacing a link weight with
      // another, entirely random weight.  It is meant to bias such mutations
      // to the tail of a genome, because that is where less time-tested genes
      // reside.  The gausspoint and coldgausspoint represent values above
      // which a random float will signify that kind of mutation.

      // Don't mutate weights of frozen links
      if (!curgene.frozen) {
        double gausspoint = 0.0;
        double coldgausspoint = 0.0;
        if (severe) {
          gausspoint = 0.3;
          coldgausspoint = 0.1;
        } else if (geneTotal >= 10.0 && num > endpart) {
          gausspoint = 0.5; // Mutate by modification % of connections
          coldgausspoint = 0.3; // Mutate the rest by replacement % of the time
        } else {
          // Half the time don't do any cold mutations
          if (neat.randFloat() > 0.5) {
            gausspoint = 1.0 - rate;
            coldgausspoint = 1.0 - rate - 0.1;
          } else {
            gausspoint = 1.0 - rate;
            coldgausspoint = 1.0 - rate;
          }
        }

        // Possible methods of setting the perturbation:
        // randnum=gaussrand()*powermod;
        // randnum=gaussrand();

        double randNum =
            neat.randPosNeg() * neat.randFloat() * power * powermod;
        // std::cout << "RANDOM: " << randnum << " " << randposneg() << " " << randfloat() << " " << power << " " << powermod << std::endl;

        if (mutType == Mutator.gaussian) {
          double randchoice = neat.randFloat();
          if (randchoice > gausspoint) {
            curgene.link.weight += randNum;
          } else if (randchoice > coldgausspoint) {
            curgene.link.weight = randNum;
          }
        } else if (mutType == Mutator.coldgaussian) {
          curgene.link.weight = randNum;
        }

        // Cap the weights at 8.0 (experimental)
        if (curgene.link.weight > 8.0) {
          curgene.link.weight = 8.0;
        } else if (curgene.link.weight < -8.0) {
          curgene.link.weight = -8.0;
        }

        // Record the innovation
        //(*curgene).mutation_num+=randnum;
        curgene.mutationNum = curgene.link.weight;

        num += 1.0;
      }
    } // end for loop
  }

  void mutateToggleEnable(Neat neat, int times) {
    for (var count = 1; count <= times; count++) {
      // Choose a random genenum
      int genenum = neat.randInt(0, genes.length - 1);
      var thegene = genes[genenum]; // Gene to toggle

      // Toggle the enable on this gene
      if (thegene.expressed) {
        // We need to make sure that another gene connects out of the in-node
        // Because if not a section of network will break off and become isolated
        final checkgene = genes.firstWhereOrNull(
          (g) =>
              g.link.inNode == thegene.link.inNode &&
              g.expressed &&
              g.innovationNum != thegene.innovationNum,
        );

        // Disable the gene if it's safe to do so
        if (checkgene != null) {
          thegene.expressed = false;
        }
      } else {
        thegene.expressed = true;
      }
    }
  }

  void mutateGeneReenable() {
    // Find the first disabled gene
    final unExpressedGene = genes.firstWhereOrNull((g) => !g.expressed);

    // If a disabled gene is found, re-enable it
    if (unExpressedGene != null) {
      unExpressedGene.expressed = true;
    }
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

  (int currentNodeId, double currentInnov) mutateAddNode(
    Neat neat,
    List<Innovation> innovs,
    int curNodeId,
    double curInnov,
  ) {
    // random gene containing the original link
    int thegeneIndex = 0;
    int thegeneEndIndex = genes.length;

    int geneNum = 0; // The random gene number
    NNode inNode; // Here are the nodes connected by the gene
    NNode outNode;
    Link theLink; // The link inside the random gene

    int theInnovIndex = 0; // For finding a historical match
    int theInnovEndIndex = innovs.length; // For finding a historical match

    bool done = false;

    late Gene newGene1; // The new Genes
    late Gene newGene2;
    late NNode newNode; // The new NNode
    Trait traitptr; // The original link's trait

    // double splitweight;  //If used, Set to sqrt(oldweight of oldlink)
    double oldWeight; // The weight of the original link

    int tryCount = 0; // Take a few tries to find an open node
    bool found;

    // First, find a random gene already in the genome
    found = false;

    // Alternative random gaussian choice of genes NOT USED in this
    // version of NEAT
    // NOTE: 7/2/01 now we use this after all
    while ((tryCount < 20) && (!found)) {
      // Choose a random genenum
      // randmult=gaussrand()/4;
      // if (randmult>1.0) randmult=1.0;

      // This tends to select older genes for splitting
      // genenum=(int) floor((randmult*(genes.size()-1.0))+0.5);

      // This old totally random selection is bad- splitting
      // inside something recently splitted adds little power
      // to the system (should use a gaussian if doing it this way)
      geneNum = neat.randInt(0, thegeneEndIndex - 1);

      // find the gene
      thegeneIndex = geneNum;
      // for (var genecount = 0; genecount < geneNum; genecount++)
      //     {thegeneIndex++;}

      // If either the gene is non-expressed/disabled, or it has a bias input, try again
      if (!(genes[thegeneIndex].expressed == false ||
          genes[thegeneIndex].link.inNode!.genNodeLabel == Nodeplace.bias)) {
        found = true;
      }

      tryCount++;
    }

    // If we couldn't find anything so say goodbye
    if (!found) {
      return (curNodeId, curInnov);
    }

    // Disabled the gene
    var gene = genes[thegeneIndex];
    gene.expressed = false;

    // Extract the link
    theLink = gene.link;
    oldWeight = gene.link.weight;

    // Extract the nodes
    inNode = theLink.inNode!;
    outNode = theLink.outNode!;

    // Check to see if this innovation has already been done
    // in another genome
    // Innovations are used to make sure the same innovation in
    // two separate genomes in the same generation receives
    // the same innovation number.
    theInnovIndex = 0;

    while (!done) {
      if (theInnovIndex == theInnovEndIndex) {
        // The innovation is totally novel

        // Get the old link's trait
        traitptr = theLink.linkTrait!;

        // Create the new NNode
        // By convention, it will point to the first trait
        newNode = NNode.makeFromPlacement(
          Nodetype.neuron,
          curNodeId++,
          Nodeplace.hidden,
        );
        newNode.depth = (inNode.depth + outNode.depth) / 2.0;
        newNode.nodeTrait = traits[0];

        // Create the new Genes
        if (theLink.isRecurrent) {
          newGene1 = Gene.makeFromTrait(
            neat,
            traitptr,
            1.0,
            inNode,
            newNode,
            true,
            curInnov,
            0,
          );
          newGene2 = Gene.makeFromTrait(
            neat,
            traitptr,
            oldWeight,
            newNode,
            outNode,
            false,
            curInnov + 1,
            0,
          );
          curInnov += 2.0;
        } else {
          newGene1 = Gene.makeFromTrait(
            neat,
            traitptr,
            1.0,
            inNode,
            newNode,
            false,
            curInnov,
            0,
          );
          newGene2 = Gene.makeFromTrait(
            neat,
            traitptr,
            oldWeight,
            newNode,
            outNode,
            false,
            curInnov + 1,
            0,
          );
          curInnov += 2.0;
        }

        // Add the innovations (remember what was done)
        var newInnov = Innovation.makeAsNewNodeType(
          inNode.nodeId,
          outNode.nodeId,
          curInnov - 2.0,
          curInnov - 1.0,
          newNode.nodeId,
          genes[thegeneIndex].innovationNum,
        );
        innovs.add(newInnov);

        done = true;
      }
      // We check to see if an innovation already occured that was:
      //   -A new node
      //   -Stuck between the same nodes as were chosen for this mutation
      //   -Splitting the same gene as chosen for this mutation
      //   If so, we know this mutation is not a novel innovation
      //   in this generation
      //   so we make it match the original, identical mutation which occured
      //   elsewhere in the population by coincidence
      else {
        final existingInnov = innovs.firstWhereOrNull(
          (innov) =>
              innov.innovationType == Innovtype.newNode &&
              innov.nodeInId == inNode.nodeId &&
              innov.nodeOutId == outNode.nodeId &&
              innov.oldInnovNum == genes[thegeneIndex].innovationNum,
        );

        if (existingInnov != null) {
          // Here, the innovation has been done before

          // Get the old link's trait
          traitptr = theLink.linkTrait!;

          var innov = innovs[theInnovIndex];

          // Create the new NNode
          newNode = NNode.makeFromPlacement(
            Nodetype.neuron,
            innov.newNodeId,
            Nodeplace.hidden,
          );
          newNode.depth = (inNode.depth + outNode.depth) / 2.0;
          // By convention, it will point to the first trait
          // Note: In future may want to change this
          newNode.nodeTrait = traits[0];

          // Create the new Genes
          if (theLink.isRecurrent) {
            newGene1 = Gene.makeFromTrait(
              neat,
              traitptr,
              1.0,
              inNode,
              newNode,
              true,
              innov.innovationNum1,
              0,
            );
            newGene2 = Gene.makeFromTrait(
              neat,
              traitptr,
              oldWeight,
              newNode,
              outNode,
              false,
              innov.innovationNum2,
              0,
            );
          } else {
            newGene1 = Gene.makeFromTrait(
              neat,
              traitptr,
              1.0,
              inNode,
              newNode,
              false,
              innov.innovationNum1,
              0,
            );
            newGene2 = Gene.makeFromTrait(
              neat,
              traitptr,
              oldWeight,
              newNode,
              outNode,
              false,
              innov.innovationNum2,
              0,
            );
          }

          done = true;
        } else {
          theInnovIndex++;
        }
      }
    }

    // Now add the new NNode and new Genes to the Genome
    addGene(genes, newGene1); // Add genes in correct order
    addGene(genes, newGene2);
    nodeInsert(nodes, newNode);

    return (curNodeId, curInnov);
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
    // List<Gene>.iterator thegene;             // Searches for existing link
    bool found = false; // Tells whether an open pair was found
    bool recurrentFlag = false; // Indicates whether proposed link is recurrent
    late Gene newGene; // The new Gene

    int traitNum = 0; // Random trait finder

    double newWeight = 0.0; // The new weight for the new link

    bool doesRecur = false;
    bool loopRecur = false;
    int firstNonsensor = 0;
    bool done = false;

    var theGeneIt = GenesIteratorList(neat, genes);
    var theInnovIt = InnovationsIteratorList(neat, innovations);

    // int theGeneIndex = 0;
    // int theGeneEndIndex = 0;

    // int theInnovIndex = 0;
    // int theInnovEndIndex = 0;

    // Make attempts to find an unconnected pair
    tryCount = 0;

    // Decide whether to make this recurrent
    doesRecur = neat.randFloat() < neat.recurOnlyProb;

    // Find the first non-sensor so that the toNode won't look at sensors as
    // possible destinations
    // indexWhere returns the first index that satisfies the condition, or -1.
    firstNonsensor = nodes.indexWhere((node) => !node.isSensor());

    // Here is the recurrent finder loop- it is done separately
    if (doesRecur) {
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
        theGeneIt.begin();

        // See if a recur link already exists  ALSO STOP AT END OF GENES!!!!
        while (!theGeneIt.isEnd &&
            nodeP2.isSensor() && // Don't allow SENSORS to get input
            (!(((theGeneIt.current.link).inNode == nodeP1) &&
                ((theGeneIt.current.link).outNode == nodeP2) &&
                (theGeneIt.current.link).isRecurrent))) {
          theGeneIt.next();
        }

        // If the link is invalid, increment the try count and try again.
        if (!theGeneIt.isEnd) {
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
          //   // cout<<"LOOP DETECTED DURING A RECURRENCY CHECK"<<std.endl;
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
      if (doesRecur) {
        recurrentFlag = true;
      }

      done = false;

      theInnovIt.begin();

      while (!done) {
        if (theInnovIt.isEnd) {
          // If the phenotype does not exist, exit on false,print error
          // Note: This should never happen- if it does there is a bug
          if (phenoType != null) {
            neat.log("ERROR: Attempt to add link to genome with no phenotype");
            return false;
          }

          // Choose a random trait
          traitNum = neat.randInt(0, traits.length - 1);

          // CASE 1: This is a novel innovation.
          // Choose a random trait for the new gene.
          // traitNum = traits[neat.randInt(0, traits.length - 1)].traitId;

          // Choose a random weight for the new link.
          newWeight =
              neat.randPosNeg() * neat.randFloat() * neat.weightMutPower;

          // Create the new gene
          newGene = Gene.makeFromTrait(
            neat,
            traits[traitNum],
            newWeight,
            nodeP1,
            nodeP2,
            recurrentFlag,
            currentInnovation,
            newWeight,
          );

          // Create the new innovation and add it to the master list.
          final newInnov = Innovation.makeAsNewLinkRecurrentType(
            nodeP1.nodeId,
            nodeP2.nodeId,
            currentInnovation,
            newWeight,
            traitNum,
            false,
          );
          innovations.add(newInnov);

          currentInnovation += 1.0;
          done = true;
        }
        // OTHERWISE, match the innovation in the innovs list
        else {
          final existingInnov = theInnovIt.findIf(
            (innov) =>
                innov.innovationType == Innovtype.newLink &&
                innov.nodeInId == nodeP1.nodeId &&
                innov.nodeOutId == nodeP2.nodeId &&
                innov.recurrentFlag == recurrentFlag,
          );

          if (existingInnov != null) {
            // Create new gene
            newGene = Gene.makeFromTrait(
              neat,
              traits[existingInnov.newTraitnum],
              existingInnov.newWeight,
              nodeP1,
              nodeP2,
              recurrentFlag,
              existingInnov.innovationNum1,
              0,
            );
            // neat.log("Novel NEW GENE2: ", newgene->link->in_node->node_id);

            done = true;
          } else {
            // Keep looking for a matching innovation from this generation
            theInnovIt.next();
          }
        }
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
    // This is the core of the condition. The every() method checks if every single
    // element in the outputs list satisfies the given test. It's a very concise way to ask,
    // "Is the following true for all outputs?"
    // genes.any((gene) => ...):
    // This is the test performed for each output. The any method checks if at
    // least one gene in the genes list satisfies the condition. It's how we
    // check for the existence of a specific link.
    // The Full Condition:
    // Putting it all together, the code reads like this:
    // "Remove a sensor if every output has any expressedd gene connecting that sensor to that output."
    sensors.removeWhere((sensor) {
      // If there are no outputs, no sensor can be fully connected.
      if (outputs.isEmpty) return false;

      // Check if this sensor is connected to EVERY output node.
      // The `every` method returns true if the condition is met for all elements.
      // "Does EVERY output have AT LEAST ONE gene connecting this sensor to it?"
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

          // Create the new gene using the new innovation number.
          newGene = Gene.makeFromTrait(
            neat,
            traits[traitNum],
            newWeight,
            sensor,
            output,
            false, // Not recurrent
            currentInnovation,
            newWeight,
          );

          // Create the new innovation and add it to the master list.
          final newInnov = Innovation.makeAsNewLinkType(
            sensor.nodeId,
            output.nodeId,
            currentInnovation,
            newWeight,
            traitNum,
          );
          innovations.add(newInnov);

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

  Genome mateSinglePoint(Neat neat, Genome g, int genomeId) {
    // =========================================================================
    // STEP 1: Average the traits from both parents
    // =========================================================================
    final List<Trait> newTraits = _averageTraits(neat, traits, g.traits);

    // =========================================================================
    // STEP 2: Determine parent roles (shorter vs longer) and pick crosspoint
    // =========================================================================
    final (p1genes, p2genes) = genes.length < g.genes.length
        ? (genes, g.genes)
        : (g.genes, genes);

    final int crosspoint = neat.randInt(0, p1genes.length - 1);

    // =========================================================================
    // STEP 3: March through parents' genes and select inherited genes
    // =========================================================================
    final List<Gene> chosenGenes = _selectCrossoverGenes(
      neat: neat,
      p1genes: p1genes,
      p2genes: p2genes,
      crosspoint: crosspoint,
    );

    // =========================================================================
    // STEP 4 & 5: Build baby nodes and genes (filtering duplicate links)
    // =========================================================================
    final List<NNode> newNodes = [];
    final List<Gene> newGenes = [];

    for (final gene in chosenGenes) {
      // Avoid duplicate links
      if (_hasLinkConflict(newGenes, gene.link)) continue;

      // Ensure both inNode and outNode exist in newNodes
      final NNode newInode = _getOrCreateNode(
        newNodes,
        gene.link.inNode!,
        newTraits,
      );
      final NNode newOnode = _getOrCreateNode(
        newNodes,
        gene.link.outNode!,
        newTraits,
      );

      // Get corresponding trait for this gene
      final newTrait = _getGeneTrait(gene, newTraits);

      // Add the new gene to the baby
      newGenes.add(Gene.makeFromGene(neat, gene, newTrait, newInode, newOnode));
    }

    // =========================================================================
    // STEP 6: Assemble baby Genome
    // =========================================================================
    return Genome.makeFromSpecs(genomeId, newTraits, newNodes, newGenes);
  }

  Genome mateMultipointAvg(
    Neat neat,
    Genome g,
    int genomeId,
    double fitness1,
    double fitness2,
    bool interspecFlag,
  ) {
    // =========================================================================
    // STEP 1: Average the traits from both parents
    // =========================================================================
    final List<Trait> newTraits = _averageTraits(neat, traits, g.traits);

    // =========================================================================
    // STEP 2: Pre-populate Sensors, Bias, and Outputs from parent
    // =========================================================================
    final List<NNode> newNodes = _createBaseSensorsAndOutputs(
      g.nodes,
      newTraits,
    );

    // =========================================================================
    // STEP 3: Determine which parent is better
    // =========================================================================
    final bool p1Better = _isParent1Better(
      fitness1,
      fitness2,
      genes.length,
      g.genes.length,
    );

    // =========================================================================
    // STEP 4: March through genes and select/average inherited genes
    // =========================================================================
    final List<Gene> chosenGenes = _selectMultipointAvgGenes(
      neat: neat,
      p1genes: genes,
      p2genes: g.genes,
      p1Better: p1Better,
    );

    // =========================================================================
    // STEP 5: Build baby nodes & genes (filtering duplicate links)
    // =========================================================================
    final List<Gene> newGenes = [];

    for (final gene in chosenGenes) {
      // Avoid duplicate links
      if (_hasLinkConflict(newGenes, gene.link)) continue;

      // Ensure both inNode and outNode exist in newNodes
      final NNode newInode = _getOrCreateNode(
        newNodes,
        gene.link.inNode!,
        newTraits,
      );
      final NNode newOnode = _getOrCreateNode(
        newNodes,
        gene.link.outNode!,
        newTraits,
      );

      // Get corresponding trait for this gene
      final Trait? newTrait = _getGeneTrait(gene, newTraits);

      // Add gene to baby
      newGenes.add(Gene.makeFromGene(neat, gene, newTrait, newInode, newOnode));
    }

    // =========================================================================
    // STEP 6: Assemble baby Genome
    // =========================================================================
    return Genome.makeFromSpecs(genomeId, newTraits, newNodes, newGenes);
  }

  Genome mateMultipoint(
    Neat neat,
    Genome g,
    int genomeId,
    double fitness1,
    double fitness2,
    bool interspeciesFlag,
  ) {
    // =========================================================================
    // STEP 1: Average the traits from both parents
    // =========================================================================
    final List<Trait> newTraits = _averageTraits(neat, traits, g.traits);

    // =========================================================================
    // STEP 2: Pre-populate Sensors, Bias, and Outputs from parent
    // =========================================================================
    final List<NNode> newNodes = _createBaseSensorsAndOutputs(
      g.nodes,
      newTraits,
    );

    // =========================================================================
    // STEP 3: Determine which parent is better
    // =========================================================================
    final bool p1Better = _isParent1Better(
      fitness1,
      fitness2,
      genes.length,
      g.genes.length,
    );

    // =========================================================================
    // STEP 4: March through genes and select inherited genes (50/50 on match)
    // =========================================================================
    final List<Gene> chosenGenes = _selectMultipointGenes(
      neat: neat,
      p1genes: genes,
      p2genes: g.genes,
      p1Better: p1Better,
    );

    // =========================================================================
    // STEP 5: Build baby nodes & genes (filtering duplicate links)
    // =========================================================================
    final List<Gene> newGenes = [];

    for (final gene in chosenGenes) {
      // Avoid duplicate links
      if (_hasLinkConflict(newGenes, gene.link)) continue;

      // Ensure both inNode and outNode exist in newNodes
      final NNode newInode = _getOrCreateNode(
        newNodes,
        gene.link.inNode!,
        newTraits,
      );
      final NNode newOnode = _getOrCreateNode(
        newNodes,
        gene.link.outNode!,
        newTraits,
      );

      // Get corresponding trait for this gene
      final Trait? newTrait = _getGeneTrait(gene, newTraits);

      // Add gene to baby
      newGenes.add(Gene.makeFromGene(neat, gene, newTrait, newInode, newOnode));
    }

    // =========================================================================
    // STEP 6: Assemble baby Genome
    // =========================================================================
    return Genome.makeFromSpecs(genomeId, newTraits, newNodes, newGenes);
  }

  bool _isParent1Better(double f1, double f2, int len1, int len2) {
    if (f1 > f2) return true;
    if (f1 == f2) return len1 < len2; // tie-breaker: smaller genome is better
    return false;
  }

  List<Gene> _selectMultipointAvgGenes({
    required Neat neat,
    required List<Gene> p1genes,
    required List<Gene> p2genes,
    required bool p1Better,
  }) {
    final List<Gene> chosen = [];
    int p1Index = 0;
    int p2Index = 0;

    while (p1Index < p1genes.length || p2Index < p2genes.length) {
      if (p1Index >= p1genes.length) {
        // Excess in parent 2: inherit only if parent 2 is better
        if (!p1Better) chosen.add(p2genes[p2Index]);
        p2Index++;
      } else if (p2Index >= p2genes.length) {
        // Excess in parent 1: inherit only if parent 1 is better
        if (p1Better) chosen.add(p1genes[p1Index]);
        p1Index++;
      } else {
        final g1 = p1genes[p1Index];
        final g2 = p2genes[p2Index];

        if (g1.innovationNum == g2.innovationNum) {
          // Matching genes: average their weights and properties
          final avgGene = _createAverageGene(neat, g1, g2);

          // If either parent gene is disabled, 75% chance offspring gene is disabled
          if (!g1.expressed || !g2.expressed) {
            if (neat.randFloat() < 0.75) avgGene.expressed = false;
          }

          chosen.add(avgGene);
          p1Index++;
          p2Index++;
        } else if (g1.innovationNum < g2.innovationNum) {
          // Disjoint in parent 1
          if (p1Better) chosen.add(g1);
          p1Index++;
        } else {
          // Disjoint in parent 2
          if (!p1Better) chosen.add(g2);
          p2Index++;
        }
      }
    }

    return chosen;
  }

  List<NNode> _createBaseSensorsAndOutputs(
    List<NNode> sourceNodes,
    List<Trait> newTraits,
  ) {
    final List<NNode> baseNodes = [];

    for (final node in sourceNodes) {
      if (node.isSensor() || node.genNodeLabel == Nodeplace.output) {
        final int traitIndex = node.nodeTrait == null
            ? 0
            : (node.nodeTrait!.traitId - traits.first.traitId).clamp(
                0,
                newTraits.length - 1,
              );

        final newNode = NNode.makeFromTrait(node, newTraits[traitIndex]);
        newNode.depth = node.depth;
        nodeInsert(baseNodes, newNode);
      }
    }

    return baseNodes;
  }

  List<Trait> _averageTraits(Neat neat, List<Trait> t1, List<Trait> t2) {
    return List.generate(
      t1.length,
      (i) => Trait.makeByAverage(neat, t1[i], t2[i]),
    );
  }

  // Select Inherited Genes across Crosspoint
  List<Gene> _selectCrossoverGenes({
    required Neat neat,
    required List<Gene> p1genes,
    required List<Gene> p2genes,
    required int crosspoint,
  }) {
    final List<Gene> chosen = [];
    int p1Index = 0;
    int p2Index = 0;
    int geneCounter = 0;

    while (p1Index < p1genes.length || p2Index < p2genes.length) {
      if (p1Index >= p1genes.length) {
        // Parent 1 ended: excess genes belong to Parent 2
        // Take if we have already crossed over to Parent 2
        if (geneCounter > crosspoint) {
          chosen.add(p2genes[p2Index]);
        }
        p2Index++;
      } else if (p2Index >= p2genes.length) {
        // Parent 2 ended: excess genes belong to Parent 1
        // Take if we are still on Parent 1 (before crosspoint)
        if (geneCounter < crosspoint) {
          chosen.add(p1genes[p1Index]);
        }
        p1Index++;
      } else {
        final g1 = p1genes[p1Index];
        final g2 = p2genes[p2Index];

        if (g1.innovationNum == g2.innovationNum) {
          // Matching genes
          if (geneCounter < crosspoint) {
            chosen.add(g1);
          } else if (geneCounter > crosspoint) {
            chosen.add(g2);
          } else {
            // Exactly AT the crosspoint: average the two genes
            chosen.add(_createAverageGene(neat, g1, g2));
          }
          p1Index++;
          p2Index++;
          geneCounter++;
        } else if (g1.innovationNum < g2.innovationNum) {
          // Disjoint gene in Parent 1
          if (geneCounter < crosspoint) {
            chosen.add(g1);
          }
          p1Index++;
          geneCounter++;
        } else {
          // Disjoint gene in Parent 2
          if (geneCounter > crosspoint) {
            chosen.add(g2);
          }
          p2Index++;
        }
      }
    }

    return chosen;
  }

  Gene _createAverageGene(Neat neat, Gene g1, Gene g2) {
    final chosenTrait = neat.randFloat() > 0.5
        ? g1.link.linkTrait
        : g2.link.linkTrait;
    final chosenInNode = neat.randFloat() > 0.5
        ? g1.link.inNode
        : g2.link.inNode;
    final chosenOutNode = neat.randFloat() > 0.5
        ? g1.link.outNode
        : g2.link.outNode;
    final chosenRecurr = neat.randFloat() > 0.5
        ? g1.link.isRecurrent
        : g2.link.isRecurrent;

    final avgGene = Gene.makeFromTrait(
      neat,
      chosenTrait,
      (g1.link.weight + g2.link.weight) / 2.0,
      chosenInNode,
      chosenOutNode,
      chosenRecurr,
      g1.innovationNum,
      (g1.mutationNum + g2.mutationNum) / 2.0,
    );

    if (!g1.expressed || !g2.expressed) {
      avgGene.expressed = false;
    }
    return avgGene;
  }

  // Duplicate Link Conflict Check
  bool _hasLinkConflict(List<Gene> genes, Link candidate) {
    return genes.any((g) {
      final link = g.link;
      // Same direction and same recurrence
      final exactMatch =
          link.inNode!.nodeId == candidate.inNode!.nodeId &&
          link.outNode!.nodeId == candidate.outNode!.nodeId &&
          link.isRecurrent == candidate.isRecurrent;

      // Opposite direction for non-recurrent links
      final oppositeMatch =
          !link.isRecurrent &&
          !candidate.isRecurrent &&
          link.inNode!.nodeId == candidate.outNode!.nodeId &&
          link.outNode!.nodeId == candidate.inNode!.nodeId;

      return exactMatch || oppositeMatch;
    });
  }

  // Node Insertion / Retrieval Helper
  NNode _getOrCreateNode(
    List<NNode> newNodes,
    NNode sourceNode,
    List<Trait> newTraits,
  ) {
    final existing = newNodes.firstWhereOrNull(
      (n) => n.nodeId == sourceNode.nodeId,
    );
    if (existing != null) return existing;

    final int traitIndex = sourceNode.nodeTrait == null
        ? 0
        : (sourceNode.nodeTrait!.traitId - traits[0].traitId).clamp(
            0,
            newTraits.length - 1,
          );

    final newNode = NNode.makeFromTrait(sourceNode, newTraits[traitIndex]);
    newNode.depth = sourceNode.depth;
    nodeInsert(newNodes, newNode);
    return newNode;
  }

  Trait? _getGeneTrait(Gene gene, List<Trait> newTraits) {
    final sourceTrait = gene.link.linkTrait;
    if (sourceTrait == null || newTraits.isEmpty) {
      return null;
    }

    // 1. Try to find the matching trait by ID in newTraits
    final matchingTrait = newTraits.firstWhereOrNull(
      (t) => t.traitId == sourceTrait.traitId,
    );
    if (matchingTrait != null) {
      return matchingTrait;
    }

    // 2. Fallback: normalize trait index (matches original C++ NEAT logic)
    final int traitIndex = (sourceTrait.traitId - traits[0].traitId).clamp(
      0,
      newTraits.length - 1,
    );
    return newTraits[traitIndex];
  }

  List<Gene> _selectMultipointGenes({
    required Neat neat,
    required List<Gene> p1genes,
    required List<Gene> p2genes,
    required bool p1Better,
  }) {
    final List<Gene> chosen = [];
    int p1Index = 0;
    int p2Index = 0;

    while (p1Index < p1genes.length || p2Index < p2genes.length) {
      if (p1Index >= p1genes.length) {
        // Parent 1 ended: excess in Parent 2 (inherit only if Parent 2 is better)
        if (!p1Better) chosen.add(p2genes[p2Index]);
        p2Index++;
      } else if (p2Index >= p2genes.length) {
        // Parent 2 ended: excess in Parent 1 (inherit only if Parent 1 is better)
        if (p1Better) chosen.add(p1genes[p1Index]);
        p1Index++;
      } else {
        final g1 = p1genes[p1Index];
        final g2 = p2genes[p2Index];

        if (g1.innovationNum == g2.innovationNum) {
          // Matching genes: randomly choose from Parent 1 or Parent 2 (50/50)
          final chosenGene = neat.randFloat() < 0.5 ? g1 : g2;

          // If either parent's gene is disabled, 75% chance offspring copy is disabled
          if (!g1.expressed || !g2.expressed) {
            if (neat.randFloat() < 0.75) {
              // Create a copy to disable it safely without mutating the parent's gene
              final disabledGene = Gene.makeCopy(neat, chosenGene);
              disabledGene.expressed = false;
              chosen.add(disabledGene);
            } else {
              chosen.add(chosenGene);
            }
          } else {
            chosen.add(chosenGene);
          }

          p1Index++;
          p2Index++;
        } else if (g1.innovationNum < g2.innovationNum) {
          // Disjoint gene in Parent 1
          if (p1Better) chosen.add(g1);
          p1Index++;
        } else {
          // Disjoint gene in Parent 2
          if (!p1Better) chosen.add(g2);
          p2Index++;
        }
      }
    }

    return chosen;
  }

  double compatibility(Neat neat, Genome g) {
    int parent1GeneIndex = 0;
    int parent1StopIndex = 0;
    int parent2GeneIndex = 0;
    int parent2StopIndex = 0;

    // Innovation numbers
    double p1Innov = 0.0;
    double p2Innov = 0.0;

    // Intermediate value
    double mutDiff = 0.0;

    // Set up the counters
    double numDisjoint = 0.0;
    double numExcess = 0.0;
    double mutDiffTotal = 0.0;
    double numMatching = 0.0; // Used to normalize mutation_num differences

    List<Gene> p1genes;
    List<Gene> p2genes;

    // double maxGenomeSize = 0.0; // Size of larger Genome

    // // Get the length of the longest Genome for percentage computations
    // if (genes.length < g.genes.length) {
    //   maxGenomeSize = g.genes.length;
    // } else {
    //   maxGenomeSize = genes.length;
    // }

    // Now move through the Genes of each potential parent
    // until both Genomes end
    p1genes = genes;
    p2genes = g.genes;

    parent1StopIndex = genes.length;
    parent2StopIndex = g.genes.length;

    while (!(parent1GeneIndex == parent1StopIndex &&
        parent2GeneIndex == parent2StopIndex)) {
      if (parent1GeneIndex == parent1StopIndex) {
        parent2GeneIndex++;
        numExcess += 1.0;
      } else if (parent2GeneIndex == parent2StopIndex) {
        parent1GeneIndex++;
        numExcess += 1.0;
      } else {
        // Extract current innovation numbers
        p1Innov = p1genes[parent1GeneIndex].innovationNum;
        p2Innov = p2genes[parent2GeneIndex].innovationNum;

        if (p1Innov == p2Innov) {
          numMatching += 1.0;
          mutDiff =
              p1genes[parent1GeneIndex].mutationNum -
              p2genes[parent2GeneIndex].mutationNum;

          if (mutDiff < 0.0) mutDiff = 0.0 - mutDiff;
          // mutDiff+=traitCompare((*p1gene).lnk.linktrait,(*p2gene).lnk.linktrait); //CONSIDER TRAIT DIFFERENCES
          mutDiffTotal += mutDiff;

          parent1GeneIndex++;
          parent2GeneIndex++;
        } else if (p1Innov < p2Innov) {
          parent1GeneIndex++;
          numDisjoint += 1.0;
        } else if (p2Innov < p1Innov) {
          parent2GeneIndex++;
          numDisjoint += 1.0;
        }
      }
    } // End while

    // Return the compatibility number using compatibility formula
    // Note that mut_diffTotal/numMatching gives the AVERAGE
    // difference between mutation_nums for any two matching Genes
    // in the Genome

    // Normalizing for genome size
    // return (disjointCoeff*(num_disjoint/max_genome_size)+
    //   excessCoeff*(num_excess/max_genome_size)+
    //   mutdiffCoeff*(mut_diffTotal/numMatching));

    // Look at disjointedness and excess in the absolute (ignoring size)

    return (neat.disjointCoeff * (numDisjoint / 1.0) +
        neat.excessCoeff * (numExcess / 1.0) +
        neat.mutdiffCoeff * (mutDiffTotal / numMatching));
  }

  double traitCompare(Trait t1, Trait t2) {
    int id1 = t1.traitId;
    int id2 = t2.traitId;
    int count;
    double paramsDiff = 0.0; // Measures parameter difference

    // See if traits represent different fundamental types of connections
    if ((id1 == 1) && (id2 >= 2)) {
      return 0.5;
    } else if ((id2 == 1) && (id1 >= 2)) {
      return 0.5;
    }
    // Otherwise, when types are same, compare the actual parameters
    else {
      if (id1 >= 2) {
        for (count = 0; count <= 2; count++) {
          paramsDiff += (t1.params[count] - t2.params[count]).abs();
        }
        return paramsDiff / 4.0;
      } else {
        return 0.0;
      } // For type 1, params are not applicable
    }
  }

  int extrons() {
    int total = 0;

    for (var gene in genes) {
      if (gene.expressed) {
        total++;
      }
    }

    return total;
  }

  void randomizeTraits(Neat neat) {
    int numtraits = traits.length;
    if (numtraits == 0) {
      return; // Nothing to do if there are no traits
    }

    // Go through all nodes and randomize their trait pointers
    for (var curnode in nodes) {
      int traitnum = neat.randInt(1, numtraits); // randomize trait
      curnode.traitId = traitnum;

      var curtraitIt = traits.firstWhereOrNull(
        (trait) => trait.traitId == traitnum,
      );

      if (curtraitIt != null) {
        curnode.nodeTrait = curtraitIt;
      }
    }

    // Go through all connections and randomize their trait pointers
    for (var curgene in genes) {
      int traitnum = neat.randInt(1, numtraits); // randomize trait
      curgene.link.traitId = traitnum;
      var curtraitIt = traits.firstWhereOrNull(
        (trait) => trait.traitId == traitnum,
      );
      if (curtraitIt != null) {
        curgene.link.linkTrait = curtraitIt;
      }
    }
  }
}
