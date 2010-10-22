import std.stdio;
import std.array;
import std.ctype;
import std.string;

class Node {
  void print(int ident=0) {
       writeln("Not implemented");
  }
}

class ContentNode : Node {
  string fContent;
  this(string content) {
    fContent = content;
  }
  void printSpaces(int ident) {
    for (int i=0; i<ident; i++) {
      write(" ");
    }
  }

  void print(int ident) {
    printSpaces(ident);
    writefln("<%s>", fContent);
    printSpaces(ident);
    writefln("</%s>", fContent);
  }
}

class Result {
  string fInput;
  Node[] fNodes;
  this() {
    fInput = null;
    fNodes = null;
  }
  this(string input, Node node) {
    fInput = input;
    fNodes = fNodes ~ node;
  }
  this(string input, Node[] nodes) {
    fInput = input;
    fNodes = nodes;
  }
}

class Parser {
      string fRest;
      this() {
        fRest = null;
      }
      Parser parse(string s) {
        return null;
      }
      void print(int indent = 0) {
      }
      void printIndent(int indent) {
        for (int i=0; i<indent; i++) {
          write(" ");
        }
      }
      void setRest(string rest) {
        fRest = rest;
      }
      @property string rest() { return fRest; }
      @property string rest(string rest) { return fRest = rest; }
}

class Epsilon : Parser {
  Parser parse(string s) {
    if (s.length == 0) {
      return this;
    } else {
      return null;
    }
  }
  void print(int indent=0) {
    printIndent(indent);
    writeln("Epsilon");
  }
  unittest {
     auto parser = new Epsilon;
     auto res = parser.parse("");
     assert(res == parser);
     res = parser.parse("a");
     assert(res is null);
  }
}

class Matcher : Parser {
      string fExpected;
      this(string expected) {
        fExpected = expected;
      }
      Parser parse(string s) {
        if (s.indexOf(fExpected) == 0) {
	  setRest(s[fExpected.length..$]);
	  return this;
	} else {
          return null;
	}
      }

      unittest {
        auto parser = new Matcher("test");
	auto res = parser.parse("test");
	assert(res == parser);
	assert(res.rest == null);
      }

      unittest {
        auto parser = new Matcher("test");
	auto res = parser.parse("abc");
	assert(res is null);
      }

      unittest {
        auto parser = new Matcher("test");
	auto res = parser.parse("test2");
	assert(res == parser);
	assert(res.rest == "2");
      }
}


class AlnumParser : public Parser {
  string content;
  Parser parse(string s) {
    if (s.length == 0) {
      return null;
    }

    for (int i=0; i<s.length; i++) {
    	if (isalnum(s[i])) {
	  content = content ~ s[i];
	} else {
	  this.rest = s[content.length..$];
	  return this;
	}
    }
    return this;
  }
  void print(int indent) {
    printIndent(indent);
    writeln(content);
  }

  unittest {
    AlnumParser parser = new AlnumParser();
    AlnumParser res = cast(AlnumParser)parser.parse("abc");
    assert(res == parser);
    assert(res.rest == null);
    assert(res.content == "abc");
  }
  unittest {
    AlnumParser parser = new AlnumParser();
    AlnumParser res = cast(AlnumParser)parser.parse("abc+");
    assert(res == parser);
    assert(res.rest == "+");
    assert(res.content == "abc");
  }
}

class Or : Parser {
      Parser[] fParsers;
      Parser res;
      this(Parser[] parsers ...) {
        fParsers = parsers.dup;
      }

      Parser parse(string s) {
        foreach (parser; fParsers) {
	  res = parser.parse(s);
	  if (res !is null) {
	     return res;
	  }
	}
	return null;
      }

      void print(int indent) {
        res.print(indent+2);
      }

      unittest {
        auto abParser = new Matcher("ab");
	auto cdParser = new Matcher("cd");
        auto parser = new Or(abParser, cdParser);
	auto res = parser.parse("ab");
	assert(res == abParser);
      }

      unittest {
        auto abParser = new Matcher("ab");
	auto cdParser = new Matcher("cd");
        auto parser = new Or(abParser, cdParser);
	auto res = parser.parse("cd");
	assert(res == cdParser);
      }
      unittest {
        auto abParser = new Matcher("ab");
	auto cdParser = new Matcher("cd");
        auto parser = new Or(abParser, cdParser);
	auto res = parser.parse("ef");
	assert(res is null);
      }
}

class And : Parser {
      Parser[] fParsers;
      this(Parser[] parsers ...) {
        fParsers = parsers.dup;
      }
      Parser parse(string s) {
        string h = s;
        foreach (parser; fParsers) {
	  auto res = parser.parse(h);
          if (res !is null) {
	    h = res.rest;
	  } else {
            return null;
	  }
	}
        return this;
      }
      void print(int indent) {
        foreach (parser ; fParsers) {
	  parser.print(indent+2);
	}
      }
    unittest {
      auto parser = new And(new Matcher("a"), new Matcher("b"));
      auto res = parser.parse("ab");
      assert(res == parser);
    }
    unittest {
      auto parser = new And(new Matcher("a"), new Matcher("b"));
      auto res = parser.parse("ac");
      assert(res is null);
    }
}


class LazyParser : Parser {
  Parser delegate() fDg;
  Parser fParser;
  this(Parser delegate() parser) {
    fDg = parser;
  }
  Parser parse(string s) {
    fParser = fDg();
    return fParser.parse(s);
  }
  void print(int indent) {
    fParser.print(indent);
  }
  unittest {
    // endless -> epsilon | "a" endless
    Parser endless() {
        return new Or(new Epsilon, new And(new Matcher("a"), new LazyParser(delegate Parser() { return endless; })));
    }
    auto parser = endless();
    auto res = parser.parse("aa");
    assert(res !is null);
    res = parser.parse("aaaaaaaaaaaaaaaaaaaaaab");
    assert(res is null);
  }
}

class MyParser {
/*
      static Parser getit() {
      }
*/
/*
      expr
      expr -> (expr+expr) | (expr>expr)
  */
/*
     static Parser match(string s) {
       return new Matcher(s);
     }

      static Parser and(Parser[] parsers ...) {
	     return new And(parsers);
      }
      static Parser or(Parser[] parsers ...) {
      	     return new Or(parsers);
      }
      static Parser epsilon() {
        return new Epsilon;
      }
*/

/*
  nodes
  nodes -> epsilon | node"+"nodes
  node -> name | name">"nodes

*/

/*
      static Parser nodes() {
        return and(node(), match("+"), nodes());
      }
*/
/*
      static Parser my() {
          return and(new AsciiParser(), new Matcher(">"), new AsciiParser());
//      	  return new LazyParserdelegate Parser() { return new Matcher("a"); });
      }
*/

/*
      static Parser expr() {
        Parser p = new Or(new And(new LazyParser(&expr),
                                  new Match("+"),
  				  new LatyParser(&expr)),
		          new And(new LazyParser(&expr), new Match(">"), new LazyParser(&expr)));
        return new LazyParser(&p.parse);
      }

      static Parser child() {
      	     Parser p = new Matcher(">");
      	     return new LazyParser(&p.parse);
      }
*/
}

int main(string[] args) {
     auto input = args[1];
/*
     if (result is null) {
     	writeln("result null");
	return 1;
     }
     if (result.fNodes !is null) {
       foreach (node; result.fNodes) {
         node.print();
       }
       if (result.fInput !is null) {
         if (result.fInput.length > 0) {
           writefln("warning .. still input available: %s", result.fInput);
         }
       }
     } else {
       writefln("no match");
     }
/*
     auto parser = new Parser;
     foreach (c; input) {
       parser.consume(c);
     }
     auto tree = parser.finish();
     tree.print();
*/
     return 0;
}