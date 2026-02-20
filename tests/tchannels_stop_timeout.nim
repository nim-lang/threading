import sync/channels
import std/[os, times, isolation]

type
  RecvPayload = tuple[ch: Chan[int], done: Chan[bool]]
  SendPayload = tuple[ch: Chan[int], done: Chan[bool]]

proc recvWorker(p: RecvPayload) {.thread.} =
  var value: int
  let ok = p.ch.recv(value)
  discard p.done.send(ok)

proc sendWorker(p: SendPayload) {.thread.} =
  let ok = p.ch.send(42)
  discard p.done.send(ok)

var destroyedCount = 0

type
  DrainProbe = object
    id: int

proc `=destroy`(x: var DrainProbe) =
  atomicInc(destroyedCount)

block stop_unblocks_recv:
  var ch = newChan[int](elements = 1)
  var done = newChan[bool](elements = 1)
  var thread: Thread[RecvPayload]
  createThread(thread, recvWorker, (ch, done))
  sleep(50)

  doAssert not ch.stopToken()
  ch.stop()
  doAssert ch.stopToken()

  var recvOk = true
  doAssert done.recv(recvOk, timeout = initDuration(milliseconds = 500))
  doAssert recvOk == false
  thread.joinThread()

block stop_unblocks_send:
  var ch = newChan[int](elements = 1)
  doAssert ch.send(1)

  var done = newChan[bool](elements = 1)
  var thread: Thread[SendPayload]
  createThread(thread, sendWorker, (ch, done))
  sleep(50)

  ch.stop()

  var sendOk = true
  doAssert done.recv(sendOk, timeout = initDuration(milliseconds = 500))
  doAssert sendOk == false
  thread.joinThread()

block recv_timeout:
  var ch = newChan[int](elements = 1)
  var value: int
  doAssert not ch.recv(value, timeout = initDuration(milliseconds = 20))

block send_timeout:
  var ch = newChan[int](elements = 1)
  doAssert ch.send(1)
  doAssert not ch.send(2, timeout = initDuration(milliseconds = 20))

block destroy_drains_pending_items:
  let baseline = destroyedCount
  block:
    var ch = newChan[DrainProbe](elements = 8)
    for i in 0..<3:
      var iso = isolate(DrainProbe(id: i))
      doAssert ch.tryTake(iso)
  doAssert destroyedCount - baseline >= 3
