module util.callable;

/**
 * simple class to handle functions and delegates in the same way.
 */
class Callable(R, P ...) {

  /// the delegate to call
  R delegate(P) fDelegate;

  /// the function to call
  R function(P) fFunction;

  /**
   * constructs with delegate
   */
  this(R delegate(P) del) {
    assert(del !is null);
    fDelegate = del;
  }

  /**
   * constructs with function
   */
  this(R function(P) fun) {
    assert(fun !is null);
    fFunction = fun;
  }

  /**
   * the opcall operator to call the delegate or function.
   */
  R opCall(P p) {
    return fDelegate ? fDelegate(p) : fFunction(p);
  }
}

unittest {
  class Test {
    void d1(int a) {
    }
    int d2() {
      return 2;
    }
  }
  Test t = new Test;
  Callable!(int) w = new Callable!(int)(&t.d2);
  assert(w() == 2);
  Callable!(void, int) w2 = new Callable!(void, int)(&t.d1);
  w2(3);
}
