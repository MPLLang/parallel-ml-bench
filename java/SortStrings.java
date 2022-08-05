import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class SortStrings {

  static final long NPS = (1000L * 1000 * 1000);

  private static String[] res;

  private static void compute(String[] input) {
    res = new String[input.length];
    IntStream.range(0, input.length).parallel().forEach(i -> res[i] = input[i]);
    java.util.Arrays.parallelSort(res);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);
    String filename = CommandLineArgs.parseString("input", "");
    String contents = ReadFile.contents(filename);
    String[] input = Tokenize.tokens(contents);

    Benchmark.run((Void v) -> { compute(input); return null; });

    System.out.print("input ");
    for (int i = 0; i < Integer.min(input.length, 10); i++) {
      System.out.print(input[i] + " ");
    }
    System.out.println("...");

    System.out.print("result ");
    for (int i = 0; i < Integer.min(res.length, 10); i++) {
      System.out.print(res[i] + " ");
    }
    System.out.println("...");

  }

}
