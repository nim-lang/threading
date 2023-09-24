import threading/semaphore, std/strformat

const
  bufSize = 16
  numIters = 1000

var
  thr1, thr2: Thread[void]
  buf: array[bufSize, int]
  head, tail = 0
  chars, spaces: Semaphore

template next(current: untyped): untyped = (current + 1) and bufSize - 1

proc producer =
  for i in 0 ..< numIters:
    wait spaces
    assert buf[head] <= i, &"Constraint: recv_{buf[tail]} < send_{i}+{bufSize}"
    buf[head] = i
    head = next(head)
    signal chars

proc consumer =
  for i in 0 ..< numIters:
    wait chars
    assert buf[tail] == i, &"Constraint: send_{buf[tail]} < recv_{i}"
    buf[tail] = i + bufSize
    tail = next(tail)
    signal spaces

proc testSemaphore =
  init chars
  init spaces, bufSize

  createThread(thr1, producer)
  createThread(thr2, consumer)
  joinThread(thr1)
  joinThread(thr2)

testSemaphore()
