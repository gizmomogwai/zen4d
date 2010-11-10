module pc.parser;

import std.stdio;
import std.array;
import std.ctype;
import std.string;
import util.callable;
import std.regexp;

class String {
  string fString;
  this(string s) {
    fString = s;
  }
  string get() {
    return fString;
  }
  string toString() {
    return "String '" ~ fString ~ "'";
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
    @property string message() {
      return fMessage;
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
    throw new Exception("must be implemented in childs");
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
        if (objects[0].toString() == "String 'test'") {
          res[0] = new String("super");
        }
        return objects;
      };
      Success suc = cast(Success)(parser.parse("test"));
      assert(suc.results[0].toString() == "String 'super'");
    }

  }

  static class Or : Parser {
    Parser[] fParsers;

    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Result parse(string s) {
      foreach (parser; fParsers) {
        Result res = parser.parse(s);
        if (cast(Success)(res) !is null) {
          return transform(res);
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

  static class And : Parser {
    Parser[] fParsers;
    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Result parse(string s) {
      auto resultObjects = appender!(Object[])();
      string h = s;
      foreach (parser; fParsers) {
        Result res = parser.parse(h);
        Success suc = cast(Success)(res);
        Error err = cast(Error)(res);
        if (suc !is null) {
          h = suc.rest;
          resultObjects.put(suc.results);
        } else {
          return err;
        }
      }
      return transform(new Success(h, resultObjects.data));
    }

    unittest {
      auto parser = new And(match("a"), match("b") );
      auto res = cast(Success)(parser.parse("ab"));
      assert(res !is null);
      assert(res.results.length == 2);
    }

    unittest {
      auto parser = new And(match("a"), match("b"));
      auto res = cast(Success)(parser.parse("abc"));
      assert(res !is null);
      assert(res.rest == "c");
    }

    unittest {
      auto parser = new And(match("a"), match("b"));
      auto res = cast(Error)(parser.parse("ac"));
      assert(res !is null);
    }

    unittest {
      auto parser = new And(match("a"), match("b"));
      parser ^^ (Object[] result) {
        Object[] res;
        string totalString;
        foreach (Object o ; result) {
          String s = cast(String)(o);
          totalString ~= s.get();
        }
        res ~= new String(totalString);
        return res;
      };

      Success suc = cast(Success)(parser.parse("ab"));
      assert(suc.results.length == 1);
      assert((cast(String)(suc.results[0])).get() == "ab");
    }
  }

  static class Opt : Parser {

    Parser fParser;

    this(Parser parser) {
      fParser = parser;
    }

    Result parse(string s) {
      auto res = fParser.parse(s);
      if (cast(Error)(res) !is null) {
        Object[] results;
        return new Success(s, results);
      } else {
        return res;
      }
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Opt(abc);
      auto res = cast(Success)(opt.parse("abc"));
      assert(res !is null);
      assert(res.rest.length == 0);
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Opt(abc);
      auto res = cast(Success)(opt.parse("efg"));
      assert(res !is null);
      assert(res.rest == "efg");
    }
  }


  static class Repeat : Parser {
    Parser fToRepeat;
    this(Parser toRepeat) {
      fToRepeat = toRepeat;
    }

    Result parse(string s) {
      auto results = appender!(Object[])();
      auto rest = s;
      while (true) {
        auto res = fToRepeat.parse(rest);
        Success suc = cast(Success)(res);
        if (suc !is null) {
          rest = suc.rest;
          results.put(suc.results);
        } else {
          break;
        }
      }
      return new Success(rest, results.data);
    }

    unittest {
      auto parser = new Repeat(new Matcher("a"));
      Success res = cast(Success)(parser.parse("aa"));
      assert(res !is null);
      assert(res.rest == "");
    }
    unittest {
      auto parser = new Repeat(new Matcher("a"));
      Success res = cast(Success)(parser.parse("b"));
      assert(res !is null);
      assert(res.rest == "b");
    }
    unittest {
      auto parser = new Repeat(new Matcher("a"));
      Success res = cast(Success)(parser.parse("ab"));
      assert(res !is null);
      assert(res.rest == "b");
    }

    unittest {
      auto parser = new Repeat(match("+") ~ match("-"));
      Success res = cast(Success)(parser.parse("+-+-+"));
      assert(res !is null);
      assert(res.rest == "+");
    }
  }

  static class RegexpParser : Parser {
    string fRegexp;
    this(string regexp) {
      fRegexp = regexp;
    }

    Result parse(string s) {
      auto res = std.regexp.search(s, fRegexp);
      if (res is null) {
        return new Error("did not match " ~ fRegexp);
      } else if (res.pre.length > 0) {
        return new Error("did not match " ~ fRegexp);
      } else {
        return new Success(res.post, new String(res[0]));
      }
    }
    unittest {
      auto parser = new RegexpParser("abc");
      Success suc = cast(Success)(parser.parse("abcd"));
      assert(suc !is null);
      assert(suc.rest == "d");
    }
    unittest {
      auto parser = new RegexpParser("abc");
      Error err = cast(Error)(parser.parse("babc"));
      assert(err !is null);
    }
  }


  static class LazyParser : Parser {
    Callable!(Parser) fCallable;

    this(Parser delegate() parser) {
      assert(parser != null);
      fCallable = new Callable!(Parser)(parser);
    }

    this(Parser function() parser) {
      assert(parser != null);
      fCallable = new Callable!(Parser)(parser);
    }

    Result parse(string s) {
      auto parser = fCallable();
      return transform(parser.parse(s));
    }

    unittest {
      class Endless {
        // endless -> a | a opt(endless)
        Parser lazyEndless() {
          return new LazyParser( &endless );
        }
        Parser endless() {
          return new Or(new And(match("a"), new Opt(lazyEndless()), match("a")));
        }
      }
      auto parser = new Endless;
      auto p = parser.endless();
      Success suc = cast(Success)(p.parse("aa"));
      assert(suc !is null);
      suc = cast(Success)(p.parse("aab"));
      assert(suc !is null);
      assert(suc.rest == "b");
    }

// expr -> term { + term }
// term -> factor { * factor }
// factor -> number | ( expr )
    /*
        static class ExprParser {
          Parser lazyExpr() {
            return new LazyParser( &expr; );
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

    */

  }

  static Parser match(string s) {
    return new Matcher(s);
  }

  unittest {
    auto parser = match("test");
    Success suc = cast(Success)(parser.parseAll("test"));
    assert(suc !is null);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "|") {
    return new Or(this, rhs);
  }

  unittest {
    Parser parser = match("a") | match("b");
    Result res = parser.parse("a");
    assert(res !is null);

    Success suc = cast(Success)(res);
    assert(suc !is null);

    res = parser.parse("b");
    assert(res !is null);

    suc = cast(Success)(res);
    assert(suc !is null);

    res = parser.parse("c");
    assert(res !is null);
    Error err = cast(Error)(res);
    assert(err !is null);
  }

  Parser opBinary(string op)(Parser rhs) if (op == "~") {
    return new And(this, rhs);
  }

  unittest {
    auto parser = match("a") ~ match("b");
    auto suc = cast(Success)(parser.parse("ab"));
    assert(suc !is null);

    auto err = cast(Error)(parser.parse("ac"));
    assert(err !is null);
  }

}
