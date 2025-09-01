This is a direct translation of this file:
https://github.com/cmuparlay/parlaylib/blob/e1f1dc0ccf930492a2723f7fbef8510d35bf57f5/examples/delaunay.h

This implementation is interesting algorithmically but is not especially
fast. It is significantly slower and less space efficient than the `delaunay`
implementation.

The implementation uses a central hash table to store (1) the mesh, and (2)
a set of outstanding edges that may need to be processed. Note that the use of
the hash table in this way results in memory entanglement.

Some basic tests have been run but more testing is probably required.