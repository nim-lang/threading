import threading/barrier, std/[os, strformat]

const
  numThreads = 10
  numIters = 100

var
  b: Barrier
  phases: array[numThreads, int]
  threads: array[numThreads, Thread[int]]

proc routine(id: int) =
  for i in 0 ..< numIters:
    phases[id] = i
    if (id + i) mod numThreads == 0:
      sleep 1
    wait b
    for j in 0 ..< numThreads:
      assert phases[j] == i, &"{id} in phase {i} sees {j} in phase {phases[j]}"
    wait b

proc testBarrier =
  init b, numThreads
  for i in 0 ..< numThreads:
    createThread(threads[i], routine, i)
  joinThreads(threads)

testBarrier()
