import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

class Tokenize {

  static String[] tokens(String input) {
    int n = input.length();
    int[] ids = IntStream.range(0,n+1).parallel().filter(i -> {
      if (i == n) {
        return !(Character.isSpace(input.charAt(n-1)));
      }
      else if (i == 0) {
        return !(Character.isSpace(input.charAt(0)));
      }
      boolean i1 = Character.isSpace(input.charAt(i));
      boolean i2 = Character.isSpace(input.charAt(i-1));
      return (i1 && !i2) || (i2 && !i1);
    }).toArray();

    int numTokens = ids.length / 2;
    String[] result = new String[numTokens];
    IntStream.range(0, numTokens).parallel().forEach(i -> {
      int start = ids[2*i];
      int stop = ids[2*i+1];
      result[i] = input.substring(start, stop);
    });

    return result;
  }

}
