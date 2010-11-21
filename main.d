class String {
  string fString;
  this(string s) {
    fString = s;
  }

}
int main(string[] args) {

    Object[] data;
    data ~= new String("test");
    return 0;

}