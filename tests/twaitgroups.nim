import threading/waitgroups

block basic:
  var wg = createWaitGroup()
  wg.enter(10)
  for _ in 1..10:
    wg.leave()
  wg.wait()

block multiple_threads:
  var data: array[10, int]
  var wg = createWaitGroup()

  proc worker(i: int) =
    data[i] = 42
    wg.leave()

  var threads: array[10, Thread[int]]
  wg.enter(10)
  for i in 0..<10:
    createThread(threads[i], worker, i)

  wg.wait()
  for x in data:
    doAssert x == 42

  joinThreads(threads)

block multiple_waits:
  var wg = createWaitGroup()
  wg.enter(1)

  proc worker() =
    wg.wait()

  var threads: array[10, Thread[void]]
  for i in 0..<10:
    createThread(threads[i], worker)

  wg.leave()

  joinThreads(threads)
