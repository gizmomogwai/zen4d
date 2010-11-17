module pc.parser;

import std.stdio;
import std.array;
import std.ctype;
import std.string;
import std.conv;
import util.callable;
import std.regex;
import std.variant;

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

class Parser {
  Callable!(Variant[], Variant[]) fCallable = null;

  static class Result {
  }

  static success(T...)(string rest, T args) {
    return new Success(rest, variantArray(args));
  }

  static class Success : Result {
    string fRest;
    Variant[] fResults;
    this(string rest, Variant[] result) {
      fRest = rest;
      fResults = result;
    }
    @property string rest() {
      return fRest;
    }

    @property string rest(string rest) {
      return fRest = rest;
    }
    @property Variant[] results() {
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

  Parser opBinary(string op)(Variant[] delegate(Variant[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser opBinary(string op)(Variant[] function(Variant[] objects) toCall) if (op == "^^") {
    return setCallback(toCall);
  }

  Parser setCallback(Variant[] function(Variant[] objects) tocall) {
    fCallable = new Callable!(Variant[], Variant[])(tocall);
    return this;
  }
  Parser setCallback(Variant[] delegate(Variant[] objects) tocall) {
    fCallable = new Callable!(Variant[], Variant[])(tocall);
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
        return transform(success(rest, fExpected));
      } else {
        return new Error("Expected: '" ~ fExpected ~ "' but got '" ~ s ~ "'");
      }
    }

    unittest {
      auto parser = new Matcher("test");
      auto res = cast(Success)(parser.parse("test"));
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
      auto suc = cast(Success)(parser.parse("test2"));
      assert(suc !is null);
      assert(suc.rest == "2");
      auto err = cast(Error)(parser.parseAll("test2"));
      assert(err !is null);
    }

    unittest {
      auto parser = match("test") ^^ (Variant[] objects) {
        auto res = objects;
        if (objects[0] == "test") {
          res[0] = "super";
        }
        return objects;
      };
      auto suc = cast(Success)(parser.parse("test"));
      assert(suc.results[0] == "super");
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
      auto res = cast(Success)(parser.parse("ab"));
      assert(res !is null);
    }

    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      auto res = cast(Success)(parser.parse("cde"));
      assert(res !is null);
      assert(res.rest == "e");
    }
    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd"));
      Error res = cast(Error)(parser.parse("ef"));
      assert(res !is null);
    }
    unittest {
      auto parser = new Or(new Matcher("ab"), new Matcher("cd")) ^^ (Variant[] input) {
        if (input[0] == "ab") {
          input[0] = "super";
        }
        return input;
      };
      auto suc = cast(Success)(parser.parse("ab"));
      assert(suc.results[0] == "super");
      suc = cast(Success)(parser.parse("cd"));
      assert(suc.results[0] == "cd");
    }
  }

  static class And : Parser {
    Parser[] fParsers;
    this(Parser[] parsers ...) {
      fParsers = parsers.dup;
    }

    Result parse(string s) {
      auto resultObjects = appender!(Variant[])();
      string h = s;
      foreach (parser; fParsers) {
        Result res = parser.parse(h);
        auto suc = cast(Success)(res);
        auto err = cast(Error)(res);
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
      auto parser = new And(match("a"), match("b")) ^^ (Variant[] result) {
        string totalString;
        foreach (Variant o ; result) {
          if (o.type == typeid(string)) {
            totalString ~= o.get!(string);
          }
        }

        Variant[] res;
        Variant v = totalString;
        res ~= v;
        return res;
      };

      auto suc = cast(Success)(parser.parse("ab"));
      assert(suc.results.length == 1);
      assert(suc.results[0] == "ab");
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
        return success(s);
      } else {
        return res;
      }
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Opt(abc);
      auto res = cast(Success)(opt.parse("abc"));
      assert(res !is null);
      assert(res.results.length == 1);
      assert(res.results[0] == "abc");
      assert(res.rest.length == 0);
    }
    unittest {
      auto abc = new Matcher("abc");
      auto opt = new Opt(abc);
      auto res = cast(Success)(opt.parse("efg"));
      assert(res !is null);
      assert(res.results.length == 0);
      assert(res.rest == "efg");
    }
    unittest {
      auto abc = new Matcher("+");
      auto def = new Integer;
      auto test = new Opt(new And(abc, def));
      auto res = cast(Success)(test.parse("+1"));
      assert(res !is null);
      assert(res.results.length == 2);
    }
  }


  static class Repeat : Parser {
    Parser fToRepeat;
    this(Parser toRepeat) {
      fToRepeat = toRepeat;
    }

    Result parse(string s) {
      auto results = appender!(Variant[])();
      auto rest = s;
      while (true) {
        auto res = fToRepeat.parse(rest);
        auto suc = cast(Success)(res);
        if (suc !is null) {
          rest = suc.rest;
          results.put(suc.results);
        } else {
          break;
        }
      }
      return success(rest, results.data);
    }

    unittest {
      auto parser = new Repeat(new Matcher("a"));
      auto res = cast(Success)(parser.parse("aa"));
      assert(res !is null);
      assert(res.rest == "");
    }
    unittest {
      auto parser = new Repeat(new Matcher("a"));
      auto res = cast(Success)(parser.parse("b"));
      assert(res !is null);
      assert(res.rest == "b");
    }
    unittest {
      auto parser = new Repeat(new Matcher("a"));
      auto res = cast(Success)(parser.parse("ab"));
      assert(res !is null);
      assert(res.rest == "b");
    }

    unittest {
      auto parser = new Repeat(new And(match("+"), match("-")));
      auto res = cast(Success)(parser.parse("+-+-+"));
      assert(res !is null);
      assert(res.rest == "+");
    }
  }

  unittest {
    auto text = "abc";
    auto m1 = std.regex.match(text, "d");
    assert(m1.empty());
    m1 = std.regex.match(text, "a");
    assert(!m1.empty());
  }

  static class RegexParser : Parser {
    string fRegex;
    this(string regex) {
      fRegex = regex;
    }

    Result parse(string s) {
      auto res = std.regex.match(s, regex(fRegex));
      if (res.empty()) {
        return new Error("did not match " ~ fRegex);
      } else if (res.pre.length > 0) {
        return new Error("did not match " ~ fRegex);
      } else {
        Variant[] results;
	foreach (c; res.captures) {
	  Variant v = c;
          results ~= v;
        }
        return transform(new Success(res.post, results));
      }
    }
    unittest {
      auto parser = new RegexParser("abc");
      Success suc = cast(Success)(parser.parse("abcd"));
      assert(suc !is null);
      assert(suc.rest == "d");
    }
    unittest {
      auto parser = new RegexParser("abc");
      Error err = cast(Error)(parser.parse("babc"));
      assert(err !is null);
    }
    unittest {
      auto parser = new RegexParser("(.)(.)(.)");
      auto res = cast(Success)(parser.parse("abc"));
      assert(res.results.length == 4);
    }
  }
  static class Number : RegexParser {
    this() {
      super(r"[-+]?[0-9]*\.?[0-9]+") ^^ (Variant[] input) {
        Variant[] output;
        foreach (Variant o ; input) {
          string s = o.get!(string);
          Variant v = std.conv.parse!(double, string)(s);
          output ~= v;
        }
        return output;
      };
    }
    unittest {
      Parser parser = new Number;
      assert(parser !is null);
      Success suc = cast(Success)(parser.parse("123.123"));
      assert(suc !is null);
    }
  }
  static class Integer : RegexParser {
    this() {
      super(r"\d+") ^^ (Variant[] input) {
	string s = input[0].get!(string);
	Variant v = std.conv.parse!(int, string)(s);
	return variantArray(v);
      };
    }
  }

  static class AlnumParser : RegexParser {
    this() {
      super(r"\w[\w\d]*") ^^ (Variant[] input) {
        return variantArray(input[0]);
      };
    }
  }
  unittest {
    auto parser = new AlnumParser;
    Success suc = cast(Success)(parser.parse("a1234"));
    assert(suc !is null);
    assert(suc.results[0] == "a1234");
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
  }

// expr -> term { + term }
// term -> factor { * factor }
// factor -> number | ( expr )
  static class ExprParser {
    Parser lazyExpr() {
      return new LazyParser( {return expr();} );
    }
    Parser expr() {
      auto add = (term() ~ match("+") ~ term()) ^^ (Variant[] input) {
	return variantArray(input[0]+input[2]);
      };
      return add | term();
    }
    Parser term() {
      auto mult = (factor() ~ match("*") ~ factor()) ^^ (Variant[] input) {
	return variantArray(input[0]*input[2]);
      };
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
    auto res = cast(Success)(p.parse("1+2*3"));
    assert(res !is null);
    assert(res.results[0] == 7);
  }

  unittest {
    auto parser = new ExprParser;
    auto p = parser.expr();
    auto res = cast(Success)(p.parse("1*2+3"));
    assert(res !is null);
    assert(res.results[0] == 5);
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
