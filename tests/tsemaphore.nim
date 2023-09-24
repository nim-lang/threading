import threading/semaphore, std/strformat

const
  BufSize = 16
  NumIters = 1000

var
  thr1, thr2: Thread[void]
  buf: array[BufSize, int]
  head, tail = 0
  chars = createSemaphore()
  spaces = createSemaphore(BufSize)

template next(current: untyped): untyped = (current + 1) and BufSize - 1

proc producer =
  for i in 0..<NumIters:
    wait spaces
    assert buf[head] <= i, &"Constraint: recv_{buf[tail]} < send_{i}+{BufSize}"
    buf[head] = i
    head = next(head)
    signal chars

proc consumer =
  for i in 0..<NumIters:
    wait chars
    assert buf[tail] == i, &"Constraint: send_{buf[tail]} < recv_{i}"
    buf[tail] = i + BufSize
    tail = next(tail)
    signal spaces

proc testSemaphore =
  createThread(thr1, producer)
  createThread(thr2, consumer)
  joinThread(thr1)
  joinThread(thr2)

testSemaphore()
