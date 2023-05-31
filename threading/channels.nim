#
#
#                                    Nim's Runtime Library
#        (c) Copyright 2021 Andreas Prell, Mamy André-Ratsimbazafy & Nim Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# Based on https://github.com/mratsim/weave/blob/5696d94e6358711e840f8c0b7c684fcc5cbd4472/unused/channels/channels_legacy.nim
# Those are translations of @aprell (Andreas Prell) original channels from C to Nim
# (https://github.com/aprell/tasking-2.0/blob/master/src/channel_shm/channel.c)
# And in turn they are an implementation of Michael & Scott lock-based queues
# (note the paper has 2 channels: lock-free and lock-based) with additional caching:
# Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms
# Maged M. Michael, Michael L. Scott, 1996
# https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf

## This module only works with `--gc:arc` or `--gc:orc`.
##
## .. warning:: This module is experimental and its interface may change.
##
## The following is a simple example of two different ways to use channels:
## blocking and non-blocking.
##

runnableExamples("--threads:on --gc:orc"):
  import std/os

  # In this example a channel is declared at module scope.
  # Channels are generic, and they include support for passing objects between
  # threads.
  # Note that isolated data passed through channels is moved around.
  var chan = newChan[string]()

  # This proc will be run in another thread using the threads module.
  proc firstWorker() =
    chan.send("Hello World!")

  # This is another proc to run in a background thread. This proc takes a while
  # to send the message since it sleeps for 2 seconds (or 2000 milliseconds).
  proc secondWorker() =
    sleep(2000)
    chan.send("Another message")

  # Launch the worker.
  var worker1: Thread[void]
  createThread(worker1, firstWorker)

  # Block until the message arrives, then print it out.
  var dest = ""
  chan.recv(dest)
  assert dest == "Hello World!"

  # Wait for the thread to exit before moving on to the next example.
  worker1.joinThread()

  # Launch the other worker.
  var worker2: Thread[void]
  createThread(worker2, secondWorker)
  # This time, use a non-blocking approach with tryRecv.
  # Since the main thread is not blocked, it could be used to perform other
  # useful work while it waits for data to arrive on the channel.
  var messages: seq[string]
  while true:
    var msg = ""
    if chan.tryRecv(msg):
      messages.add msg # "Another message"
      break

    messages.add "Pretend I'm doing useful work..."
    # For this example, sleep in order not to flood stdout with the above
    # message.
    sleep(400)

  # Wait for the second thread to exit before cleaning up the channel.
  worker2.joinThread()

  assert messages[^1] == "Another message"
  assert messages.len >= 2

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "This channel implementation requires --gc:arc or --gc:orc".}

import std/[locks, atomics, isolation]
import system/ansi_c

# Channel (Shared memory channels)
# ------------------------------------------------------------------------------

type
  ChannelRaw = ptr ChannelObj
  ChannelObj = object
    lock: Lock
    spaceAvailableCV, dataAvailableCV: Cond
    closed: Atomic[bool]
    size: int
    itemsize: int # up to itemsize bytes can be exchanged over this channel
    head: int     # Write/enqueue/send index
    tail: int     # Read/dequeue/receive index
    buffer: ptr UncheckedArray[byte]
    atomicCounter: Atomic[int]

  ChannelCache = ptr ChannelCacheObj
  ChannelCacheObj = object
    next: ChannelCache
    chanSize: int
    chanN: int
    numCached: int

# ------------------------------------------------------------------------------

proc numItems(chan: ChannelRaw): int {.inline.} =
  result = chan.head - chan.tail
  if result < 0:
    inc(result, 2 * chan.size)

  assert result <= chan.size

template isFull(chan: ChannelRaw): bool =
  abs(chan.head - chan.tail) == chan.size

template isEmpty(chan: ChannelRaw): bool =
  chan.head == chan.tail

# Unbuffered / synchronous channels
# ------------------------------------------------------------------------------

template numItemsUnbuf(chan: ChannelRaw): int =
  chan.tail

template isFullUnbuf(chan: ChannelRaw): bool =
  chan.tail == 1

template isEmptyUnbuf(chan: ChannelRaw): bool =
  chan.tail == 0

# ChannelRaw kinds
# ------------------------------------------------------------------------------

proc isUnbuffered(chan: ChannelRaw): bool =
  chan.size == 1

# ChannelRaw status and properties
# ------------------------------------------------------------------------------

when false:
  proc isClosed(chan: ChannelRaw): bool {.inline.} = load(chan.closed, moRelaxed)

proc peek(chan: ChannelRaw): int {.inline.} =
  (if chan.isUnbuffered: numItemsUnbuf(chan) else: numItems(chan))


# Channels memory ops
# ------------------------------------------------------------------------------

proc allocChannel(size, n: int): ChannelRaw =
  result = cast[ChannelRaw](c_malloc(csize_t sizeof(ChannelObj)))

  # To buffer n items, we allocate for n
  result.buffer = cast[ptr UncheckedArray[byte]](c_malloc(csize_t n*size))

  initLock(result.lock)
  initCond(result.spaceAvailableCV)
  initCond(result.dataAvailableCV)

  result.closed.store(false, moRelaxed) # We don't need atomic here, how to?
  result.size = n
  result.itemsize = size
  result.head = 0
  result.tail = 0
  result.atomicCounter.store(0, moRelaxed)


proc freeChannel(chan: ChannelRaw) =
  if chan.isNil:
    return

  if not chan.buffer.isNil:
    c_free(chan.buffer)

  deinitLock(chan.lock)
  deinitCond(chan.spaceAvailableCV)
  deinitCond(chan.dataAvailableCV)

  c_free(chan)

# MPMC Channels (Multi-Producer Multi-Consumer)
# ------------------------------------------------------------------------------

proc sendUnbufferedMpmc(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  when not blocking:
    if chan.isFullUnbuf(): return false

  # for a buffer of size=1 only tail index is used
  acquire(chan.lock)

  # check for when another thread was faster to fill
  when blocking:
    while chan.isFullUnbuf():
      wait(chan.spaceAvailableCV, chan.lock)
  else:
    if chan.isFullUnbuf():
      release(chan.lock)
      return false

  assert chan.isEmptyUnbuf()
  assert size <= chan.itemsize
  copyMem(chan.buffer, data, size)

  chan.tail = 1

  release(chan.lock)
  signal(chan.dataAvailableCV)
  result = true

proc sendMpmc(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  assert not chan.isNil
  assert not data.isNil

  if isUnbuffered(chan):
    return sendUnbufferedMpmc(chan, data, size, blocking)

  when not blocking:
    if chan.isFull(): return false

  acquire(chan.lock)

  # check for when another thread was faster to fill
  when blocking:
    while chan.isFull():
      wait(chan.spaceAvailableCV, chan.lock)
  else:
    if chan.isFull():
      release(chan.lock)
      return false

  assert not chan.isFull()
  assert size <= chan.itemsize

  let writeIdx = if chan.head < chan.size:
      chan.head
    else:
      chan.head - chan.size

  copyMem(chan.buffer[writeIdx * chan.itemsize].addr, data, size)

  inc(chan.head)
  if chan.head == 2 * chan.size:
    chan.head = 0

  release(chan.lock)
  signal(chan.dataAvailableCV)
  result = true

proc recvUnbufferedMpmc(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  when not blocking:
    if chan.isEmptyUnbuf(): return false

  # for a buffer of size=1 only tail index is used
  acquire(chan.lock)

  # check for when another thread was faster to empty
  when blocking:
    while chan.isEmptyUnbuf():
      wait(chan.dataAvailableCV, chan.lock)
  else:
    if chan.isEmptyUnbuf():
      release(chan.lock)
      return false

  assert chan.isFullUnbuf()
  assert size <= chan.itemsize

  copyMem(data, chan.buffer, size)

  chan.tail = 0
  assert chan.isEmptyUnbuf()

  release(chan.lock)
  signal(chan.spaceAvailableCV)
  result = true

proc recvMpmc(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  assert not chan.isNil
  assert not data.isNil

  if isUnbuffered(chan):
    return recvUnbufferedMpmc(chan, data, size, blocking)

  when not blocking:
    if chan.isEmpty(): return false

  acquire(chan.lock)

  # check for when another thread was faster to empty
  when blocking:
    while chan.isEmpty():
      wait(chan.dataAvailableCV, chan.lock)
  else:
    if chan.isEmpty():
      release(chan.lock)
      return false

  assert not chan.isEmpty()
  assert size <= chan.itemsize

  let readIdx = if chan.tail < chan.size:
      chan.tail
    else:
      chan.tail - chan.size

  copyMem(data, chan.buffer[readIdx * chan.itemsize].addr, size)

  inc(chan.tail)
  if chan.tail == 2 * chan.size:
    chan.tail = 0

  release(chan.lock)
  signal(chan.spaceAvailableCV)
  result = true


# Public API
# ------------------------------------------------------------------------------

type
  Chan*[T] = object ## Typed channels
    d: ChannelRaw

proc `=destroy`*[T](c: var Chan[T]) =
  if c.d != nil:
    if load(c.d.atomicCounter, moAcquire) == 0:
      if c.d.buffer != nil:
        freeChannel(c.d)
    else:
      atomicDec(c.d.atomicCounter)

proc `=copy`*[T](dest: var Chan[T], src: Chan[T]) =
  ## Shares `Channel` by reference counting.
  if src.d != nil:
    atomicInc(src.d.atomicCounter)

  if dest.d != nil:
    `=destroy`(dest)
  dest.d = src.d

proc channelSend[T](chan: Chan[T], data: T, size: int, blocking: static bool): bool {.inline.} =
  ## Send item to the channel (FIFO queue)
  ## (Insert at last)
  sendMpmc(chan.d, data.unsafeAddr, size, blocking)

proc channelReceive[T](chan: Chan[T], data: ptr T, size: int, blocking: static bool): bool {.inline.} =
  ## Receive an item from the channel
  ## (Remove the first item)
  recvMpmc(chan.d, data, size, blocking)

proc trySend*[T](c: Chan[T], src: sink Isolated[T]): bool {.inline.} =
  ## Sends item to the channel (non blocking).
  var data = src.extract
  result = channelSend(c, data, sizeof(data), false)
  if result:
    wasMoved(data)

template trySend*[T](c: Chan[T], src: T): bool =
  ## Helper templates for `trySend`.
  trySend(c, isolate(src))

proc tryRecv*[T](c: Chan[T], dst: var T): bool {.inline.} =
  ## Receives item from the channel (non blocking).
  channelReceive(c, dst.addr, sizeof(dst), false)

proc send*[T](c: Chan[T], src: sink Isolated[T]) {.inline.} =
  ## Sends item to the channel (blocking).
  var data = src.extract
  when defined(gcOrc) and defined(nimSafeOrcSend):
    GC_runOrc()
  discard channelSend(c, data, sizeof(data), true)
  wasMoved(data)

template send*[T](c: Chan[T]; src: T) =
  ## Helper templates for `send`.
  send(c, isolate(src))

proc recv*[T](c: Chan[T], dst: var T) {.inline.} =
  ## Receives item from the channel (blocking).
  discard channelReceive(c, dst.addr, sizeof(dst), true)

proc recv*[T](c: Chan[T]): T {.inline.} =
  ## Receives item from the channel (blocking).
  discard channelReceive(c, result.addr, sizeof(result), true)

proc recvIso*[T](c: Chan[T]): Isolated[T] {.inline.} =
  var dst: T
  discard channelReceive(c, dst.addr, sizeof(dst), true)
  result = isolate(dst)

when false:
  proc open*[T](c: Chan[T]) {.inline.} =
    store(c.d.closed, false, moRelaxed)

  proc close*[T](c: Chan[T]) {.inline.} =
    store(c.d.closed, true, moRelaxed)

proc peek*[T](c: Chan[T]): int {.inline.} = peek(c.d)

proc newChan*[T](elements: Positive = 30): Chan[T] =
  assert elements >= 1, "Elements must be positive!"
  result = Chan[T](d: allocChannel(sizeof(T), elements))
