# primes-simple-bool

This is an alternative implementation of [`primes`](../primes), replacing
the `Word8.word` flags with just simple booleans. This is slightly less
efficient, due to the compilation strategy for booleans, which is 4 bytes
instead of 1.