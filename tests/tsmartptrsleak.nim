import threading/smartptrs
import std/isolation
import std/locks
import std/atomics
import threading/channels

var
  freeCounts: Atomic[int]

type
  TestObj = object

when defined(nimAllowNonVarDestructor):
  proc `=destroy`(obj: TestObj) =
    discard freeCounts.fetchAdd(1, moRelease)
else:
  proc `=destroy`(obj: var TestObj) =
    discard freeCounts.fetchAdd(1, moRelease)

var
  thr: array[0..1, Thread[void]]
  chan = newChan[SharedPtr[TestObj]]()

const
  # N = 10_000_000
  # doSleep = false
  N = 10_000
  doSleep = true

import std/os

proc threadA() {.thread.} =
  for i in 1..N:
    block:
      var a: SharedPtr[TestObj] = newSharedPtr(unsafeIsolate TestObj())
      var b = a
      chan.send(b)
      doAssert a.isNil == false # otherwise we don't copy a?
      when doSleep:
        os.sleep(1)

proc threadB() {.thread.} =
  for i in 1..N:
    block:
      var b: SharedPtr[TestObj] = chan.recv()
      when doSleep:
        os.sleep(1)

createThread(thr[0], threadA)
createThread(thr[1], threadB)
joinThreads(thr)

echo "freeCounts: got: ", load(freeCounts, moRelaxed), " expected: ", N
echo ""
assert freeCounts.load(moRelaxed) == N
