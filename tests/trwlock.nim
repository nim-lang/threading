import threading/rwlock, std/os

const
  numThreads = 10
  numIters = 100

var
  rw: RwLock
  data = 0
  threads: array[numThreads, Thread[void]]

proc routine =
  for i in 0..<numIters:
    writeWith rw:
      let tmp = data
      data = -1
      sleep 1
      data = tmp + 1

proc frob =
  init rw
  for i in 0..<numThreads:
    createThread(threads[i], routine)
  for i in 0..<numIters:
    readWith(rw, assert data >= 0)
  joinThreads(threads)
  assert data == numIters * numThreads

frob()
