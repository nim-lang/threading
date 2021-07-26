when declared(broadcast):
  import threading/rwlock, std/[random, os]

  const
    numThreads = 10
    numIters = 100

  var
    rw: RwLock
    data = 0
    threads: array[numThreads, Thread[void]]

  proc routine =
    var r = initRand(getThreadId())
    for i in 0..<numIters:
      if r.rand(1.0) <= 1 / numThreads:
        writeWith rw:
          let tmp = data
          data = -1
          sleep 1
          data = tmp + 1
      else:
        readWith rw:
          assert data >= 0

  proc frob =
    init rw
    for i in 0..<numThreads:
      createThread(threads[i], routine)
    joinThreads(threads)

  frob()
