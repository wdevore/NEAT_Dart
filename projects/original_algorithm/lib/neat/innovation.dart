enum Innovtype { unset, newNode, newLink }

class Innovation {
  // Either NEWNODE or NEWLINK
  Innovtype innovationType = Innovtype.unset;

  int nodeInId = 0; // Two nodes specify where the innovation took place
  int nodeOutId = 0;

  double innovationNum1 = 0.0; // The number assigned to the innovation
  // If this is a new node innovation, then there are 2 innovations (links) added for the new node
  double innovationNum2 = 0.0;

  double newWeight = 0.0; //  If a link is added, this is its weight
  int newTraitnum = 0; // If a link is added, this is its connected trait

  int newNodeId = 0; // If a new node was created, this is its node_id

  // If a new node was created, this is the innovnum of the gene's link it is being stuck inside
  double oldInnovNum = 0.0;

  bool recurrentFlag = false;

  Innovation();

  factory Innovation.makeAsNewNodeType(
    int nIn,
    int nOut,
    double num1,
    double num2,
    int newId,
    double oldInnov,
  ) {
    var inno = Innovation()
      ..innovationType = Innovtype.newNode
      ..nodeInId = nIn
      ..nodeOutId = nOut
      ..innovationNum1 = num1
      ..innovationNum2 = num2
      ..newNodeId = newId
      ..oldInnovNum = oldInnov
      // Unused parameters set to zero
      ..newWeight = 0
      ..newTraitnum = 0
      ..recurrentFlag = false;

    return inno;
  }

  factory Innovation.makeAsNewLinkType(
    int nIn,
    int nOut,
    double num1,
    double w,
    int t,
  ) {
    var inno = Innovation()
      ..innovationType = Innovtype.newLink
      ..nodeInId = nIn
      ..nodeOutId = nOut
      ..innovationNum1 = num1
      // Unused parameters set to zero
      ..newWeight = w
      ..newTraitnum = t
      ..innovationNum2 = 0
      ..newNodeId = 0
      ..recurrentFlag = false;

    return inno;
  }

  factory Innovation.makeAsNewLinkRecurrentType(
    int nIn,
    int nOut,
    double num1,
    double w,
    int t,
    bool recurrent,
  ) {
    var inno = Innovation()
      ..innovationType = Innovtype.newLink
      ..nodeInId = nIn
      ..nodeOutId = nOut
      ..innovationNum1 = num1
      ..newWeight = w
      ..newTraitnum = t
      // Unused parameters set to zero
      ..innovationNum2 = 0
      ..newNodeId = 0
      ..recurrentFlag = recurrent;

    return inno;
  }
}
