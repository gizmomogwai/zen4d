module util.callable;

class Callable(R, P ...) {
  R delegate(P) fDelegate;
  R function(P) fFunction;
  this(R delegate(P) del) {
    assert(del !is null);
    fDelegate = del;
  }
  this(R function(P) fun) {
    assert(fun !is null);
    fFunction = fun;
  }
  R call(P p) {
    if (fDelegate !is null) {
      return fDelegate(p);
    } else {
      return fFunction(p);
    }
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
  assert(w.call() == 2);
  Callable!(void, int) w2 = new Callable!(void, int)(&t.d1);
  w2.call(3);
}
