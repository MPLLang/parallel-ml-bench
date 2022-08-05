import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;
import java.util.Arrays;

class SparseMxV {

  static class Ix {
    public final int i;
    public final double x;
    public Ix(int i, double x) {
      this.i = i;
      this.x = x;
    }
  }

  static final long NPS = (1000L * 1000 * 1000);

  private static double[] res;

  private static void compute(Ix[][] mat, double[] vec) {
    res = sparseMxV(mat, vec);
  }

  private static double[] sparseMxV(Ix[][] mat, double[] vec) {
    double z = 0.0;

    double[] result = new double[mat.length];

    IntStream.range(0, mat.length).parallel().forEach(i -> {
      Ix[] row = mat[i];
      double sum = 0.0;
      for (int j = 0; j < row.length; j++) {
        Ix elem = row[j];
        sum += vec[elem.i] * elem.x;
      }
      result[i] = sum;
    });

    return result;
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    int n = CommandLineArgs.parseInt("n", 100 * 1000 * 1000);

    int rowLen = 100;
    int numRows = n / rowLen;

    long t0 = System.nanoTime();
    Ix[][] mat = new Ix[numRows][rowLen];
    double[] vec = new double[numRows];
    long t1 = System.nanoTime();
    double allocTime = (double) (t1 - t0) / NPS;
    System.out.println("allocate   " + Double.toString(allocTime) + "s");

    t0 = System.nanoTime();
    IntStream.range(0, mat.length).parallel().forEach(i -> {
      Ix[] row = mat[i];
      for (int j = 0; j < row.length; j++) {
        row[j] = new Ix((int)Util.mod(Util.hash((long)(i*rowLen + j)), (long)numRows), 1.0);
      }
    });
    IntStream.range(0, vec.length).parallel().forEach(i -> { vec[i] = 1.0; });
    t1 = System.nanoTime();
    double initTime = (double) (t1 - t0) / NPS;
    System.out.println("initialize " + Double.toString(initTime) + "s");

    Benchmark.run((Void v) -> { compute(mat, vec); return null; });

    System.out.print("result ");
    for (int i = 0; i < Integer.min(10, res.length); i++) {
      System.out.print(Double.toString(res[i]));
      System.out.print(" ");
    }
    System.out.println("");
  }

}
