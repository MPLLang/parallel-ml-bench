import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.*;

class WCAccum {

  static final long NPS = (1000L * 1000 * 1000);

  static class LW {
    public final int lines;
    public final int words;
    public LW(int lines, int words) {
      this.lines = lines;
      this.words = words;
    }
  }

  private static LW result;

  private static boolean isWordStart(String input, int i) {
    return (i == 0 || Character.isSpace(input.charAt(i-1)))
        && !Character.isSpace(input.charAt(i));
  }

  private static LW wc(String input) {
    LW z = new LW(0,0);
    AtomicReference<LW> acc = new AtomicReference<LW>(z);

    int numElems = input.length();
    int grain = 100000;
    int numBlocks = 1 + (numElems-1) / grain;

    IntStream.range(0, numBlocks).parallel().forEach(bi -> {
      int start = bi*grain;
      int stop = Integer.min(start+grain, numElems);
      int words = 0;
      int lines = 0;
      for (int i = start; i < stop; i++) {
        if (isWordStart(input, i)) words++;
        if (input.charAt(i) == '\n') lines++;
      }
      LW tot = new LW(lines, words);
      acc.getAndAccumulate(tot, (LW a, LW b) -> { 
        return new LW(a.lines+b.lines, a.words+b.words);
      });
    });

    return acc.get();
  }

  private static void compute(String input) {
    result = wc(input);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);

    String filename = CommandLineArgs.parseString("input", "");
    String contents = ReadFile.contents(filename);

    Benchmark.run((Void v) -> { compute(contents); return null; });

    int lines = result.lines;
    int words = result.words;
    int bytes = contents.length();
    System.out.println("lines " + Integer.toString(lines));
    System.out.println("words " + Integer.toString(words));
    System.out.println("bytes " + Integer.toString(bytes));

  }

}
