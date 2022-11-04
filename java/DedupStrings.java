import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.*;

class DedupStrings {

  static final long NPS = (1000L * 1000 * 1000);

  // static class HString implements Comparable<String> {
  //   final String data;

  //   HString(String x) {
  //     this.data = x;
  //   }

  //   @Override
  //   public boolean equals(Object other) {
  //     return data.equals(other);
  //   }

  //   @Override
  //   public int hashCode() {
  //     return data.hashCode();
  //     // long hash = 7;
  //     // int len = Integer.min(data.length(), 32);
  //     // for (int i = 0; i < len; i++) {
  //     //   hash = hash*31 + (long)data.charAt(i);
  //     // }
  //     // return (int)(Util.hash(hash) & (long)0xFFFFFFFF);
  //   }

  //   @Override
  //   public int compareTo(String other) {
  //     return data.compareTo(other);
  //   }
  // }

  static ConcurrentHashMap<String, Boolean> result;

  public static void compute(String[] input) {

    ConcurrentHashMap<String, Boolean> x =
      new ConcurrentHashMap<String, Boolean>(input.length / 100);

    // IntStream.range(0, input.length).parallel().forEach(i -> {
    //   x.put(new HashObject(input[i]), true);
    // });

    IntStream.range(0, input.length).parallel().forEach(i -> {
      x.putIfAbsent(input[i], true);
    });

    result = x;
    // result = x.keySet().stream().parallel().toArray(HashObject[]::new);
  }

  public static void main (String args[]) throws Exception {
    CommandLineArgs.initialize(args);
    String filename = CommandLineArgs.parseString("input", "");
    String contents = ReadFile.contents(filename);
    String[] tokens = Tokenize.tokens(contents);

    // HString[] input = new HString[tokens.length];
    // IntStream.range(0, tokens.length).parallel().forEach(i -> {
    //   input[i] = new HString(tokens[i]);
    // });

    String[] input = tokens;

    System.out.println("number of tokens " + Integer.toString(input.length));

    Benchmark.run((Void v) -> { compute(input); return null; });

    long n = result.size();
    System.out.println("unique " + Long.toString(n));
  }
}
