import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;
import java.util.function.*;

class Filter {

  static int[] filterInts(int lo, int hi, Function<Integer,Boolean> pred) {
    int n = hi-lo;
    int blockSize = 1000;
    int numBlocks = 1 + (n-1) / blockSize;

    int[] tmp = new int[numBlocks];
    IntStream.range(0, numBlocks).parallel().forEach(b -> {
      int start = lo + b*blockSize;
      int stop = Integer.min(start+blockSize, hi);
      int count = 0;
      for (int i = start; i < stop; i++) {
        if (pred.apply(i)) count++;
      }
      tmp[b] = count;
    });

    int total = 0;
    for (int b = 0; b < numBlocks; b++) {
      int count = tmp[b];
      tmp[b] = total;
      total += count;
    }

    int[] result = new int[total];
    IntStream.range(0, numBlocks).parallel().forEach(b -> {
      int start = lo + b*blockSize;
      int stop = Integer.min(start+blockSize, hi);
      int offset = tmp[b];
      for (int i = start; i < stop; i++) {
        if (pred.apply(i)) {
          result[offset] = i;
          offset++;
        }
      }
    });

    return result;
  }

}
