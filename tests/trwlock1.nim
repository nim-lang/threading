import threading/rwlock, std/[random, os]

const
  NumThreads = 10
  NumIters = 100

var
  rw = createRwLock()
  data = 0
  threads: array[NumThreads, Thread[void]]

proc routine =
  var r = initRand(getThreadId())
  for i in 0..<NumIters:
    if r.rand(1.0) <= 1 / NumThreads:
      writeWith rw:
        let tmp = data
        data = -1
        sleep 1
        data = tmp + 1
    else:
      readWith rw:
        assert data >= 0

proc frob =
  for i in 0..<NumThreads:
    createThread(threads[i], routine)
  joinThreads(threads)

frob()
