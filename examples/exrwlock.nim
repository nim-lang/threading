import std/os, threading/rwlock

const
  numThreads = 5

var
  rw: RwLock # global object of monitor class
  readers: array[numThreads, Thread[int]]
  writers: array[numThreads, Thread[int]]
  fuel {.guard: rw.}: int

proc gauge(id: int) =
  # each reader attempts to read 5 times
  for i in 0 ..< 10:
    readWith rw:
      echo "#", id, " observed fuel. Now left: ", fuel
    sleep(500)

proc pump(id: int) =
  # each writer attempts to write 5 times
  for i in 0 ..< 5:
    writeWith rw:
      echo "#", id, " filled with fuel..."
      fuel += 30
      sleep(250)
    sleep(250)

proc main =
  init rw
  for i in 0 ..< numThreads:
    # creating threads which execute writer function
    createThread(writers[i], pump, i)
    # creating threads which execute reader function
    createThread(readers[i], gauge, i)
  joinThreads(readers)
  joinThreads(writers)
  #assert fuel == 750

main()
