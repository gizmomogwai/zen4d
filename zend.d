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
      Result parse(string s) {
        return new Result();
      }
}

class Matcher : Parser {
      string fExpected;
      this(string expected) {
        fExpected = expected;
      }
      Result parse(string s) {
        if (s.indexOf(fExpected) == 0) {
	  return new Result(s[fExpected.length..$], new ContentNode(fExpected));
	} else {
          return new Result;
	}
      }
}
class Epsilon : Parser {
  this() {}
  Result parse(string s) {
    if (s.length == 0) {
      return new Result("", new ContentNode(""));
    } else {
      return new Result;
    }
  }
}
class AsciiParser : public Parser {
  Result parse(string s) {
    if (s.length == 0) {
      return new Result;
    }

    string res;
    for (int i=0; i<s.length; i++) {
    	if (isalnum(s[i])) {
	  res = res ~ s[i];
	} else {
	  return new Result(s[i..$], new ContentNode(res));
	}
    }
    return new Result("", new ContentNode(res));
  }
}
class Or : Parser {
      Parser[] fParsers;
      this(Parser[] parsers ...) {
        fParsers = parsers.dup;
        writefln("number of parsers: %d", fParsers.length);
      }

      Result parse(string s) {
        foreach (parser; fParsers) {
	  auto res = parser.parse(s);
	  if (res.fNodes !is null) {
	     return res;
	  }
	}
	return new Result;
      }
}

class LazyParser : Parser {
  Parser delegate() fDg;
  this(Parser delegate() parser) {
    fDg = parser;
  }
  Result parse(string s) {
    return fDg().parse(s);
  }
}

class And : Parser {
      Parser[] fParsers;
      this(Parser[] parsers ...) {
        fParsers = parsers.dup;
      }
      Result parse(string s) {
	Node[] nodes;
        string h = s;
        foreach (parser; fParsers) {
	  auto res = parser.parse(h);
          if (res.fNodes !is null) {
	    nodes = nodes ~ res.fNodes;
	    h = res.fInput;
	  } else {
            return new Result;
	  }
	}
        return new Result(h, nodes);
      }
}
/*
class Node {
      Node parent;
      Node[] childs;
      this(Node parent_=null, string name_="root") {
      	     name = name_;
	     parent = parent_;
	     if (parent !is null) {
	     	parent.addChild(this);
	     }
      }
      void addChild(Node child) {
      	   childs = childs ~ child;
      }
      string name;
      void printSpaces(int ident) {
      	   for (auto i=0; i<ident; ++i) {
	       writef(" ");
	   }
      }
      void print(int ident=0) {
        printSpaces(ident);
        writefln("<%s>", name);
	foreach (c; childs) {
		c.print(ident+2);
	}
	printSpaces(ident);
	writefln("</%s>", name);
      }
      Node root() {
        if (parent is null) {
	  return this;
	} else {
	  return parent.root();
	}
      }
}
class Parser {
      Node tree;
      string currentString;
      this() {
        tree = new Node;
        currentString = "";
      }
      void consume(char c) {
        if (isalnum(c)) {
	  currentString = currentString ~ c;
	} else if (c == '>') {
          if (currentString.length > 0) {
	    tree = new Node(tree, currentString);
            currentString = "";
          }
	} else {
 	  throw new Exception("unknown character: " ~c);
	}
      }
      Node finish() {
        if (currentString.length > 0) {
          tree = new Node(tree, currentString);
        }
        return tree.root();
      }
}
*/


class MyParser {
/*
      static Parser getit() {
      }
*/
/*
      expr
      expr -> (expr+expr) | (expr>expr)
  */
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

/*
 endless
 endless -> e | endless "+" "a"
*/

   static Parser endless() {
     return or(epsilon(), and(match("a"), new LazyParser(delegate Parser() {return endless();})));
   }
/*

  nodes
  nodes -> node "+" nodes
  node -> e | node ">" nodes

*/

/*
      static Parser nodes() {
        return and(node(), match("+"), nodes());
      }
*/
      static Parser my() {
          return and(new AsciiParser(), new Matcher(">"), new AsciiParser());
//      	  return new LazyParserdelegate Parser() { return new Matcher("a"); });
      }

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
//     Parser parser = MyParser.expr();//new AsciiParser;
     Parser parser;
     parser = MyParser.endless();
//     parser = MyParser.and(MyParser.match("a"), MyParser.match("b"));
     auto result = parser.parse(input);
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