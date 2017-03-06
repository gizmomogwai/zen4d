import std.stdio;

import pc4d;
import pc4d.parsers;
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

  string toHaml(int indent=0) {
    string res;
    int newIndent = indent;
    for (int i=0; i<this.multiply; i++) {
      if (fName.length > 0) {
        res ~= printIndent(indent);
        res ~= "%" ~ fName;
        newIndent = indent+2;
      }
      if (fId !is null) {
        res ~= "#" ~fId;
      }
      if (fClasses.length > 0) {
        res ~= "." ~ std.string.join(fClasses, ".");
      }
      if (fName.length > 0) {
        res ~= "\n";
      }
      foreach (n; fChilds) {
        res ~= n.toHaml(newIndent);
      }
    }
    return res;
  }

  string toHtml(int indent=0) {
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
      foreach (n ; fChilds) {
        res ~= n.toHtml(newIndent);
      }
      if (fName.length > 0) {
        res ~= printIndent(indent);
        res ~= "</" ~ fName ~ ">\n";
      }
    }
    return res;
  }

  override string toString() {
    string res = "Node " ~ fName;
    if (fId !is null) {
      res ~= "#" ~ fId;
    }
    foreach (c ; fClasses) {
      res ~= "." ~ c;
    }
    foreach (child ; fChilds) {
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
  override StringParser element() {
    return super.element() ^^ (input) {
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
  override StringParser rec() {
    return super.rec() ^^ (input) {
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
  override StringParser factorized() {
    return super.factorized() ^^ (input) {
      int f = input[0].get!(int);
      auto nodes = input[1].get!(Node[]);
      auto res = appender!(Node[])();
      foreach (n ; nodes) {
        n.multiply = f;
        res.put(n);
      }
      return variantArray(res.data);
    };
  }
  override StringParser sibbling() {
    return super.sibbling() ^^ (input) {
      if (input.length == 1) {
        return input;
      } else if (input.length == 2) {
        auto parents = input[0].get!(Node[]);
        auto childs = input[1].get!(Node[]);
        auto res = appender!(Node[])();
        foreach (parent ; parents) {
          res.put(parent);
          foreach (child ; childs) {
            parent.strangeAddChild(child);
          }
        }
        return variantArray(res.data);
      }
      assert(false);
    };
  }
  override StringParser zen() {
    return super.zen() ^^ (input) {
      auto res = appender!(Node[])();
      foreach (n; input[0].get!(Node[])) {
        res.put(n);
      }
      if (input.length > 1) {
        foreach (n; input[1].get!(Node[])) {
          res.put(n);
        }
      }
      return variantArray(res.data);
    };
  }
}

alias Parser!(immutable(char)) StringParser;

class ZenParser : StringParser {

  StringParser lazyZen() {
    return lazyParser(&zen);
  }

  StringParser zen() {
    return sibbling() ~ -nextZen();
  }

  StringParser nextZen() {
    return match("+", false) ~ lazyZen();
  }
  StringParser lazySibbling() {
    return lazyParser(&sibbling);
  }

  StringParser nextSibbling() {
    return match(">", false) ~ lazySibbling();
  }
  StringParser sibbling() {
    return mult() ~ -nextSibbling();
  }

  StringParser mult() {
    return factorized() | node();
  }

  StringParser factorized() {
    return integer!(immutable(char))() ~ match("*", false) ~ node();
  }

  StringParser node() {
    return element() | rec();
  }

  StringParser rec() {
    return match("(", false) ~ lazyZen() ~ match(")", false);
  }

  StringParser element() {
    auto id = id();
    auto classes = classes();
    return alnum!(immutable(char))() ~ id ~ classes;
  }

  StringParser id() {
    auto id = -(match("#") ~ alnum!(immutable(char))());
    return id;
  }

  StringParser lazyClasses() {
    return lazyParser(&classes);
  }

  StringParser classes() {
    return -(match(".") ~ alnum!(immutable(char))() ~ lazyClasses());
  }
}

string doHtml(Node n) {
  return n.toHtml();
}
string doHaml(Node n) {
  return n.toHaml();
}

void printResult(Variant r, string function(Node) whatToDo) {
  foreach (n ; r.get!(Node[])) {
    write(whatToDo(n));
  }
}


Object check(string s, string function(Node) whatToDo) {
  //  writefln("checking %s:", s);
  auto zen = new ZenParserAst;
  auto res = zen.zen().parseAll(s);
  if (!res.success) {
    writeln("could not parse: " ~ s ~ ": " ~ res.message);
    return null;
  }
  Variant r = res.results[0];
  printResult(r, whatToDo);
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
        debug { writeln("error: expected '" ~c1 ~ "' got '" ~ c2 ~ "'"); }
      } else {
        debug { write(c1); }
      }
    }
  }


  void compare(string inputpath, string outputpath, string function(Node) whatToCall) {
    string input = (cast(string)(read(inputpath))).strip();
    string expected = (cast(string)(read(outputpath.replace("in", "out")))).strip();
    auto zen = new ZenParserAst;
    auto res = zen.zen().parseAll(input);
    assert(res.success);
    string output;
    debug { writeln("input: " ~input); }
    debug { writeln("expected: " ~expected); }
    foreach (n;res.results[0].get!(Node[])) {
      output ~= whatToCall(n);
    }
    output = output.strip();
    debug { writeln("got: " ~output); }
    if (expected != output) {
      debug { writeln("problem in " ~ inputpath); }
      showError(expected, output);
    }
    assert(expected == output);

  }
  foreach (string inputpath; dirEntries("testdata/in", SpanMode.breadth)) {
    auto outputpath = inputpath.replace("in", "out");

    auto html = outputpath ~ ".html";
    debug { writefln("comparing %s with %s", inputpath, html); }
    compare(inputpath, html, &doHtml);

    auto haml = outputpath ~ ".haml";
    debug { writefln("comparing %s with %s", inputpath, haml); }
    compare(inputpath, haml, &doHaml);
  }

}

int zen(string[] args) {
  auto startIdx = 1;
  auto toDo = &doHtml;
  if (args.length > 1) {
    startIdx = 1;
    if (args[1] == "-h") {
      startIdx = 2;
      toDo = &doHaml;
    }
  }
  foreach (string input ; args[startIdx..$]) {
    check(input, toDo);
  }
  return 0;
}
