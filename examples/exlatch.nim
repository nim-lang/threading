import threading/latch

const
  numThreads = 4

var
  completedThreadCounter, callingThreadBlocker, readyThreadCounter: Latch
  threads: array[numThreads, Thread[void]]

proc work =
  readyThreadCounter.dec()
  wait callingThreadBlocker
  echo "Counted down"
  completedThreadCounter.dec()

proc main =
  init completedThreadCounter, numThreads
  init callingThreadBlocker, 1
  init readyThreadCounter, numThreads
  for i in 0 ..< numThreads:
    createThread(threads[i], work)
  wait readyThreadCounter
  echo "Workers ready"
  callingThreadBlocker.dec()
  wait completedThreadCounter
  echo "Workers complete"
  joinThreads(threads)

main()
