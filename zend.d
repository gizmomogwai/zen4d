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
  this(Node toCopy) {
    fName = toCopy.fName;
    foreach (Node n ; toCopy.fChilds) {
      fChilds ~= new Node(n);
    }
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
    string res = "Node " ~ fName;
    foreach (Node child ; fChilds) {
      res ~= "  " ~ child.toString();
    }
    return res;
  }
}


//       zen -> sibbling { + zen }
// sibbling  -> mult { > sibbling }
// mult      -> number * node | node
// node      -> alnum | (zen)

Parser lazyZen() {
  return new Parser.LazyParser(&zen);
}
Parser zen() {
  auto h = (Parser.match("+") ~ lazyZen()) ^^ (Variant[] input) {
    return input[1..$];
  };
  return (sibbling() ~ new Parser.Opt(h)) ^^ (Variant[] input) {
    Node[] res;
    foreach (Node n; input[0].get!(Node[])) {
      res ~= n;
    }
    if (input.length > 1) {
      foreach (Node n; input[1].get!(Node[])) {
        res ~= n;
      }
    }
    return variantArray(res);
  };
}
Parser lazySibbling() {
  return new Parser.LazyParser(&sibbling);
}
Parser sibbling() {
  auto h = (Parser.match(">") ~ lazySibbling()) ^^ (Variant[] input) {
    return variantArray(input[1]);
  };
  Parser res = (mult() ~ new Parser.Opt(h)) ^^ (Variant[] input) {
    if (input.length == 1) {
      return input;
    } else if (input.length == 2) {
      auto parents = input[0].get!(Node[]);
      auto childs = input[1].get!(Node[]);
      Node[] res;
      foreach (Node parent ; parents) {
        res ~= parent;
        foreach (Node child ; childs) {
          parent.addChild(child);
        }
      }
      return variantArray(res);
    }
    assert(false);
  };
  return res;
}

Parser mult() {
  auto factorized = (new Parser.Integer ~ Parser.match("*") ~ node()) ^^ (Variant[] input) {
    int f = input[0].get!(int);
    auto nodes = input[2].get!(Node[]);
    Node[] res;
    for (int i=0; i<f; i++) {
      foreach (Node n ; nodes) {
        res ~= new Node(n);
      }
    }
    return variantArray(res);
  };
  return factorized | node();
}

Parser node() {
  auto alnum = new Parser.AlnumParser ^^ (Variant[] input) {
    Node[] res;
    res ~= new Node(input[0].get!(string));
    return variantArray(res);
  };
  auto rec = (Parser.match("(") ~ lazyZen() ~ Parser.match(")")) ^^ (Variant[] input) {
    return input[1..$-1];
  };

  return alnum | rec;
}

void printResult(Variant r) {
  foreach (Node n ; r.get!(Node[])) {
    n.print();
  }
}

Object check(string s) {
  writefln("checking %s:", s);
  auto res = zen().parseAll(s);
  auto suc = cast(Parser.Success)(res);
  auto err = cast(Parser.Error)(res);
  if (err !is null) {
    writeln("could not parse: " ~ s ~ ": " ~ err.message);
    return null;
  }
  Variant r = suc.results[0];
  printResult(r);
  return res;
}

unittest {
  assert(check("a+a+a") !is null);

  assert(check("a") !is null);
  assert(check("5*a") !is null);
  assert(check("a>a") !is null);
  assert(check("a+a") !is null);

  assert(check("(a+b)>(c+d)") !is null);

  assert(check("a>(a+b+c)") !is null);
  assert(check("a>b+c+d") !is null);
  assert(check("a>b>(c>d)") !is null);
  assert(check("a+(b>c)+c") !is null);
  assert(check("a+b+c+d+e+f") !is null);
  assert(check("a>b>c>d>e>f") !is null);
  assert(check("a>b>2*(c+d)") !is null);
  assert(check("1+3*a>(a_1+a_2)+3") !is null);
}

int main(string[] args) {
  foreach (string input ; args[1..$]) {
    check(input);
  }
  return 0;
}
