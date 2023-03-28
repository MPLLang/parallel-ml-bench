import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class Tokens {

  static final long NPS = (1000L * 1000 * 1000);

  private static Tokenize.StringSlice[] result;

  private static void compute(String input) {
    result = Tokenize.tokens(input);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    String filename = CommandLineArgs.parseString("input", "");
    String contents = ReadFile.contents(filename);

    Benchmark.run((Void v) -> { compute(contents); return null; });

    int n = result.length;
    System.out.println("number of tokens " + Integer.toString(n));
    for (int i = 0; i < Integer.min(n, 10); i++) {
      Tokenize.StringSlice x = result[i];
      System.out.print(x.data.substring(x.start, x.start+x.length) + " ");
    }
    System.out.println("...");

  }

}
