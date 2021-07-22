import threading/spinlock

const
  numThreads = 10
  numIters = 1000

var
  lock: SpinLock
  a = 0
  threads: array[numThreads, Thread[void]]

proc inc =
  #var aLocal = 0
  #for i in 0 ..< numIters:
    #aLocal = aLocal + i
  #withLock lock:
    #a = a + aLocal
  for i in 0 ..< numIters:
    withLock lock:
      a = a + i

proc contention =
  for i in 0 ..< numThreads:
    createThread(threads[i], inc)
  joinThreads(threads)
  assert a == (var s = 0; for i in 0..<numIters: s += i; s) * numThreads

contention()
