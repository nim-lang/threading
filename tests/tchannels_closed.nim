## Tests the `closed` procs: a channel reports closed for sending when the
## last Sender is destroyed and closed for receiving when the last Receiver
## is destroyed. Destroying one of several handles of a direction does not
## close it, and once a direction is closed it stays closed.
##
## Handles are released early with `s = Sender[int]()` (assignment of a nil
## handle), not `=destroy`: `=destroy` does not nil the handle's pointer, so
## an explicit `=destroy` on a local would be run a second time by the
## compiler at scope end and touch the channel again.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import threading/channels
import std/isolation

block not_closed_initially:
  let (s, r) = newChan[int]()
  # Compile-time check that `closed` returns a bool
  let sClosed: bool = s.closed()
  let rClosed: bool = r.closed()
  doAssert not sClosed
  doAssert not rClosed

block dup_keeps_direction_open:
  var (s, r) = newChan[int]()
  var s2 = s
  var r2 = r
  s = Sender[int]()
  r = Receiver[int]()
  # The copies keep both directions open
  doAssert not s2.closed()
  doAssert not r2.closed()
  s2 = Sender[int]()
  r2 = Receiver[int]()

block closed_for_sending:
  var (s, r) = newChan[int]()
  var s2 = s
  s = Sender[int]()
  doAssert not s2.closed()  # s2 keeps the channel open for sending
  s2 = Sender[int]()
  doAssert r.closed()       # all senders are gone
  # The receiver still works: an empty closed channel yields default(T)
  doAssert r.recv() == 0
  var dst: int
  doAssert not r.recv(dst)
  doAssert dst == 0
  doAssert not r.tryRecv(dst)

block closed_for_receiving:
  var (s, r) = newChan[int]()
  var r2 = r
  r = Receiver[int]()
  doAssert not r2.closed()  # r2 keeps the channel open for receiving
  r2 = Receiver[int]()
  doAssert s.closed()       # all receivers are gone
  # Sending is refused once the channel is closed for receiving
  doAssert not s.send(isolate(1))
