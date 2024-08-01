#
#
#            Nim's Runtime Library
#        (c) Copyright 2023 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Semaphore for Nim.

runnableExamples:

  import std / os

  var arrived = createSemaphore(2)

  proc worker(i: int) =
    echo i, " starts"
    wait arrived
    sleep 1
    echo i, " progresses"
    signal arrived

  var threads: array[4, Thread[int]]
  for i in 0..<4:
    createThread(threads[i], worker, i)
  joinThreads(threads)


import std/locks

type
  Semaphore* = object
    ## A semaphore is a synchronization primitive that controls access to a
    ## shared resource through the use of a counter. If the counter is greater
    ## than zero, then access is allowed. If it is zero, then access is denied.
    ## What the access is depends on the use of the semaphore.
    ##
    ## Semaphores are typically used to limit the number of threads than can
    ## access some (physical or logical) resource.
    ##
    ## Semaphores are of two types: counting and binary. Counting semaphores
    ## can take non-negative integer values to indicate the number of
    ## resources available. Binary semaphores can only take the values 0 and 1
    ## and are used to implement locks.
    c: Cond
    L: Lock
    counter: int

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(s: Semaphore) {.inline.} =
    deinitCond(s.c)
    deinitLock(s.L)
else:
  proc `=destroy`*(s: var Semaphore) {.inline.} =
    deinitCond(s.c)
    deinitLock(s.L)

proc `=sink`*(dest: var Semaphore; src: Semaphore) {.error.}
proc `=copy`*(dest: var Semaphore; src: Semaphore) {.error.}

proc createSemaphore*(count: Natural = 0): Semaphore =
  result = default(Semaphore)
  result.counter = count
  initCond(result.c)
  initLock(result.L)

proc wait*(s: var Semaphore) =
  ## Wait for the semaphore to be signaled. If the semaphore's counter is zero,
  ## wait blocks until it becomes greater than zero.
  acquire(s.L)
  while s.counter <= 0:
    wait(s.c, s.L)
  dec s.counter
  release(s.L)

proc signal*(s: var Semaphore) {.inline.} =
  ## Signal the semaphore.
  acquire(s.L)
  inc s.counter
  signal(s.c)
  release(s.L)
