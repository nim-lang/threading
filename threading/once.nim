#
#
#            Nim's Runtime Library
#        (c) Copyright 2023 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Once for Nim.

runnableExamples:

  type
    Singleton = object
      data: int

  var
    counter = 1
    instance: ptr Singleton
    o = createOnce()

  proc getInstance(): ptr Singleton =
    once(o):
      instance = createSharedU(Singleton)
      instance.data = counter
      inc counter
    result = instance

  proc worker {.thread.} =
    for i in 1..1000:
      assert getInstance().data == 1

  var threads: array[10, Thread[void]]
  for i in 0..<10:
    createThread(threads[i], worker)
  joinThreads(threads)
  deallocShared(instance)


import std / [locks, atomics]

type
  Once* = object
    ## Once is a type that allows you to execute a block of code exactly once.
    ## The first call to `once` will execute the block of code and all other
    ## calls will be ignored.
    L: Lock
    finished: Atomic[bool]

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(o: Once) {.inline.} =
    let x = addr(o)
    deinitLock(x.L)
else:
  proc `=destroy`*(o: var Once) {.inline.} =
    deinitLock(o.L)

proc `=sink`*(dest: var Once; source: Once) {.error.}
proc `=copy`*(dest: var Once; source: Once) {.error.}

proc createOnce*(): Once =
  result = default(Once)
  initLock(result.L)

template once*(o: Once, body: untyped) =
  ## Executes `body` exactly once.
  if not o.finished.load(moAcquire):
    acquire(o.L)
    try:
      if not o.finished.load(moRelaxed):
        try:
          body
        finally:
          o.finished.store(true, moRelease)
    finally:
      release(o.L)
