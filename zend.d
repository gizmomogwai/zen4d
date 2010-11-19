import std.stdio;

import pc.parser;
import std.variant;
import std.array;


class Node {
  Node[] fChilds;
  string fName;
  string fId;
  string[] fClasses;
  int fMult;
  this(string name, int mult=1) {
    fName = name;
    fMult = mult;
  }
  void addChild(Node n) {
    fChilds ~= n;
  }
  void strangeAddChild(Node n) {
    if (fName.length == 0) {
      foreach (c;fChilds) {
        c.strangeAddChild(n);
      }
    } else {
      addChild(n);
    }
  }
  void printIndent(int nrOfIndents) {
    for (int i=0; i<nrOfIndents; i++) {
      write(" ");
    }
  }
  void print(int indent=0) {
    int newIndent = indent;
    for (int i=0; i<this.multiply; i++) {
      if (fName.length > 0) {
        printIndent(indent);
        write("<" ~ fName);
        if (fId !is null) {
          write(" id=\"" ~ fId ~ "\"");
        }
        if (fClasses.length > 0) {
          write(" class=\"" ~ std.string.join(fClasses, ",") ~ "\"");
        }
        write(">\n");
	newIndent = indent+2;
      }
      foreach (Node n ; fChilds) {
        n.print(newIndent);
      }
      if (fName.length > 0) {
        printIndent(indent);
        write("</" ~ fName ~ ">\n");
      }
    }
  }
  string toString() {
    string res = "Node " ~ fName;
    if (fId !is null) {
      res ~= "#" ~ fId;
    }
    foreach (c ; fClasses) {
      res ~= "." ~ c;
    }
    foreach (Node child ; fChilds) {
      res ~= "  " ~ child.toString();
    }
    return res;
  }
  void setId(string v) {
    if (fId !is null) {
      throw new Exception("id already set");
    }
    fId = v;
  }
  void addClass(string v) {
    fClasses ~= v;
  }
  @property int multiply() {
    return fMult;
  }
  @property void multiply(int m) {
    fMult = m;
  }
}


//       zen -> sibbling { + zen }
// sibbling  -> mult { > sibbling }
// mult      -> number * node | node
// node      -> element | (zen)
// element   -> alnum {id} {classes}
// id        -> # alnum
// classes   -> . alnum {classes}

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
          parent.strangeAddChild(child);
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
    foreach (Node n ; nodes) {
      n.multiply = f;
      res ~= n;
    }
    return variantArray(res);
  };
  return factorized | node();
}

Parser node() {
  auto rec = (Parser.match("(") ~ lazyZen() ~ Parser.match(")")) ^^ (Variant[] input) {
    Node res = new Node("");
    foreach (n;input[1..$-1]) {
      auto childs = n.get!(Node[])();
      foreach (c;childs) {
        res.addChild(c);
      }
    }
    Node[] nodes;
    nodes ~= res;
    return variantArray(nodes);
  };
  auto element = element() ^^ (Variant[] input) {
    Node res = new Node(input[0].get!(string)());

    int idx = 1;
    while (idx+1 < input.length) {
      string mod = input[idx].get!(string)();
      string value = input[idx+1].get!(string)();
      switch (mod) {
      case "#":
        res.setId(value);
        break;
      case ".":
        res.addClass(value);
        break;
      default:
        throw new Exception("unknown modifier: " ~ mod);
      }
      idx += 2;
    }

    Node[] nodes;
    nodes ~= res;
    return variantArray(nodes);
  };
  return element | rec;
}

// alnum ~ id ~ classes
Parser element() {
  auto alnum = new Parser.AlnumParser;
  auto id = id();
  auto classes = classes();
  return alnum ~ id ~ classes;
}

Parser id() {
  auto id = new Parser.Opt(Parser.match("#") ~ new Parser.AlnumParser);
  return id;
}

Parser lazyClasses() {
  return new Parser.LazyParser(&classes);
}

Parser classes() {
  return new Parser.Opt(Parser.match(".") ~ new Parser.AlnumParser ~ lazyClasses());
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
  assert(check("a#id.class1.class2>b") !is null);
  assert(check("2*a#id.class1.class2>b") !is null);
}

int main(string[] args) {
  foreach (string input ; args[1..$]) {
    check(input);
  }
  return 0;
}
