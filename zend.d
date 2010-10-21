import std.stdio;
import std.array;
import std.ctype;

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

int main(string[] args) {

     auto input = args[1];
     auto parser = new Parser;
     foreach (c; input) {
       parser.consume(c);
     }
     auto tree = parser.finish();
     tree.print();
     return 0;
}