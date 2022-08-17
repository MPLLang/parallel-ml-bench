import java.util.*;
import java.util.function.*;
import java.lang.management.*;

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
    double gct0 = totalGCTime();
    long gcn0 = numGCs();

    for (int i = 0; i < repeat; i++) {
      long t0 = System.nanoTime();
      func.apply(null);
      long t1 = System.nanoTime();

      double tm = (double) (t1 - t0) / NPS;
      System.out.println("time " + Double.toString(tm) + "s");

      tms[i] = tm;
    }

    double gct1 = totalGCTime();
    long gcn1 = numGCs();

    long gcn = gcn1 - gcn0;
    double gct = gct1 - gct0;
    double avg_gct = gct / (double)repeat;
    double avg_gcn = (double)gcn / (double)repeat;

    // some stats
    double avg =
      Arrays.stream(tms).reduce((a,b) -> a+b).getAsDouble() / (double)repeat;
    System.out.println("average " + Double.toString(avg) + "s");
    System.out.println("average-gcs-per-run " + Double.toString(avg_gcn));
    System.out.println("average-gc-time-per-run " + Double.toString(avg_gct) + "s");
    System.out.println("tot-gc-time " + Double.toString(gct1-gct0) + "s");
    System.out.println("num-gcs " + Long.toString(gcn1-gcn0));
  }

  public static long numGCs() {
    long count = 0;

    for(GarbageCollectorMXBean gc :
          ManagementFactory.getGarbageCollectorMXBeans())
    {
      long c = gc.getCollectionCount();
      if (c >= 0) {
        count += c;
      }
    }

    return count;
  }

  public static double totalGCTime() {
    long ms = 0;

    for(GarbageCollectorMXBean gc :
          ManagementFactory.getGarbageCollectorMXBeans())
    {
      long t = gc.getCollectionTime();
      if (t >= 0) {
        ms += t;
      }
    }

    return (double)ms / (double)1000.0;
  }

}
