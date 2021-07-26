import os, sync/spsc_queue

const
  numIters = 200

var
  pong: Thread[void]
  q1: SpscQueue[int]
  q2: SpscQueue[int]

template pushLoop(tx, data: typed, body: untyped): untyped =
  while not tx.tryPush(data):
    body

template popLoop(rx, data: typed, body: untyped): untyped =
  while not rx.tryPop(data):
    body

proc pongFn {.thread.} =
  while true:
    var n: int
    popLoop(q1, n): cpuRelax()
    pushLoop(q2, n): cpuRelax()
    #sleep 20
    if n == 0: break
    assert n == 9091_89

proc pingPong =
  q1 = newSpscQueue[int](50)
  q2 = newSpscQueue[int](50)
  createThread(pong, pongFn)
  for i in 1..numIters:
    pushLoop(q1, 9091_89): cpuRelax()
    var n: int
    #sleep 10
    popLoop(q2, n): cpuRelax()
    assert n == 9091_89
  pushLoop(q1, 0): cpuRelax()
  var n: int
  popLoop(q2, n): cpuRelax()
  assert n == 0
  pong.joinThread()

pingPong()
