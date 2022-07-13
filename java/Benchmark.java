import java.util.*;
import java.util.function.*;

class Benchmark {

  static final long NPS = (1000L * 1000 * 1000);

  public static void run(Function<Void, Void> func) {
    double warmup = CommandLineArgs.parseDouble("warmup", 0.0);
    int repeat = Integer.max(1, CommandLineArgs.parseInt("repeat", 1));

    if (warmup > 0.001) {
      System.out.println("============ WARMUP ============");
      long tStart = System.nanoTime();
      while ( ((double)(System.nanoTime() - tStart) / NPS) < warmup ) {
        long t0 = System.nanoTime();
        func.apply(null);
        long t1 = System.nanoTime();

        double tm = (double) (t1 - t0) / NPS;
        System.out.println("warmup_run " + Double.toString(tm) + "s");
      }
      System.out.println("========== END WARMUP ==========");
    }

    double tms[] = new double[repeat];

    for (int i = 0; i < repeat; i++) {
      long t0 = System.nanoTime();
      func.apply(null);
      long t1 = System.nanoTime();

      double tm = (double) (t1 - t0) / NPS;
      System.out.println("time " + Double.toString(tm) + "s");

      tms[i] = tm;
    }

    // some stats
    double avg =
      Arrays.stream(tms).reduce((a,b) -> a+b).getAsDouble() / (double)repeat;
    System.out.println("average " + Double.toString(avg) + "s");
  }

}
