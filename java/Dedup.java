import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.*;

class Dedup {

  static final long NPS = (1000L * 1000 * 1000);

  static HashObject result[] = new HashObject[0];

  static class HashObject {
    long x;
    HashObject(long x) {
      this.x = x;
    }
    public int hashcode () {
      return (int)(Util.hash(x) & (long)0xFFFFFFFF);
    }
  }

  public static void compute(long[] input) {

    ConcurrentHashMap<HashObject, Boolean> x =
      new ConcurrentHashMap<HashObject, Boolean>(input.length);

    IntStream.range(0, input.length).parallel().forEach(i -> {
      x.put(new HashObject(input[i]), true);
    });

    result = x.keySet().stream().parallel().toArray(HashObject[]::new);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    int n = CommandLineArgs.parseInt("n", 10 * 1000 * 1000);
    // System.out.println(Long.toString(hash(n)));

    long t0 = System.nanoTime();
    long input[] = new long[n];
    long t1 = System.nanoTime();
    double allocTime = (double) (t1 - t0) / NPS;
    System.out.println("allocate   " + Double.toString(allocTime) + "s");

    t0 = System.nanoTime();
    IntStream.range(0, n).parallel().forEach(i -> input[i] = Util.hash(i));
    t1 = System.nanoTime();
    double initTime = (double) (t1 - t0) / NPS;
    System.out.println("initialize " + Double.toString(initTime) + "s");

    Benchmark.run((Void v) -> { compute(input); return null; });
/*
      int n = 1000000;
      int reps = 1;
      int sreps = 1;
      try {
          if (args.length > 0)
            n = Integer.parseInt(args[0]);
          if (args.length > 1)
            reps = Integer.parseInt(args[1]);
          if (args.length > 2)
            sreps = Integer.parseInt(args[2]);
      } catch (Exception e) {
          System.out.println("Usage: java Histogram size reps sreps");
          return;
      }

      char[][] l = new char[n][0];
      IntStream.range(0, n).parallel().forEach(i -> l[i] = StrGen.generate(i));
      Runner.run(
        (Void v) -> { compute(l); return null; },
           reps, sreps);
*/
  }
}
