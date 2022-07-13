class Util {
  static long hash(long i) {
    long v = (long)i * 3935559000370003845L + 2691343689449507681L;
    v = v ^ (v >>> 21);
    v = v ^ (v << 37);
    v = v ^ (v >>> 4);
    v = v * 4768777513237032717L;
    v = v ^ (v << 20);
    v = v ^ (v >>> 41);
    v = v ^ (v <<  5);
    return v;
  }
}
