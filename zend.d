import std.stdio;

import pc.parser;
import std.variant;
import std.array;


class Node {
  Node[] fChilds;
  string fName;
  this(string name) {
    fName = name;
  }
  void addChild(Node n) {
    fChilds ~= n;
  }
  void printIndent(int nrOfIndents) {
    for (int i=0; i<nrOfIndents; i++) {
      write(" ");
    }
  }
  void print(int indent=0) {
    printIndent(indent);
    write("<" ~ fName ~ ">\n");
    foreach (Node n ; fChilds) {
      n.print(indent+2);
    }
    printIndent(indent);
    write("</" ~ fName ~ ">\n");
  }
  string toString() {
    return "Node " ~ fName;
  }
}

class MultNode : public Node {
  int fTimes;
  this(Node[] child, int mult) {
    super("");
    fChilds = child;
    fTimes = mult;
  }
  void print(int indent=0) {
    for (int i=0; i<fTimes; i++) {
      foreach (Node child ; fChilds) {
	child.print(indent);
      }
    }
  }
}

//           zen -> multWithChild | multWithSibbling | mult
// multWithChild -> mult > zen
// multWithSibbling -> mult + zen
// mult -> number * node | node
// node -> alnum | ( zen )

//       zen -> sibbling { + sibbling }
// sibbling  -> mult { > mult }
// mult      -> number * node | node
// node      -> alnum | (zen)
Parser lazyZen() {
  return new Parser.LazyParser( &zen );
}

Parser zen() {
  return multWithChild() | multWithSibbling() | mult();
}

Parser mult() {
  Variant[] multnode(int factorIdx, int nodesIdx, Variant[] input) {
    int factor = input[factorIdx].get!(int);
    Node[] nodes = input[nodesIdx].get!(Node[]);
    auto node = new MultNode(nodes, factor);
    Node[] res;
    res ~= node;
    return variantArray(res);
  }
  auto numberTimesNode = (new Parser.Integer ~ Parser.match("*") ~ lazyZen()) ^^ (Variant[] input) {
    return multnode(0, 2, input);
  };
  return numberTimesNode | node();
}

Parser node() {
  auto alnum =  new Parser.AlnumParser ^^ (Variant[] input) {
    Node[] res;
    res ~= new Node(input[0].get!(string));
    return variantArray(res);
  };
  return alnum | (Parser.match("(") ~ lazyZen() ~ Parser.match(")")) ^^ (Variant[] input) {
    auto realValues = input[1..$-1];
    return realValues;
  };
}

Parser multWithChild() {
  return (mult() ~ Parser.match(">") ~ lazyZen()) ^^ (Variant[] input) {
    void prepareParent(Node parent, Variant v) {
      if (v.type == typeid(Node[])) {
        foreach (Node n ; v.get!(Node[])) {
          parent.addChild(n);
        }
      } else {
        assert(false);
      }
    }
    auto parents = input[0];
    auto childs = input[2];
    if (parents.type == typeid(Node[])) {
      foreach(Node n ; parents.get!(Node[])) {
        prepareParent(n, childs);
      }
    } else {
      assert(false);
    }
    return variantArray(parents);
  };
}

Parser multWithSibbling() {
  return (mult() ~ Parser.match("+") ~ lazyZen()) ^^ (Variant[] input) {
    Node[] r;
    r ~= input[0].get!(Node[]);
    r ~= input[2].get!(Node[]);
    return variantArray(r);
  };
}

void printResult(Variant r) {
  foreach (Node n ; r.get!(Node[])) {
    n.print();
  }
}

Object check(string s) {
  writefln("checking %s:", s);
  auto res = cast(Parser.Success)(zen().parseAll(s));
  if (res is null) {
    writeln("could not parse: " ~ s);
    return null;
  }
  Variant r = res.results[0];
  printResult(r);
  return res;
}

unittest {
  assert(check("a") !is null);
  assert(check("a>a") !is null);
  assert(check("a+a") !is null);
  assert(check("a>(a+b+c)") !is null);
  assert(check("(a+b)>(a+b)") !is null);
  assert(check("a>b+c+d") !is null);
  assert(check("a>b>(c>d)") !is null);
  assert(check("a+(b>c)+c") !is null);
  assert(check("a+b+c+d+e+f") !is null);
  assert(check("a>b>c>d>e>f") !is null);
}

int main(string[] args) {
  foreach (string input ; args[1..$]) {
    check(input);
  }
  return 0;
}
