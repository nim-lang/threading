## Test for and edge case of a channel with a single-element buffer:
## https://github.com/nim-lang/threading/pull/27#issue-1652851878
## Also tests `trySend` and `tryRecv` templates.

import threading/channels, std/os
const Message = "Hello"

block trySend_recv:
  var attempts = 0

  proc test(s: Sender[string]) {.thread.} =
    var notSent = true
    let msg = Message
    while notSent:
      notSent = not s.trySend(msg)
      if notSent:
        atomicInc(attempts)

  var (s, r) = newChan[string](elements = 1)
  # Fill the channel before spawning the thread
  discard s.send("Dummy message")

  var thread: Thread[Sender[string]]
  createThread(thread, test, s)
  sleep 10

  # Receive the dummy message to make room for the real message
  discard r.recv()

  var dest: string
  discard r.recv(dest)
  doAssert dest == Message

  thread.joinThread()
  doAssert attempts > 0, "trySend should have been attempted multiple times"


block send_tryRecv:
  var attempts = 0

  proc test(r: Receiver[string]) {.thread.} =
    var notReceived = true
    var msg: string
    while notReceived:
      notReceived = not r.tryRecv(msg)
      if notReceived:
        atomicInc(attempts)
    doAssert msg == Message

  var (s, r) = newChan[string](elements = 1)

  var thread: Thread[Receiver[string]]
  createThread(thread, test, r)
  sleep 10

  let src = Message
  discard s.send(src)

  thread.joinThread()
  doAssert attempts > 0, "tryRecv should have been attempted multiple times"
