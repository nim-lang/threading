## Tests the deprecated legacy channel API (newChan/Channel) emulated on top
## of a Sender/Receiver pair.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
{.warnings: off.} # This test exercises the deprecated legacy API on purpose.
import threading/channels
import std/[os, isolation]

var chan = newChan[string]()

# This proc will be run in another thread using the threads module.
proc firstWorker(c: channels.Channel[string]) =
  c.send("Hello World!")

# Launch the worker.
var worker1: Thread[channels.Channel[string]]
createThread(worker1, firstWorker, chan)

# Block until the message arrives, then print it out.
var dest = ""
chan.recv(dest)
doAssert dest == "Hello World!"

# Wait for the thread to exit before moving on.
worker1.joinThread()

block legacy_ops:
  let c = newChan[int](elements = 2)
  doAssert c.trySend(1)
  doAssert c.trySend(2)
  doAssert not c.trySend(3) # Channel is full
  doAssert c.peek() == 2
  var x: int
  doAssert c.tryRecv(x)
  doAssert x == 1
  doAssert c.recv() == 2
  doAssert not c.tryRecv(x)

block legacy_isolated_ops:
  let c = newChan[int]()
  var v: Isolated[int] = isolate(5)
  doAssert c.tryTake(v)
  var x: int
  doAssert c.tryRecv(x)
  doAssert x == 5

  let c2 = newChan[string]()
  c2.send("iso")
  discard c2.recvIso() # Exercise the isolated recv API.

  let c3 = newChan[string]()
  c3.send("iso")
  doAssert c3.recv() == "iso"

block legacy_copies:
  let c0 = newChan[int]()
  let c1 = c0
  block:
    let c2 = c0
    let c3 = c0
