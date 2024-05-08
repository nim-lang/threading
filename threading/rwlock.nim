#
#
#            Nim's Runtime Library
#        (c) Copyright 2023 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## Readers-writer lock for Nim.

runnableExamples:

  import std / os

  var rw = createRwLock()
  var data = 0

  proc worker =
    for i in 0..<100:
      writeWith rw:
        let tmp = data
        data = -1
        sleep 1
        data = tmp + 1

  var threads: array[10, Thread[void]]
  for i in 0..<10:
    createThread(threads[i], worker)
  for i in 0..<100:
    readWith(rw, assert data >= 0)
  joinThreads(threads)
  assert data == 1000


import std / locks

type
  RwLock* = object
    ## Readers-writer lock. Multiple readers can acquire the lock at the same
    ## time, but only one writer can acquire the lock at a time.
    c: Cond
    L: Lock
    activeReaders, waitingWriters: int
    activeWriter: bool

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(rw: RwLock) {.inline.} =
    let x = addr(rw)
    deinitCond(x.c)
    deinitLock(x.L)
else:
  proc `=destroy`*(rw: var RwLock) {.inline.} =
    deinitCond(rw.c)
    deinitLock(rw.L)

proc `=sink`*(dest: var RwLock; source: RwLock) {.error.}
proc `=copy`*(dest: var RwLock; source: RwLock) {.error.}

proc createRwLock*(): RwLock =
  result = default(RwLock)
  initCond(result.c)
  initLock(result.L)

proc beginRead*(rw: var RwLock) =
  ## Acquire a read lock.
  acquire(rw.L)
  while rw.waitingWriters > 0 or rw.activeWriter:
    wait(rw.c, rw.L)
  inc rw.activeReaders
  release(rw.L)

proc beginWrite*(rw: var RwLock) =
  ## Acquire a write lock.
  acquire(rw.L)
  inc rw.waitingWriters
  while rw.activeReaders > 0 or rw.activeWriter:
    wait(rw.c, rw.L)
  dec rw.waitingWriters
  rw.activeWriter = true
  release(rw.L)

proc endRead*(rw: var RwLock) {.inline.} =
  ## Release a read lock.
  acquire(rw.L)
  dec rw.activeReaders
  rw.c.broadcast()
  release(rw.L)

proc endWrite*(rw: var RwLock) {.inline.} =
  ## Release a write lock.
  acquire(rw.L)
  rw.activeWriter = false
  rw.c.broadcast()
  release(rw.L)

template readWith*(a: RwLock, body: untyped) =
  ## Acquire a read lock and execute `body`. Release the lock afterwards.
  beginRead(a)
  {.locks: [a].}:
    try:
      body
    finally:
      endRead(a)

template writeWith*(a: RwLock, body: untyped) =
  ## Acquire a write lock and execute `body`. Release the lock afterwards.
  beginWrite(a)
  {.locks: [a].}:
    try:
      body
    finally:
      endWrite(a)
