class Pair<X, Y> {
  public final X fst;
  public final Y snd;
  public Pair(X x, Y y) {
    this.fst = x;
    this.snd = y;
  }

  public first() {
    return this.fst;
  }

  public second() {
    return this.snd;
  }
}
