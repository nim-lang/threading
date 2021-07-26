#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Antonis Geralis
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
# Nim port of https://github.com/rigtorp/SPSCQueue
import std/isolation, atomics2
from std/typetraits import supportsCopyMem

const
  cacheLineSize = 64

type
  SpscQueue*[T] = object
    cap: int
    data: ptr UncheckedArray[T]
    head {.align(cacheLineSize).}: Atomic[int]
    cachedTail {.align(cacheLineSize).}: int
    tail {.align(cacheLineSize).}: Atomic[int]
    cachedHead {.align(cacheLineSize).}: int
    # Padding to avoid adjacent allocations to share cache line with tail
    padding: array[cacheLineSize - sizeof(Atomic[int]), byte]

template Pad: untyped = (cacheLineSize - 1) div sizeof(T) + 1

proc `=destroy`*[T](self: var SpscQueue[T]) =
  if self.data != nil:
    when not supportsCopyMem(T):
      let head = self.head.load(Acquire)
      var tail = self.tail.load(Relaxed)
      while tail != head:
        `=destroy`(self.data[tail + Pad])
        inc tail
        if tail == self.cap:
          tail = 0
    deallocShared(self.data)

proc `=copy`*[T](dest: var SpscQueue[T]; source: SpscQueue[T]) {.error.}

proc init*[T](self: var SpscQueue[T]; capacity: Natural) =
  self.cap = capacity + 1
  self.data = cast[ptr UncheckedArray[T]](allocShared((self.cap + 2 * Pad) * sizeof(T)))

proc newSpscQueue*[T](cap: int): SpscQueue[T] =
  init(result, cap)

proc cap*[T](self: SpscQueue[T]): int = self.cap - 1

proc len*[T](self: SpscQueue[T]): int =
  result = self.head.load(Acquire) - self.tail.load(Acquire)
  if result < 0:
    result += self.cap

proc tryPush*[T](self: var SpscQueue[T]; value: var Isolated[T]): bool {.
    nodestroy.} =
  let head = self.head.load(Relaxed)
  var nextHead = head + 1
  if nextHead == self.cap:
    nextHead = 0
  if nextHead == self.cachedTail:
    self.cachedTail = self.tail.load(Acquire)
    if nextHead == self.cachedTail:
      result = false
  else:
    self.data[head + Pad] = extract value
    self.head.store(nextHead, Release)
    result = true

template tryPush*[T](self: SpscQueue[T]; value: T): bool =
  ## .. warning:: Using this template in a loop causes multiple evaluations of `value`.
  mixin isolate
  var p = isolate(value)
  tryPush(self, p)

proc tryPop*[T](self: var SpscQueue[T]; value: var T): bool =
  let tail = self.tail.load(Relaxed)
  if tail == self.cachedHead:
    self.cachedHead = self.head.load(Acquire)
    if tail == self.cachedHead:
      result = false
  else:
    value = move self.data[tail + Pad]
    var nextTail = tail + 1
    if nextTail == self.cap:
      nextTail = 0
    self.tail.store(nextTail, Release)
    result = true

when isMainModule:
  # Don't move this test
  proc testBasic =
    var r: SpscQueue[int]
    init(r, 100)
    for i in 0..<r.cap:
      # try to insert an element
      if r.tryPush(i):
        # succeeded
        discard
      else:
        # buffer full
        assert i == cap(r)
    for i in 0..<r.cap:
      # try to retrieve an element
      var value: int
      if r.tryPop(value):
        # succeeded
        discard
      else:
        # buffer empty
        assert i == cap(r)

  testBasic()
