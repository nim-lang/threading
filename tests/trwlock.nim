import threading/rwlock, std/os

const
  NumThreads = 10
  NumIters = 100

var
  rw = createRwLock()
  data = 0
  threads: array[NumThreads, Thread[void]]

proc routine =
  for i in 0..<NumIters:
    writeWith rw:
      let tmp = data
      data = -1
      sleep 1
      data = tmp + 1

proc frob =
  for i in 0..<NumThreads:
    createThread(threads[i], routine)
  for i in 0..<NumIters:
    readWith(rw, assert data >= 0)
  joinThreads(threads)
  assert data == NumIters * NumThreads

frob()
