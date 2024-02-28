import threading/once

const
  NumThreads = 10
  NumIters = 1000

type
  Singleton = object
    data: int

var
  threads: array[NumThreads, Thread[void]]
  counter = 1
  instance: ptr Singleton
  o = createOnce()

proc getInstance(): ptr Singleton =
  once(o):
    instance = createSharedU(Singleton)
    instance.data = counter
    inc counter
  result = instance

proc routine {.thread.} =
  for i in 1..NumIters:
    assert getInstance().data == 1

proc main =
  for i in 0..<NumThreads:
    createThread(threads[i], routine)
  joinThreads(threads)
  deallocShared(instance)

main()
