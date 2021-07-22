import threading/[once, atomics]

const
  numThreads = 10
  maxIters = 1000

type
  Singleton = object
    data: int

var
  threads: array[numThreads, Thread[void]]
  counter = 1
  instance: ptr Singleton
  o: Once

proc getInstance(): ptr Singleton =
  once(o):
    instance = createSharedU(Singleton)
    instance.data = counter
    inc counter
  result = instance

proc routine {.thread.} =
  for i in 1 .. maxIters:
    assert getInstance().data == 1

proc main =
  init o
  for i in 0 ..< numThreads:
    createThread(threads[i], routine)
  joinThreads(threads)
  deallocShared(instance)

main()
