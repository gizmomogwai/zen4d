import std.stdio;
import std.array;
import std.ctype;
import std.string;

abstract class Parser {
      string fRest;

      this() {
        fRest = null;
      }

      Parser parse(string s) {
        return null;
      }

      abstract string print(int indent = 0);

      string printIndent(int indent) {
        string res;
        for (int i=0; i<indent; i++) {
          res ~= " ";
        }
	return res;
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
  string print(int indent=0) {
    return printIndent(indent) ~ "epsilon";
  }

  unittest {
     auto parser = new Epsilon;
     auto res = parser.parse("");
     assert(res == parser);
     res = parser.parse("a");
     assert(res is null);
  }

  unittest {
    auto parser = new Epsilon;
    auto s = parser.print(4);
    assert(s == "    epsilon");
  }
}

class Number : Parser {
  string fNumber;
  Parser parse(string s) {
    for (int i=0; i<s.length; i++) {
    	if (isdigit(s[i])) {
	  fNumber = fNumber ~ s[i];
	} else {
	  if (fNumber.empty) {
            return null;
	  } else {
	    this.rest = s[fNumber.length..$];
	    return this;
          }
	}
    }
    return this;
  }
  string print(int indent) {
    return printIndent(indent) ~ "Number(" ~ fNumber ~ ")";
  }

  unittest {
    Number parser = new Number;
    Number res = cast(Number)parser.parse("1234");
    assert(res.fNumber == "1234");
  }
  unittest {
    Number parser = new Number;
    Number res = cast(Number) parser.parse("123a");
    assert(res !is null);
    assert(res.rest == "a");
  }
  unittest {
    Number parser = new Number;
    auto res = parser.parse("abc");
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

      string print(int indent) {
        return printIndent(indent) ~ "Matcher(" ~ fExpected ~ ")";
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
  string fContent;
  Parser parse(string s) {
    if (s.length == 0) {
      return null;
    }

    for (int i=0; i<s.length; i++) {
    	if (isalnum(s[i])) {
	  fContent = fContent ~ s[i];
	} else {
	  this.rest = s[fContent.length..$];
	  return this;
	}
    }
    return this;
  }
  string print(int indent) {
    return printIndent(indent) ~ "Alnum(" ~ fContent ~ ")";
  }

  unittest {
    AlnumParser parser = new AlnumParser();
    AlnumParser res = cast(AlnumParser)parser.parse("abc");
    assert(res == parser);
    assert(res.rest == null);
    assert(res.fContent == "abc");
  }
  unittest {
    AlnumParser parser = new AlnumParser();
    AlnumParser res = cast(AlnumParser)parser.parse("abc+");
    assert(res == parser);
    assert(res.rest == "+");
    assert(res.fContent == "abc");
  }
  unittest {
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

      string print(int indent) {
        return printIndent(indent) ~ "OR(\n" ~ res.print(indent+2) ~ "\n" ~ printIndent(indent) ~ ")";
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
      string print(int indent) {
        string res = printIndent(indent) ~ "AND(\n";
        foreach (parser ; fParsers) {
	  res = res ~ parser.print(indent+2) ~ "\n";
	}
        res ~= printIndent(indent) ~ ")\n";
	return res;
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

class Opt : Parser {
  Parser fParser;
  Parser fRes;
  this(Parser parser) {
    fParser = parser;
  }
  Parser parse(string s) {
    auto res = fParser.parse(s);
    if (res is null) {
      fRes = new None;
    } else {
      fRes = fParser;
    }
    return this;
  }
  string print(int indent) {
    return printIndent(indent) ~ "opt(\n" ~ fRes.print(indent+2) ~ ")";
  }
  unittest {
    auto abc = new Matcher("abc");
    auto opt = new Opt(abc);
    auto res = opt.parse("abc");
    assert(res !is null);
  }
  unittest {
    auto abc = new Matcher("abc");
    auto opt = new Opt(abc);
    auto res = opt.parse("efg");
    assert(res !is null);
  }
}

class Float : Parser {
  Parser fParser;
  Parser fRes;
  this() {
    fParser = new And(new Number, new Opt(new And(new Matcher("."), new Opt(new Number))));
  }
  Parser parse(string s) {
    fRes = fParser.parse(s);
    if (fRes !is null) {
      return this;
    }
    return null;
  }
  string print(int indent) {
    return printIndent(indent) ~ "Float\n" ~ fRes.print(indent) ~ ")";
  }

  unittest {
    auto parser = new Float;
    auto res = parser.parse("abc");
    assert(res is null);
  }

  unittest {
    auto parser = new Float;
    auto res = parser.parse("1234");
    assert(res !is null);
  }

  unittest {
    auto parser = new Float;
    auto res = parser.parse("1234.123");
    assert(res !is null);
  }
  unittest {
    auto parser = new Float;
    auto res = parser.parse("1234.123a");
    assert(res !is null);
  }
  unittest {
    auto parser = new Float;
    auto res = parser.parse("1234.");
    assert(res !is null);
  }
}


class None : Parser {
  Parser parse(string s) { return this; }
  string print(int indent) {
    return printIndent(indent) ~ "None";
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
  string print(int indent) {
    return fParser.print(indent);
  }
  unittest {
    // endless -> epsilon | "a" endless
    Parser endless() {
        return new Or(new Epsilon, new And(new Matcher("a"), new LazyParser(delegate Parser() { return endless; })));
    }
    auto parser = endless();
    auto res = parser.parse("aaaaaaaaaaaaaaaa");
    assert(res !is null);
    writeln(res.print());
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
      static Parser digit() {
        
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

class Help {
  string toString() {
    return "myhelp";
  }
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