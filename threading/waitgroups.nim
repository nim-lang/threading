#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Wait groups for Nim.

import std / [locks]

type
  WaitGroup* = object ## \
    ## A WaitGroup is an synchronization object that can be used to `wait` until
    ## all workers have completed.
    c: Cond
    L: Lock
    runningTasks: int

when defined(nimAllowNonVarDestructor):
  proc `=destroy`(b: WaitGroup) {.inline.} =
    let x = addr(b)
    deinitCond(x.c)
    deinitLock(x.L)
else:
  proc `=destroy`(b: var WaitGroup) {.inline.} =
    deinitCond(b.c)
    deinitLock(b.L)

proc `=copy`(dest: var WaitGroup; src: WaitGroup) {.error.}
proc `=sink`(dest: var WaitGroup; src: WaitGroup) {.error.}

proc createWaitGroup*(): WaitGroup =
  result = default(WaitGroup)
  initCond(result.c)
  initLock(result.L)

proc enter*(b: var WaitGroup; delta = 1) {.inline.} =
  ## Tells the WaitGroup that one or more workers (the `delta` parameter says
  ## how many) "entered" which means to increase the counter that counts how
  ## many workers to wait for.
  acquire(b.L)
  inc b.runningTasks, delta
  release(b.L)

proc leave*(b: var WaitGroup) {.inline.} =
  ## Tells the WaitGroup that one worker has finished its task.
  acquire(b.L)
  dec b.runningTasks
  signal(b.c)
  release(b.L)

proc wait*(b: var WaitGroup) =
  ## Waits until all workers have completed.
  acquire(b.L)
  while b.runningTasks > 0:
    wait(b.c, b.L)
  release(b.L)
