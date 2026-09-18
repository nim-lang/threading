## Regression test: when the last Receiver is destroyed, the items still in
## the queue must be destroyed - their finalizers must run - in the same FIFO
## order a reader would dequeue them, before the channel buffer is freed.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import threading/channels
import std/isolation

type Item = object
  id: int
  data: pointer

var destroyedIds: seq[int]

proc `=destroy`(item: var Item) =
  if item.data != nil:
    dealloc(item.data)
    destroyedIds.add(item.id)

block pending_items_are_destroyed_in_fifo_order:
  var (s, r) = newChan[Item](elements = 10)
  for i in 1..5:
    doAssert s.send(isolate(Item(id: i, data: alloc(64))))
  # The last receiver is destroyed while 5 items are still queued:
  # their finalizers must run, in the order a reader would see them
  r = Receiver[Item]()
  doAssert destroyedIds == @[1, 2, 3, 4, 5]
  s = Sender[Item]()
