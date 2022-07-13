import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class Primes {

  static final long NPS = (1000L * 1000 * 1000);

  private static long[] res;

  private static void compute(long n) {
    res = primesUpto(n);
  }

  private static long[] primesUpto(long n) {
    if (n < 2) return new long[0];

    long[] sqrtPrimes = primesUpto((long) Math.floor(Math.sqrt((double)n)));
    boolean[] flags = new boolean[(int)(n+1)]; // initializes to false??

    // LongStream.range(0, n+1).parallel().forEach(i -> flags[i] = input[i])

    LongStream.range(0, sqrtPrimes.length).parallel().forEach(i -> {
      long p = sqrtPrimes[(int)i];
      long numMultiples = n / p - 1;
      LongStream.range(0, numMultiples).parallel().forEach(j -> {
        flags[(int)((j+2)*p)] = true;
      });
    });

    long[] result =
      LongStream
      .range(2,n+1)
      .parallel()
      .filter(i -> !(flags[(int)i]))
      .toArray();

    return result;
  }


  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    long n = CommandLineArgs.parseLong("n", 100 * 1000 * 1000);

    Benchmark.run((Void v) -> { compute(n); return null; });

    System.out.println("number of primes " + Integer.toString(res.length));
    for (long i = 0; i < Long.min(n, 10); i++) {
      System.out.print(Long.toString(res[(int)i]) + " ");
    }
    System.out.println("...");

  }

}
