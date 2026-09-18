## Regression test: once all senders are gone, the channel must not report
## closed on the receiving side until the queued items have been drained:
## readers must be able to read every sent item, and only then observe
## `closed`.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import threading/channels
import std/isolation

block closed_only_after_drained:
  var (s, r) = newChan[int](elements = 10)
  doAssert not r.closed()
  for i in 1..5:
    doAssert s.send(isolate(i))
  # All senders are gone, but 5 items are still queued:
  # the channel must not report closed yet
  s = Sender[int]()
  doAssert not r.closed()
  var dst: int
  for i in 1..5:
    doAssert r.tryRecv(dst)
    doAssert dst == i
    doAssert r.closed() == (i == 5)  # closed only once fully drained
  doAssert not r.tryRecv(dst)

block readers_still_drain_all_items:
  var (s, r) = newChan[int](elements = 10)
  for i in 1..5:
    doAssert s.send(isolate(i))
  s = Sender[int]()
  # Blocking recv yields every queued item in order, then default(T)
  var dst: int
  for i in 1..5:
    doAssert r.recv(dst)
    doAssert dst == i
  doAssert not r.recv(dst)
  doAssert dst == 0
