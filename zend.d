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
    printIndent(indent);write("</" ~ fName ~ ">\n");
  }
  string toString() {
    return "Node " ~ fName;
  }
}


  //           zen -> nodeWithChild | nodeWithSibbling | node
  // nodeWithChild -> node > zen
  // nodeWithSibbling -> node + zen
  // node -> alnum | ( zen )

  Parser lazyZen() {
    return new Parser.LazyParser( &zen );
  }

  Parser zen() {
    return nodeWithChild() | nodeWithSibbling() | node();
  }

  Parser node() {
    auto alnum =  new Parser.AlnumParser;
    alnum ^^ (Variant[] input) {
      return variantArray(new Node(input[0].get!(string)));
    };
    return alnum | (Parser.match("(") ~ lazyZen() ~ Parser.match(")")) ^^ (Variant[] input) {
      auto realValues = input[1..$-1];
      return realValues;
    };
  }
  Parser nodeWithChild() {
    return (node() ~ Parser.match(">") ~ lazyZen()) ^^ (Variant[] input) {

      void prepareParent(Node parent, Variant v) {
        if (v.type == typeid(Node)) {
          parent.addChild(v.get!(Node));
        } else {
          foreach (Node n ; v.get!(Node[])) {
	    parent.addChild(n);
          }
        }
      }

      auto parents = input[0];
      auto childs = input[2];
      if (parents.type == typeid(Node)) {
      	 prepareParent(parents.get!(Node), childs);
      } else if (parents.type == typeid(Node[])) {
         foreach(Node n ; parents.get!(Node[])) {
	   prepareParent(n, childs);
	 }
      }
      return variantArray(parents);
    };
  }

  Parser nodeWithSibbling() {
    return (node() ~ Parser.match("+") ~ lazyZen()) ^^ (Variant[] input) {
      Node[] r;
      foreach (Variant v ; input) {
        if (v.type == typeid(Node)) {
	  r ~= v.get!(Node);
	} else if (v.type == typeid(Node[])) {
	  r ~= v.get!(Node[]);
	}
      }
      return variantArray(r);
    };
  }

void printResult(Variant r) {
      if (r.type == typeid(Node)) {
	r.get!(Node).print();
      } else if (r.type == typeid(Node[])) {
	foreach (Node n ; r.get!(Node[])) {
	  n.print();
	}
      } else {
        writeln("unknown node structure");
      }
}

    Object check(string s) {
      writefln("checking %s:", s);
      auto res = cast(Parser.Success)(zen().parse(s));
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
    assert(check("a>(a+b)") !is null);
    assert(check("(a+b)>(a+b)") !is null);
    assert(check("a>b+c+d") !is null);
    assert(check("a>b>(c>d)") !is null);
    assert(check("a+(b>c)+c") !is null);
    assert(check("a+b+c+d+e+f") !is null);
    assert(check("a>b>c>d>e>f") !is null);
  }

int main(string[] args) {
  if (args.length > 0) {
    foreach (string input ; args) {
      check(input);
//      printResult((cast(Parser.Success)(zen().parse(input))).results[0]);
    }
  }
  auto input = args[1];
  return 0;
}
