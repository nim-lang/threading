## Tests the close semantics of channels: when the last sender is destroyed,
## the channel is closed for sending and receivers drain the remaining
## messages then start receiving default(T). Symmetrically, when the last
## receiver is destroyed, the channel is closed for receiving and senders
## (including blocked ones) are woken up and their sends fail.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import threading/channels
import std/[os, isolation]

block drain_then_default:
  # A receiver created after the last sender is gone drains the queue
  # and then receives default(T).
  var receiver: Receiver[int]
  block:
    var (sender, r) = newChan[int]()
    discard sender.send(1)
    discard sender.send(2)
    receiver = r
  # Both senders are gone here: the channel is closed for sending.
  doAssert receiver.recv() == 1
  doAssert receiver.recv() == 2
  doAssert receiver.recv() == 0 # default(int)
  doAssert receiver.recv() == 0 # still default(int)
  var dst: int
  doAssert not receiver.tryRecv(dst)
  doAssert not receiver.recv(dst) # closed: returns false

block last_sender_closes:
  # Destroying one of two senders does not close the channel;
  # destroying the last one does.
  var receiver: Receiver[int]
  block:
    var (sender, r) = newChan[int]()
    receiver = r
    var s2 = sender # A second sender
    discard s2.send(7)
  doAssert receiver.recv() == 7
  doAssert receiver.recv() == 0 # default(int)

block close_wakes_blocked_receiver:
  # A receiver blocked on recv is woken up when the last sender is
  # destroyed while it is waiting, and receives default(T).
  var receiver: Receiver[int]
  var thr: Thread[Receiver[int]]
  var got: int
  proc worker(r: Receiver[int]) {.thread.} =
    got = r.recv() # Blocks until the channel is closed
  block:
    var (sender, r) = newChan[int]()
    receiver = r
    createThread(thr, worker, receiver)
    sleep(100) # Give the worker time to block on recv
  # The last sender was destroyed above, closing the channel while the
  # worker is blocked on recv.
  thr.joinThread()
  doAssert got == 0 # default(int)

block close_wakes_blocked_sender:
  # A sender blocked on send (full channel) is woken up when the last
  # receiver is destroyed, and send returns false.
  var sender: Sender[int]
  var thr: Thread[Sender[int]]
  var sent: bool
  proc worker(s: Sender[int]) {.thread.} =
    # The channel is full when the worker starts, so this blocks until
    # the last receiver is destroyed.
    sent = send(s, isolate(1))
  block:
    var (s, r) = newChan[int](elements = 1)
    sender = s
    discard s.send(0) # Fill the single-slot buffer
    createThread(thr, worker, sender)
    sleep(100) # Give the worker time to block on send
  # The last receiver was destroyed above, closing the channel for
  # receiving while the worker is blocked on send.
  thr.joinThread()
  doAssert not sent # send returned false: channel closed for receiving
