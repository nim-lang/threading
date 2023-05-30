## Test for and edge case of a channel with a single-element buffer:
## https://github.com/nim-lang/threading/pull/27#issue-1652851878
## Also tests `trySend` and `tryRecv` templates.

import threading/channels
const Message = "Hello"

block trySend_recv:
  proc test(chan: ptr Chan[string]) {.thread.} =
    var notSent = true
    var msg = Message
    while notSent:
      notSent = not chan[].trySend(msg)

  var chan = newChan[string](elements = 1)
  var thread: Thread[ptr Chan[string]]
  var dest: string

  createThread(thread, test, chan.addr)
  chan.recv(dest)
  doAssert dest == Message

  thread.joinThread()


block send_tryRecv:
  proc test(chan: ptr Chan[string]) {.thread.} =
    var notReceived = true
    var msg: string
    while notReceived:
      notReceived = not chan[].tryRecv(msg)
    doAssert msg == Message

  var chan = newChan[string](elements = 1)
  var thread: Thread[ptr Chan[string]]
  let src = Message

  createThread(thread, test, chan.addr)
  chan.send(src)

  thread.joinThread()
