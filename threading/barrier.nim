#
#
#            Nim's Runtime Library
#        (c) Copyright 2023 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Barrier for Nim.

runnableExamples:

  import std / os

  var phases: array[10, int]
  var b = createBarrier(10)

  proc worker(id: int) =
    for i in 0 ..< 100:
      phases[id] = i
      if (id + i) mod 10 == 0:
        sleep 1
      wait b
      for j in 0 ..< 10:
        assert phases[j] == i
      wait b

  var threads: array[10, Thread[int]]
  for i in 0..<10:
    createThread(threads[i], worker, i)

  joinThreads(threads)


import std / locks

type
  Barrier* = object
    ## A barrier is a synchronization mechanism that allows a set of threads to
    ## all wait for each other to reach a common point. Barriers are useful in
    ## programs involving a fixed-size party of cooperating threads that must
    ## occasionally wait for each other. The barrier is called a cyclic barrier
    ## if it can be reused after the waiting threads are released.
    ##
    ## The barrier is initialized for a given number of threads. Each thread
    ## that calls `wait` on the barrier will block until all the threads have
    ## made that call. At this point, the barrier is reset to its initial state
    ## and all threads are released.
    c: Cond
    L: Lock
    required: int # number of threads needed for the barrier to continue
    left: int # current barrier count, number of threads still needed.
    cycle: uint # generation count

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(b: Barrier) {.inline.} =
    let x = addr(b)
    deinitCond(x.c)
    deinitLock(x.L)
else:
  proc `=destroy`*(b: var Barrier) {.inline.} =
    deinitCond(b.c)
    deinitLock(b.L)

proc `=sink`*(dest: var Barrier; src: Barrier) {.error.}
proc `=copy`*(dest: var Barrier; src: Barrier) {.error.}

proc createBarrier*(parties: Natural): Barrier =
  result = default(Barrier)
  result.required = parties
  result.left = parties
  initCond(result.c)
  initLock(result.L)

proc wait*(b: var Barrier) =
  ## Wait for all threads to reach the barrier. When the last thread reaches
  ## the barrier, all threads are released.
  acquire(b.L)
  dec b.left
  if b.left == 0:
    inc b.cycle
    b.left = b.required
    broadcast(b.c)
  else:
    let cycle = b.cycle
    while cycle == b.cycle:
      wait(b.c, b.L)
  release(b.L)
