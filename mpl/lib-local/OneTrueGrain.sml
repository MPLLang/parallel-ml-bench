structure OneTrueGrain:
sig
  val asInt: int
  val asWord: word
  val asWord64: Word64.word
end =
struct

  val asInt = CommandLineArgs.parseInt "one-true-grain" 32
  val asWord = Word.fromInt asInt
  val asWord64 = Word64.fromInt asInt

end