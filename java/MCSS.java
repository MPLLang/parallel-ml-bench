import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;
import java.util.Arrays;

class MCSS {

  static class M {
    public final double l;
    public final double r;
    public final double b;
    public final double t;
    public M(double l, double r, double b, double t) {
      this.l = l;
      this.r = r;
      this.b = b;
      this.t = t;
    }
  }

  static final long NPS = (1000L * 1000 * 1000);

  private static double res;

  private static void compute(double[] input) {
    res = mcss(input);
  }

  private static double mcss(double[] input) {
    M z = new M(0.0,0.0,0.0,0.0);
    M result =
      Arrays.stream(input)
      .parallel()
      .mapToObj(v -> { double vp = Double.max(0.0, v); return new M(vp,vp,vp,v); })
      .reduce(z, (x, y) -> {
        return new M(Double.max(x.l, x.t + y.l),
            Double.max(y.r, x.r + y.t),
            Double.max(x.r + y.l, Double.max(x.b, y.b)),
            x.t + y.t);
      });

    return result.b;
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    int n = CommandLineArgs.parseInt("n", 100 * 1000 * 1000);

    long t0 = System.nanoTime();
    double input[] = new double[n];
    long t1 = System.nanoTime();
    double allocTime = (double) (t1 - t0) / NPS;
    System.out.println("allocate   " + Double.toString(allocTime) + "s");

    t0 = System.nanoTime();
    IntStream.range(0, n).parallel().forEach(i -> {
      input[i] = (double)(Util.mod(Util.hash(i), 1000) - 500) / (double)500.0;
    });
    t1 = System.nanoTime();
    double initTime = (double) (t1 - t0) / NPS;
    System.out.println("initialize " + Double.toString(initTime) + "s");

    Benchmark.run((Void v) -> { compute(input); return null; });

    System.out.println("result " + Double.toString(res));

  }

}
