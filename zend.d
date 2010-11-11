/+
import pc.parser;
import std.stdio;

unittest {
  class Help {
    int delegate(string) fDg;
    this(int delegate(string)dg) {
      fDg = dg;
    }
    void run() {
      writeln(fDg("1"));
    }
  }

  class Test {
    this() {
      Help h = new Help(&blub);
    }
    int blub(string s) {
      writeln("using blub");
      return 1;
    }
  }
}

class ZendParser : Parser {

  //           zen -> nodeWithChild | nodeWithSibbling | node epsilon
  // nodeWithChild -> node > zen
  // nodeWithSibbling -> node + zen
  // node -> alnum | ( zen )

  Parser lazyZen() {
    return new LazyParser(&zen);
  }

  Parser zen() {
    return nodeWithChild() | nodeWithSibbling() | node();
  }

  Parser node() {
    return new AlnumParser | (match("(") ~ lazyZen() ~ match(")"));
  }
  Parser nodeWithChild() {
    return node() ~ match(">") ~ lazyZen();
  }
  Parser nodeWithSibbling() {
    return node() ~ match("+") ~ lazyZen();
  }

  Parser internalParse(string s) {
    return zen().internalParse(s);
  }
  string print(int indent) {
    return "zen";
  }

  unittest {
    Object check(string s) {
      writeln("checking " ~ s);
      auto parser = new ZendParser;
      auto res = parser.parse(s);
      return res;
    }
    assert(check("a") !is null);
    assert(check("a>a") !is null);
    assert(check("a+a") !is null);
    assert(check("a>(a+b)") !is null);
    assert(check("a>b+c+d") !is null);
    assert(check("a>b>(c>d)") !is null);
    assert(check("a+(b>c)+c") !is null);
    assert(check("a+b+c+d+e+f") !is null);
    assert(check("a>b>c>d>e>f") !is null);
  }

}
+/
int main(string[] args) {
//  auto input = args[1];
  return 0;
}
