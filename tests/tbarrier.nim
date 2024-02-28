import threading/barrier, std/[os, strformat]

const
  NumThreads = 10
  NumIters = 100

var
  b = createBarrier(NumThreads)
  phases: array[NumThreads, int]
  threads: array[NumThreads, Thread[int]]

proc routine(id: int) =
  for i in 0..<NumIters:
    phases[id] = i
    if (id + i) mod NumThreads == 0:
      sleep 1
    wait b
    for j in 0..<NumThreads:
      assert phases[j] == i, &"{id} in phase {i} sees {j} in phase {phases[j]}"
    wait b

proc testBarrier =
  for i in 0..<NumThreads:
    createThread(threads[i], routine, i)
  joinThreads(threads)

testBarrier()
