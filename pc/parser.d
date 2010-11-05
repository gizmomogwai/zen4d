module pc.parser;

import std.stdio;
import std.array;
import std.ctype;
import std.string;

class Wrapper(T, P) {
  T delegate(P) fDelegate;
  T function(P) fFunction;
  public this(T delegate(P) callback) {
    assert(callback != null);
    fDelegate = callback;
  }
  public this(T function(P) callback) {
    assert(callback != null);
    fFunction = callback;
  }
  T call(P p) {
    if (fDelegate != null) {
       return fDelegate(p);
    } else if (fFunction != null) {
      return fFunction(p);
    }
    return null;
  }
}

abstract class Parser {
  private string fRest = null;
  Wrapper!(Object, Parser) fCallable = null;
  Object parse(string s) {
    auto res = internalParse(s);
    if (fCallable !is null) {
      return fCallable.call(res);
    }
    return res;
  }

  abstract Parser internalParse(string s);

  string print(int indent = 0) {
    return "nyi";
  }

  string printIndent(int indent) {
    string res;
    for (int i=0; i<indent; i++) {
      res ~= " ";
    }
    return res;
  }

  @property string rest() {
    return fRest;
  }

  @property string rest(string rest) {
    return fRest = rest;
  }

  static class Matcher : Parser {
    string fExpected;
    this(string expected) {
      fExpected = expected;
    }
    Parser internalParse(string s) {
      if (s.indexOf(fExpected) == 0) {
        rest = s[fExpected.length..$];
        return this;
      } else {
        return null;
      }
    }

    string print(int indent) {
      return printIndent(indent) ~ "Matcher(" ~ fExpected ~ ")";
    }

    unittest {
      auto parser = Parser.match("test");
      Parser res = cast(Parser)(parser.parse("test"));
      assert(res == parser);
      assert(res.rest == null);
    }

    unittest {
      auto parser = Parser.match("test");
      auto res = parser.parse("abc");
      assert(res is null);
    }

    unittest {
      auto parser = Parser.match("test");
      Parser res = cast(Parser)(parser.parse("test2"));
      assert(res !is null);
      assert(res.rest == "2");
    }
  }

  static Parser match(string s) {
    return new Matcher(s);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "|") {
    return new Or(this, rhs);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "~") {
    return new And(this, rhs);
  }

  unittest {
    auto parser = match("a") | match("b");
    auto res = parser.parse("a");
    assert(res !is null);
    res = parser.parse("b");
    assert(res !is null);
    res = parser.parse("c");
    assert(res is null);
  }

  static class Or : Parser {
    Parser[] fParsers;
    Parser res;

    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Parser internalParse(string s) {
      foreach (parser; fParsers) {
        res = parser.internalParse(s);
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
      auto parser = new Or(match("ab"), match("cd"));
      auto res = parser.parse("ab");
      assert(res !is null);
    }

    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      Parser res = cast(Parser)(parser.parse("cde"));
      assert(res !is null);
      assert(res.rest == "e");
    }
    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      auto res = parser.parse("ef");
      assert(res is null);
    }
  }

  static class And : Parser {
    Parser[] fParsers;
    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Parser internalParse(string s) {
      string h = s;
      foreach (parser; fParsers) {
        Parser res = parser.internalParse(h);
        if (res !is null) {
          h = res.rest;
        } else {
          return null;
        }
      }
      rest = h;
      return this;
    }

    string print(int indent) {
      string res = printIndent(indent) ~ "AND(\n";
      foreach (parser ; fParsers) {
        res ~= parser.print(indent+2) ~ "\n";
      }
      res ~= printIndent(indent) ~ ")\n";
      return res;
    }

    unittest {
      auto parser = match("a") ~ match("b");
      auto res = parser.parse("ab");
      assert(res !is null);
    }
    unittest {
      auto parser = match("a") ~ match("b");
      auto res = parser.internalParse("abc");
      assert(res !is null);
      assert(res.rest == "c");
    }
    unittest {
      auto parser = match("a") ~ match("b");
      auto res = parser.parse("ac");
      assert(res is null);
    }
  }
}

class Epsilon : Parser {
  Parser internalParse(string s) {
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

}

class Number : Parser {
  string fNumber;
  Parser internalParse(string s) {
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

class AlnumParser : public Parser {
  string fContent;
  Parser internalParse(string s) {
    if (s.length == 0) {
      return null;
    }

    for (int i=0; i<s.length; i++) {
      auto c = s[i];
      if (!ispunct(c) && isalnum(s[i])) {
        fContent = fContent ~ s[i];
      } else {
        rest = s[fContent.length..$];
        break;
      }
    }
    if (fContent.length == 0) {
      return null;
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
    AlnumParser parser = new AlnumParser;
    AlnumParser res = cast(AlnumParser)parser.parse("abc+");
    assert(res == parser);
    assert(res.rest == "+");
    assert(res.fContent == "abc");
  }
  unittest {
    assert(ispunct(')'));
    auto parser = new AlnumParser;
    auto res = parser.parse("(");
    assert(res is null);
  }
}



class Opt : Parser {
  Parser fParser;
  Parser fRes;
  this(Parser parser) {
    fParser = parser;
  }
  Parser internalParse(string s) {
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
  Parser internalParse(string s) {
    fRes = fParser.internalParse(s);
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
  Parser internalParse(string s) {
    return this;
  }
  string print(int indent) {
    return printIndent(indent) ~ "None";
  }
}

class Repeat : Parser {
  Parser fToRepeat;
  Parser[] fRes;
  this(Parser toRepeat) {
    fToRepeat = toRepeat;
  }

  Parser internalParse(string s) {
    rest = s;
    while (true) {
      auto res = fToRepeat.internalParse(this.rest);
      if (res !is null) {
        rest = res.rest;
        fRes ~= res;
      } else {
        break;
      }
    }
    return this;
  }

  string print(int indent) {
    string res = printIndent(indent) ~ "Repeat(\n";
    foreach (child ; fRes) {
      res ~= child.print(indent+2);
    }
    res ~= printIndent(indent) ~ ")\n";
    return res;
  }

  unittest {
    auto parser = new Repeat(new Matcher("a"));
    auto res = parser.internalParse("aaaaaaaaaaaaaaaaa");
    assert(res !is null);
    assert(res.rest == "");
  }
  unittest {
    auto parser = new Repeat(new Matcher("a"));
    auto res = parser.internalParse("b");
    assert(res !is null);
    assert(res.rest == "b");
  }
  unittest {
    auto parser = new Repeat(new Matcher("a"));
    auto res = parser.parse("ab");
    assert(res !is null);
  }
  unittest {
    auto parser = new Repeat(match("+") ~ match("-"));
    auto res =parser.internalParse("+-+-+");
    assert(res !is null);
    assert(res.rest == "+");
  }
}


class LazyParser : Parser {
  Parser delegate() fDelegate;
  Parser function() fFunction;
  Parser fParser;

  this(Parser delegate() parser) {
    assert(parser != null);
    fDelegate = parser;
  }

  this(Parser function() parser) {
    assert(parser != null);
    fFunction = parser;
  }

  Parser internalParse(string s) {
    if (fDelegate != null) {
      fParser = fDelegate();
    } else if (fFunction != null) {
      fParser = fFunction();
    }
    return fParser.internalParse(s);
  }

  string print(int indent) {
    return fParser.print(indent);
  }

  unittest {
    class Endless {
      // endless -> epsilon | "a" endless
      Parser lazyEndless() {
        return new LazyParser(delegate Parser() {
          return endless;
        });
      }
      Parser endless() {
        return new Or(new And(match("a"), lazyEndless()), new Epsilon());
      }
    }
    auto parser = new Endless;
    auto p = parser.endless();
    auto res = p.parse("aa");
    assert(res !is null);
    res = p.parse("aab");
    assert(res is null);
  }

  // expr -> term { + term }
  // term -> factor { * factor }
  // factor -> number | ( expr )

  static class ExprParser {
    Parser lazyExpr() {
      return new LazyParser(delegate Parser() {
        return expr;
      });
    }
    Parser expr() {
      return new And(term(), new Repeat(new And(new Matcher("+"), term())));
    }
    Parser term() {
      return new And(factor(), new Repeat(new And(new Matcher("*"), factor())));
    }
    Parser factor() {
      return new Or(new Number, new And(new Matcher("("), lazyExpr(), new Matcher(")")));
    }
  }

  unittest {
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = p.parse("1+2*3");
    assert(res !is null);
  }
  unittest {
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = p.parse("1*2+3");
    assert(res !is null);
  }
  unittest {
    static Parser help() {
      return new Matcher("a");
    }
    auto parser = new LazyParser(&help);
    auto res = parser.parse("a");
    assert(res !is null);
  }
}
