import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class SortLongs {

  static final long NPS = (1000L * 1000 * 1000);

  private static long[] res;

  private static void compute(long[] input) {
    res = new long[input.length];
    IntStream.range(0, input.length).parallel().forEach(i -> res[i] = input[i]);
    java.util.Arrays.parallelSort(res);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    int n = CommandLineArgs.parseInt("n", 10 * 1000 * 1000);

    long t0 = System.nanoTime();
    long input[] = new long[n];
    long t1 = System.nanoTime();
    double allocTime = (double) (t1 - t0) / NPS;
    System.out.println("allocate   " + Double.toString(allocTime) + "s");

    t0 = System.nanoTime();
    IntStream.range(0, n).parallel().forEach(i -> {
      input[i] = Util.mod(Util.hash(i), n);
    });
    t1 = System.nanoTime();
    double initTime = (double) (t1 - t0) / NPS;
    System.out.println("initialize " + Double.toString(initTime) + "s");

    Benchmark.run((Void v) -> { compute(input); return null; });

    for (int i = 0; i < Integer.min(n, 10); i++) {
      System.out.print(Long.toString(res[i]) + " ");
    }
    System.out.println("");

  }

}
