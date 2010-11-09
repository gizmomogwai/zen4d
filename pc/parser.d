module pc.parser;

import std.stdio;
import std.array;
import std.ctype;
import std.string;
import util.callable;

template Test(T) {
  T instanceof(Object o) {
    T res = cast(T)(o);
    if (res is null) {
      throw new Exception("typecast failed");
    } else {
      return res;
    }
  }
}

unittest {
  class A {
  }

  class B : A {
  }

  class C {
  }

  A a = new A;
  B b = new B;
  C c = new C;

  Object o = Test!(A).instanceof(a);
  o = Test!(B).instanceof(b);
  o = Test!(A).instanceof(b);
  o = Test!(C).instanceof(c);
}

class String {
  string fString;
  this(string s) {
    fString = s;
  }
  string toString() {
    return fString;
  }
}

abstract class Parser {
  Callable!(Object[], Object[]) fCallable = null;

  static class Result {
  }

  static class Success : Result {
    string fRest;
    Object[] fResults;
    this(string rest, Object[] result) {
      fRest = rest;
      fResults = result;
    }
    this(string rest, Object o) {
      fRest = rest;
      fResults ~= o;
    }
    @property string rest() {
      return fRest;
    }

    @property string rest(string rest) {
      return fRest = rest;
    }
    @property Object[] results() {
      return fResults;
    }

  }

  static class Error : Result {
    string fMessage;
    this(string message) {
      fMessage = message;
    }
  }

  Result parseAll(string s) {
    auto res = parse(s);
    if (typeid(res) == typeid(Success)) {
      auto success = cast(Success)(res);
      if ((success.rest is null) || (success.rest.length == 0)) {
        return res;
      } else {
        return new Error("string not completely consumed: " ~ success.rest);
      }
    } else {
      return res;
    }
  }

  Result parse(string s) {
    auto res = parse(s);
    return transform(res);
  }

  Parser opBinary(string op)(Object[] delegate(Object[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser opBinary(string op)(Object[] function(Object[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser setCallback(Object[] function(Object[] objects) tocall) {
    fCallable = new Callable!(Object[], Object[])(tocall);
    return this;
  }
  Parser setCallback(Object[] delegate(Object[] objects) tocall) {
    fCallable = new Callable!(Object[], Object[])(tocall);
    return this;
  }

  Result transform(Result result) {
    if (typeid(result) == typeid(Success)) {
      auto success = cast(Success)(result);
      return fCallable ? new Success(success.rest, fCallable(success.results)) : result;
    } else {
      return result;
    }
  }

  static class Matcher : Parser {
    string fExpected;

    this(string expected) {
      fExpected = expected;
    }

    Result parse(string s) {
      if (s.indexOf(fExpected) == 0) {
        string rest = s[fExpected.length..$];
        return transform(new Success(rest, new String(fExpected)));
      } else {
        return new Error("Expected: '" ~ fExpected ~ "' but got '" ~ s ~ "'");
      }
    }

    unittest {
      auto parser = new Matcher("test");
      Success res = cast(Success)(parser.parse("test"));
      assert(res !is null);
      assert(res.rest is null || res.rest.length == 0);
    }

    unittest {
      auto parser = new Matcher("test");
      auto res = cast(Error)(parser.parse("abc"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Matcher("test");
      Success suc = cast(Success)(parser.parse("test2"));
      assert(suc !is null);
      assert(suc.rest == "2");
      Error err = cast(Error)(parser.parseAll("test2"));
      assert(err !is null);
    }

    unittest {
      auto parser = match("test") ^^ (Object[] objects) {
        auto res = objects;
        if (objects[0].toString() == "test") {
          res[0] = new String("super");
        }
        return objects;
      };
      Success suc = cast(Success)(parser.parse("test"));
      assert(suc.results[0].toString() == "super");
    }

  }

  static class Or : Parser {
    Parser[] fParsers;

    this(Parser[] parsers ...) {
      fParsers = parsers;
    }

    Result parse(string s) {
      foreach (parser; fParsers) {
        auto res = parser.parse(s);
        if (typeid(res) == typeid(Success)) {
          return res;
        }
      }
      return new Error("or did not match");
    }

    unittest {
      auto parser = new Or(match("ab"), match("cd"));
      Success res = cast(Success)(parser.parse("ab"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      Success res = cast(Success)(parser.parse("cde"));
      assert(res !is null);
      assert(res.rest == "e");
    }
    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      Error res = cast(Error)(parser.parse("ef"));
      assert(res !is null);
    }
  }
  /+
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
  Callable!(Parser) fCallable;
  Parser fParser;

  this(Parser delegate() parser) {
    assert(parser != null);
    fCallable = new Callable!(Parser)(parser);
  }

  this(Parser function() parser) {
    assert(parser != null);
    fCallable = new Callable!(Parser)(parser);
  }

  Parser internalParse(string s) {
    fParser = fCallable();
    return fParser.internalParse(s);
  }

  string print(int indent) {
    return fParser.print(indent);
  }

  unittest {
    class Endless {
      // endless -> epsilon | "a" endless
      Parser lazyEndless() {
        return new LazyParser( {return endless;});
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
      return new LazyParser( {return expr;} );
    }
    Parser expr() {
      auto add = term() ~ match("+") ~ term();
      return add | term();
    }
    Parser term() {
      auto mult = factor() ~ match("*") ~ factor();
      return mult | factor();
    }
    Parser factor() {
      auto exprWithParens = match("(") ~ lazyExpr() ~ match(")");
      return new Number | exprWithParens;
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
  +/

  /**
   * convinient short for new Matcher()
   */
  static Parser match(string s) {
    return new Matcher(s);
  }

  unittest {
    auto parser = match("test");
    Success suc = cast(Success)(parser.parseAll("test"));
    assert(suc !is null);
  }
  /+
  Parser opBinary(string op)(Parser rhs) if (op == "|") {
    return new Or(this, rhs);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "~") {
    return new And(this, rhs);
  }

  /**
   * test
   */
  unittest {
    auto parser = match("a") | match("b");
    auto res = parser.parse("a");
    assert(res !is null);
    res = parser.parse("b");
    assert(res !is null);
    res = parser.parse("c");
    assert(res is null);
  }

  +/


}
