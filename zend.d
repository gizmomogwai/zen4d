import std.stdio;

import pc.parser;
import std.variant;
import std.array;
import std.file;
import std.string;
import std.algorithm;

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
      foreach (c; fChilds) {
        c.strangeAddChild(n);
      }
    } else {
      addChild(n);
    }
  }

  string printIndent(int nrOfIndents) {
    string res;
    for (int i=0; i<nrOfIndents; i++) {
      res ~= " ";
    }
    return res;
  }

  string print(int indent=0) {
    string res;
    int newIndent = indent;
    for (int i=0; i<this.multiply; i++) {
      if (fName.length > 0) {
        res ~= printIndent(indent);
        res ~= "<" ~ fName;
        if (fId !is null) {
          res ~= " id=\"" ~ fId ~ "\"";
        }
        if (fClasses.length > 0) {
          res ~= " class=\"" ~ std.string.join(fClasses, ",") ~ "\"";
        }
        res ~= ">\n";
        newIndent = indent+2;
      }
      foreach (Node n ; fChilds) {
        res ~= n.print(newIndent);
      }
      if (fName.length > 0) {
        res ~= printIndent(indent);
        res ~= "</" ~ fName ~ ">\n";
      }
    }
    return res;
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
class ZenParserAst : ZenParser {
  Parser element() {
    return super.element() ^^ (Variant[] input) {
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

      return variantArray([res]);
    };
  }
  Parser rec() {
    return super.rec() ^^ (Variant[] input) {
      Node res = new Node("");
      foreach (n; input) {
        auto childs = n.get!(Node[])();
        foreach (c; childs) {
          res.addChild(c);
        }
      }
      return variantArray([res]);
    };
  }
  Parser factorized() {
    return super.factorized() ^^ (Variant[] input) {
      int f = input[0].get!(int);
      auto nodes = input[1].get!(Node[]);
      auto res = appender!(Node[])();
      foreach (Node n ; nodes) {
        n.multiply = f;
        res.put(n);
      }
      return variantArray(res.data);
    };
  }
  Parser sibbling() {
    return super.sibbling() ^^ (Variant[] input) {
      if (input.length == 1) {
        return input;
      } else if (input.length == 2) {
        auto parents = input[0].get!(Node[]);
        auto childs = input[1].get!(Node[]);
        auto res = appender!(Node[])();
        foreach (Node parent ; parents) {
          res.put(parent);
          foreach (Node child ; childs) {
            parent.strangeAddChild(child);
          }
        }
        return variantArray(res.data);
      }
      assert(false);
    };
  }
  Parser zen() {
    return super.zen() ^^ (Variant[] input) {
      auto res = appender!(Node[])();
      foreach (Node n; input[0].get!(Node[])) {
        res.put(n);
      }
      if (input.length > 1) {
        foreach (Node n; input[1].get!(Node[])) {
          res.put(n);
        }
      }
      return variantArray(res.data);
    };
  }
}

class ZenParser : Parser {

  Parser lazyZen() {
    return new LazyParser(&zen);
  }

  Parser zen() {
    return sibbling() ~ new Opt(nextZen());
  }

  Parser nextZen() {
    return match("+", false) ~ lazyZen();
  }
  Parser lazySibbling() {
    return new LazyParser(&sibbling);
  }

  Parser nextSibbling() {
    return match(">", false) ~ lazySibbling();
  }
  Parser sibbling() {
    return mult() ~ new Opt(nextSibbling());
  }

  Parser mult() {
    return factorized() | node();
  }
  Parser factorized() {
    return new Integer ~ match("*", false) ~ node();
  }

  Parser node() {
    return element() | rec();
  }

  Parser rec() {
    return match("(", false) ~ lazyZen() ~ Parser.match(")", false);
  }

  Parser element() {
    auto alnum = new AlnumParser;
    auto id = id();
    auto classes = classes();
    return alnum ~ id ~ classes;
  }

  Parser id() {
    auto id = new Opt(match("#") ~ new AlnumParser);
    return id;
  }

  Parser lazyClasses() {
    return new LazyParser(&classes);
  }

  Parser classes() {
    return new Opt(match(".") ~ new AlnumParser ~ lazyClasses());
  }
}


void printResult(Variant r) {
  foreach (Node n ; r.get!(Node[])) {
    write(n.print());
  }
}

Object check(string s) {
  writefln("checking %s:", s);
  auto zen = new ZenParserAst;
  auto res = zen.zen().parseAll(s);
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
  void showError(string expected, string got) {
    for (int i=0; i<max(expected.length, got.length); i++) {
      auto c1 = ' ';
      auto c2 = c1;
      if (i < expected.length) {
        c1 = expected[i];
      }
      if (i < got.length) {
        c2 = got[i];
      }
      if (c1 != c2) {
        writeln("error: expected " ~c1 ~ " got " ~ c2);
      } else {
        write(c1);
      }
    }
  }

  foreach (string inputpath; dirEntries("testdata/in", SpanMode.breadth)) {
    string outputpath = inputpath.replace("in", "out");
    writefln("comparing %s with %s", inputpath, outputpath);
    string input = (cast(string)(read(inputpath))).strip();
    string expected = (cast(string)(read(outputpath.replace("in", "out")))).strip();
    auto zen = new ZenParserAst;
    auto suc = cast(Parser.Success)(zen.zen().parseAll(input));
    assert(suc !is null);
    string output;
    foreach (n;suc.results[0].get!(Node[])) {
      output ~= n.print();
    }
    output = output.strip();
    if (expected != output) {
      writeln("problem in " ~ inputpath);
      showError(expected, output);
    }
    assert(expected == output);
  }
  /+
  assert(check("a+a+a") !is null); // 1

  assert(check("a") !is null); // 2
  assert(check("5*a") !is null); // 3
  assert(check("a>a") !is null); // 4

  assert(check("(a+b)>(c+d)") !is null); // 5

  assert(check("a>(a+b+c)") !is null); // 6
  assert(check("a>b+c+d") !is null); // 7
  assert(check("a>b>(c>d)") !is null); // 8
  assert(check("a+(b>c)+c") !is null); // 9
  assert(check("a+b+c+d+e+f") !is null); // 10
  assert(check("a>b>c>d>e>f") !is null); // 11
  assert(check("a>b>2*(c+d)") !is null); // 12
  assert(check("1+3*a>(a_1+a_2)+3") !is null); // 13
  assert(check("a#id.class1.class2>b") !is null); // 14
  assert(check("2*a#id.class1.class2>b") !is null); // 15
+/
}

int main(string[] args) {
  foreach (string input ; args[1..$]) {
    check(input);
  }
  return 0;
}
