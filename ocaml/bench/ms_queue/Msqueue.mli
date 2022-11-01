type 'a queue
val mkQueue: 'a -> 'a queue
val isEmpty: 'a queue -> bool
val enqueue: 'a queue -> 'a -> unit
val dequeue: 'a queue -> 'a option