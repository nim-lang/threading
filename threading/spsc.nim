#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Antonis Geralis
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
import smartptrs, spsc_queue, std/isolation
export smartptrs.isNil

type
  SpscSender*[T] = object
    queue: SharedPtr[SpscQueue[T]]

#proc `=copy`*[T](dest: var SpscSender[T]; source: SpscSender[T]) {.error.}

proc newSpscSender*[T](queue: sink SharedPtr[SpscQueue[T]]): SpscSender[T] =
  result = SpscSender[T](queue: queue)

proc trySend*[T](self: SpscSender, t: var Isolated[T]): bool {.inline.} =
  self.queue[].tryPush(t)

template trySend*[T](self: SpscSender[T]; value: T): bool =
  ## .. warning:: Using this template in a loop causes multiple evaluations of `value`.
  mixin isolate
  var p = isolate(value)
  trySend(self, p)

type
  SpscReceiver*[T] = object
    queue: SharedPtr[SpscQueue[T]]

#proc `=copy`*[T](dest: var SpscReceiver[T]; source: SpscReceiver[T]) {.error.}

proc newSpscReceiver*[T](queue: sink SharedPtr[SpscQueue[T]]): SpscReceiver[T] =
  result = SpscReceiver[T](queue: queue)

proc tryRecv*[T](self: SpscReceiver; dst: var T): bool {.inline.} =
  self.queue[].tryPop(dst)

proc newSpscChannel*[T](cap: int): (SpscSender[T], SpscReceiver[T]) =
  let queue = newSharedPtr[SpscQueue[T]](newSpscQueue[T](cap))
  result = (newSpscSender[T](queue), newSpscReceiver[T](queue))
