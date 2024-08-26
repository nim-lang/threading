## Test for and edge case of a channel with a single-element buffer:
## https://github.com/nim-lang/threading/pull/27#issue-1652851878
## Also tests `trySend` and `tryRecv` templates.

import threading/channels, std/os
const Message = "Hello"

block trySend_recv:
  var attempts = 0

  proc test(chan: Chan[string]) {.thread.} =
    var notSent = true
    let msg = Message
    while notSent:
      notSent = not chan.trySend(msg)
      if notSent:
        atomicInc(attempts)

  var chan = newChan[string](elements = 1)
  # Fill the channel before spawning the thread
  chan.send("Dummy message")

  var thread: Thread[Chan[string]]
  createThread(thread, test, chan)
  sleep 10

  # Receive the dummy message to make room for the real message
  discard chan.recv()

  var dest: string
  chan.recv(dest)
  doAssert dest == Message

  thread.joinThread()
  doAssert attempts > 0, "trySend should have been attempted multiple times"


block send_tryRecv:
  var attempts = 0

  proc test(chan: Chan[string]) {.thread.} =
    var notReceived = true
    var msg: string
    while notReceived:
      notReceived = not chan.tryRecv(msg)
      if notReceived:
        atomicInc(attempts)
    doAssert msg == Message

  var chan = newChan[string](elements = 1)

  var thread: Thread[Chan[string]]
  createThread(thread, test, chan)
  sleep 10

  let src = Message
  chan.send(src)

  thread.joinThread()
  doAssert attempts > 0, "tryRecv should have been attempted multiple times"

