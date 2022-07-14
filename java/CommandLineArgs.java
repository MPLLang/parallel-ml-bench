import java.lang.*;

class CommandLineArgs {

  private static CommandLineArgs CommandLineArgsInstance = null;
  private static String args[] = null;

  public static void initialize(String[] args_) {
    args = args_;

    // System.out.print("args are: ");
    // for (int i = 0; i < args.length; i++) {
    //   System.out.print(args[i]);
    //   System.out.print(" ");
    // }
    // System.out.print("\n");
  }

  private static int find(String dashkey) {
    // System.out.println("find(" + dashkey + ")");

    if (args == null)
      return -1;

    for (int i = 0; i < args.length; i++) {
      if (args[i].equals(dashkey)) {
        return i;
      }
    }

    // System.out.println("didn't find it :(");
    return -1;
  }

  public static int parseInt(String key, int def) {
    int i = find("-" + key);
    if (i < 0)
      return def;

    if (i+1 >= args.length) {
      System.err.println("missing integer value for key -" + key);
      System.exit(1);
    }

    return Integer.parseInt(args[i+1]);
  }

  public static long parseLong(String key, long def) {
    int i = find("-" + key);
    if (i < 0)
      return def;

    if (i+1 >= args.length) {
      System.err.println("missing long value for key -" + key);
      System.exit(1);
    }

    return Long.parseLong(args[i+1]);
  }

  public static double parseDouble(String key, double def) {
    int i = find("-" + key);
    if (i < 0)
      return def;

    if (i+1 >= args.length) {
      System.err.println("missing double value for key -" + key);
      System.exit(1);
    }

    return Double.parseDouble(args[i+1]);
  }

  public static String parseString(String key, String def) {
    int i = find("-" + key);
    if (i < 0)
      return def;

    if (i+1 >= args.length) {
      System.err.println("missing double value for key -" + key);
      System.exit(1);
    }

    return args[i+1];
  }

  public static boolean parseFlag(String key) {
    int i = find("--" + key);
    return (i > 0);
  }

}
