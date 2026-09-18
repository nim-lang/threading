## Stress test: destroying the last Sender and the last Receiver concurrently
## must not use the channel after it has been freed.
##
## Regression: the refcount decrement and the free used to happen outside the
## channel lock, so one thread could free the channel while the other was
## about to take the lock for the close broadcast (use-after-free, heap
## corruption). The handles are passed to the threads as pointers so that
## exactly one Sender and one Receiver exist at a time.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import threading/channels
import std/atomics

when defined(tsan):
  # TSan is slow and reports the race within the first iterations anyway
  const Iterations = 20_000
else:
  const Iterations = 200_000

var globalPair = newChan[int]()
var startA: Atomic[int]
var startB: Atomic[int]

proc destroySender(p: ptr Sender[int]) {.thread.} =
  while startA.load(moAcquire) == 0:
    for k in 0..3: discard k
  p[] = Sender[int]()   # =copy with a nil source -> =destroy(p[])

proc destroyReceiver(p: ptr Receiver[int]) {.thread.} =
  while startB.load(moAcquire) == 0:
    for k in 0..3: discard k
  p[] = Receiver[int]()

var a: Thread[ptr Sender[int]]
var b: Thread[ptr Receiver[int]]
for i in 0..<Iterations:
  startA.store(0, moRelaxed)
  startB.store(0, moRelaxed)
  createThread(a, destroySender, addr(globalPair.sender))
  createThread(b, destroyReceiver, addr(globalPair.receiver))
  # Give both threads time to reach their spin
  for j in 0..<50:
    if (j and 7) == 0: discard j
  startA.store(1, moRelease)
  # Start the receiver destructor with a variable phase offset so the two
  # destructors sweep across each other's refcount/lock window
  for j in 0..<(i and 199):
    if (j and 3) == 0: discard j
  startB.store(1, moRelease)
  joinThread(a)
  joinThread(b)
  # The workers have nilled both handles (`p[] = Sender[int]()`), so
  # assign a fresh channel (the compiler elides the temporary, leaving
  # exactly one Sender and one Receiver)
  globalPair = newChan[int]()
