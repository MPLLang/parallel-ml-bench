import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class TokensCheat {

  static final int blockSize = 5000;

  static boolean check(String input, int i) {
    int n = input.length();
    if (i == n) {
      return !(Character.isSpace(input.charAt(n-1)));
    }
    else if (i == 0) {
      return !(Character.isSpace(input.charAt(0)));
    }
    boolean i1 = Character.isSpace(input.charAt(i));
    boolean i2 = Character.isSpace(input.charAt(i-1));
    return (i1 && !i2) || (i2 && !i1);
  }

  static String[] tokensCheat(String input, String[] cheat, int[] tmpIds, String[] tmpResult) {

    long tm = System.nanoTime();

    // =======================================================================

    int lo = 0;
    int hi = input.length() + 1;
    int n = hi-lo;
    int numBlocks = 1 + (n-1) / blockSize;

    int[] tmp = new int[numBlocks];
    tm = Util.tickSince(tm, "tokens:filter:alloc-tmp");
    IntStream.range(0, numBlocks).parallel().forEach(b -> {
      int start = lo + b*blockSize;
      int stop = Integer.min(start+blockSize, hi);
      int count = 0;
      for (int i = start; i < stop; i++) {
        if (check(input, i)) count++;
      }
      tmp[b] = count;
    });
    tm = Util.tickSince(tm, "tokens:filter:count-blocks");

    int total = 0;
    for (int b = 0; b < numBlocks; b++) {
      int count = tmp[b];
      tmp[b] = total;
      total += count;
    }
    tm = Util.tickSince(tm, "tokens:filter:scan");

    // int[] ids = new int[total];
    int[] ids = tmpIds;
    tm = Util.tickSince(tm, "tokens:filter:alloc-output");
    IntStream.range(0, numBlocks).parallel().forEach(b -> {
      int start = lo + b*blockSize;
      int stop = Integer.min(start+blockSize, hi);
      int offset = tmp[b];
      for (int i = start; i < stop; i++) {
        if (check(input, i)) {
          ids[offset] = i;
          offset++;
        }
      }
    });
    tm = Util.tickSince(tm, "tokens:filter:fill-output");

    // =======================================================================

    int numTokens = ids.length / 2;
    // String[] result = new String[numTokens];
    String[] result = tmpResult;
    tm = Util.tickSince(tm, "tokens:alloc-output");
    IntStream.range(0, numTokens).parallel().forEach(i -> {
      int start = ids[2*i];
      int stop = ids[2*i+1];
      String answer = cheat[i];
      for (int j = 0; j < stop-start; j++) {
        if (answer.charAt(j) != input.charAt(start+j)) {
          System.out.println("ERROR! Chars differ");
        }
      }
      result[i] = answer;
      // result[i] = input.substring(start, stop);

    });
    tm = Util.tickSince(tm, "tokens:fill-output");

    return result;
  }

  private static String[] result;

  private static void compute(String input, String[] cheat, int[] tmpIds, String[] tmpResult) {
    result = tokensCheat(input, cheat, tmpIds, tmpResult);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    String filename = CommandLineArgs.parseString("input", "");
    String contents = ReadFile.contents(filename);

    String[] cheat = Tokenize.tokens(contents);
    String[] tmpResult = new String[cheat.length];
    int[] tmpIds = new int[2 * cheat.length];

    Benchmark.run((Void v) -> { compute(contents, cheat, tmpIds, tmpResult); return null; });

    int n = result.length;
    System.out.println("number of tokens " + Integer.toString(n));
    for (int i = 0; i < Integer.min(n, 10); i++) {
      System.out.print(result[i] + " ");
    }
    System.out.println("...");

  }

}
