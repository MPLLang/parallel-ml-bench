import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.*;
import java.util.Arrays;

class LinefitAccum {

  static class P {
    public final double x;
    public final double y;
    public P(double x, double y) {
      this.x = x;
      this.y = y;
    }
  }

  static final long NPS = (1000L * 1000 * 1000);

  private static P res;

  private static void compute(P[] input) {
    res = linefit(input);
  }

  private static P linefit(P[] input) {
    P z = new P(0.0,0.0);

    AtomicReference<P> acc = new AtomicReference<P>(z);

    int numElems = input.length;
    int grain = 100000;
    int numBlocks = 1 + (numElems-1) / grain;

    IntStream.range(0, numBlocks).parallel().forEach(bi -> {
      int start = bi*grain;
      int stop = Integer.min(start+grain, numElems);
      double xx = 0.0;
      double yy = 0.0;
      for (int i = start; i < stop; i++) {
        xx += input[i].x;
        yy += input[i].y;
      }

      P tot = new P(xx, yy);
      acc.getAndAccumulate(tot, (P a, P b) -> { 
        return new P(a.x+b.x, a.y+b.y);
      });
    });

  	P r = acc.get();
    acc.set(z);

    double xsum = r.x;
    double ysum = r.y;
    double n = (double)input.length;
    double xa = xsum / n;
    double ya = ysum / n;

    // ======================================================================

    IntStream.range(0, numBlocks).parallel().forEach(bi -> {
      int start = bi*grain;
      int stop = Integer.min(start+grain, numElems);
      double xx = 0.0;
      double yy = 0.0;
      for (int i = start; i < stop; i++) {
        P p = input[i];
        xx += (p.x - xa) * (p.x - xa);
        yy += (p.x - xa) * p.y;
      }
      P tot = new P(xx, yy);
      acc.getAndAccumulate(tot, (P a, P b) -> { 
        return new P(a.x+b.x, a.y+b.y);
      });
    });

    r = acc.get();

    // r =
    //   Arrays.stream(input)
    //   .parallel()
    //   .map(p -> { return new P((p.x - xa)*(p.x - xa), (p.x - xa) * p.y); })
    //   .reduce(z, (P a, P b) -> { return new P(a.x+b.x, a.y+b.y); });

    double Stt = r.x;
    double bb = r.y;

  	double b = bb / Stt;
  	double a = ya - xa * b;

  	return new P(a, b);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    int n = CommandLineArgs.parseInt("n", 100 * 1000 * 1000);

    long t0 = System.nanoTime();
    P input[] = new P[n];
    long t1 = System.nanoTime();
    double allocTime = (double) (t1 - t0) / NPS;
    System.out.println("allocate   " + Double.toString(allocTime) + "s");

    t0 = System.nanoTime();
    IntStream.range(0, n).parallel().forEach(i -> {
      input[i] = new P((double)i, (double)i);
    });
    t1 = System.nanoTime();
    double initTime = (double) (t1 - t0) / NPS;
    System.out.println("initialize " + Double.toString(initTime) + "s");

    Benchmark.run((Void v) -> { compute(input); return null; });

    System.out.println("a " + Double.toString(res.x));
    System.out.println("b " + Double.toString(res.y));

  }

}
