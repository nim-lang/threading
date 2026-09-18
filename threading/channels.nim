#
#
#                                    Nim's Runtime Library
#        (c) Copyright 2021 Andreas Prell, Mamy André-Ratsimbazafy & Nim Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
# This Channel implementation is a shared memory, fixed-size, concurrent queue using
# a circular buffer for data. Based on channels implementation[1]_ by
# Mamy André-Ratsimbazafy (@mratsim), which is a C to Nim translation of the
# original[2]_ by Andreas Prell (@aprell)
#
# .. [1] https://github.com/mratsim/weave/blob/5696d94e6358711e840f8c0b7c684fcc5cbd4472/unused/channels/channels_legacy.nim
# .. [2] https://github.com/aprell/tasking-2.0/blob/master/src/channel_shm/channel.c

## This module works only with one of `--mm:arc` / `--mm:atomicArc` / `--mm:orc`
## compilation flags.
##
## .. warning:: This module is experimental and its interface may change.
##
## This module implements multi-producer multi-consumer bounded channels - a
## concurrency primitive with a high-level interface intended for communication
## and synchronization between threads. It allows sending and receiving typed, isolated
## data, enabling safe and efficient concurrency.
##
## A channel is created as a pair of a `Sender` and a `Receiver` using the
## `newChan` proc.
##
## Both are reference-counted handles to the same underlying fixed-size
## channel, and they can be copied and shared between threads.
##
## Sending operations are provided by the blocking `send` proc and the
## non-blocking `trySend` and `tryTake` procs on the `Sender`.
##
## Receiving operations are provided by the blocking `recv` proc and the
## non-blocking `tryRecv` proc on the `Receiver`.
##
## When the last `Sender` is destroyed, the channel is closed for sending:
## `Receiver`s drain any messages still in the queue and then start receiving
## `default(T)` values instead of sent messages.
##
## When the last `Receiver` is destroyed, the channel is closed for receiving:
## `send` calls on the remaining `Sender`s return `false` and blocked senders
## are woken up.
##
## The deprecated `Channel` API at the bottom of this module emulates
## the legacy single-handle channel on top of a `Sender`/`Receiver` pair.
##
## See also:
## * [std/isolation](https://nim-lang.org/docs/isolation.html)
##
## The following is a simple example of two different ways to use channels:
## blocking and non-blocking.

runnableExamples("--threads:on --gc:orc"):
  import std/os

  # In this example a channel pair is declared at module scope.
  # Channels are generic, and they include support for passing objects between
  # threads.
  # Note that isolated data passed through channels is moved around.
  var (sender, receiver) = newChan[string]()

  block example_blocking:
    # This proc will be run in another thread.
    proc basicWorker(s: Sender[string]) =
      discard s.send("Hello World!")

    # Launch the worker.
    var worker: Thread[Sender[string]]
    createThread(worker, basicWorker, sender)

    # Block until the message arrives, then print it out.
    var dest = ""
    discard receiver.recv(dest)
    assert dest == "Hello World!"

    # Wait for the thread to exit before moving on to the next example.
    worker.joinThread()

  block example_non_blocking:
    # This is another proc to run in a background thread. This proc takes a while
    # to send the message since it first sleeps for some time.
    proc slowWorker(args: tuple[s: Sender[string], d: Natural]) =
      # `args.d` is a delay period in milliseconds
      sleep(args.d)
      discard args.s.send("Another message")

    # Launch the worker with a delay set to 2 seconds (2000 ms).
    var worker: Thread[tuple[s: Sender[string], d: Natural]]
    createThread(worker, slowWorker, (sender, 2000.Natural))

    # This time, use a non-blocking approach with tryRecv.
    # Since the main thread is not blocked, it could be used to perform other
    # useful work while it waits for data to arrive on the channel.
    var messages: seq[string]
    while true:
      var msg = ""
      if receiver.tryRecv(msg):
        messages.add msg # "Another message"
        break
      messages.add "Pretend I'm doing useful work..."
      # For this example, sleep in order not to flood the sequence with too many
      # "pretend" messages.
      sleep(400)

    # Wait for the second thread to exit before cleaning up the channel.
    worker.joinThread()

    # Thread exits right after receiving the message
    assert messages[^1] == "Another message"
    # At least one non-successful attempt to receive the message had to occur.
    assert messages.len >= 2

when not (defined(gcArc) or defined(gcOrc) or defined(gcAtomicArc) or defined(nimdoc)):
  {.error: "This module requires one of --mm:arc / --mm:atomicArc / --mm:orc compilation flags".}

import std/[locks, isolation, atomics]

# Channel
# ------------------------------------------------------------------------------

type
  ChannelRaw = ptr ChannelObj
  ChannelObj = object
    lock: Lock
    spaceAvailableCV, dataAvailableCV: Cond
    slots: int         ## Number of item slots in the buffer
    head: Atomic[int]  ## Write/enqueue/send index
    tail: Atomic[int]  ## Read/dequeue/receive index
    buffer: ptr UncheckedArray[byte]
    refCount: Atomic[int]  ## Total number of live Sender and Receiver handles
    senders: Atomic[int]   ## Number of live Sender handles
    receivers: Atomic[int] ## Number of live Receiver handles

# ------------------------------------------------------------------------------

proc getTail(chan: ChannelRaw, order: MemoryOrder = moRelaxed): int {.inline.} =
  chan.tail.load(order)

proc getHead(chan: ChannelRaw, order: MemoryOrder = moRelaxed): int {.inline.} =
  chan.head.load(order)

proc setTail(chan: ChannelRaw, value: int, order: MemoryOrder = moRelaxed) {.inline.} =
  chan.tail.store(value, order)

proc setHead(chan: ChannelRaw, value: int, order: MemoryOrder = moRelaxed) {.inline.} =
  chan.head.store(value, order)

proc numItems(chan: ChannelRaw): int {.inline.} =
  result = chan.getHead() - chan.getTail()
  if result < 0:
    inc(result, 2 * chan.slots)

  assert result <= chan.slots

template isFull(chan: ChannelRaw): bool =
  abs(chan.getHead() - chan.getTail()) == chan.slots

template isEmpty(chan: ChannelRaw): bool =
  chan.getHead() == chan.getTail()

template closedForSending(chan: ChannelRaw): bool =
  chan.senders.load(moRelaxed) == 0

template closedForReceiving(chan: ChannelRaw): bool =
  chan.receivers.load(moRelaxed) == 0

# Channels memory ops
# ------------------------------------------------------------------------------

proc allocChannel(size, n: int): ChannelRaw =
  result = cast[ChannelRaw](allocShared(sizeof(ChannelObj)))

  # To buffer n items, we allocate for n
  result.buffer = cast[ptr UncheckedArray[byte]](allocShared(n*size))

  initLock(result.lock)
  initCond(result.spaceAvailableCV)
  initCond(result.dataAvailableCV)

  result.slots = n
  result.setHead(0)
  result.setTail(0)
  result.refCount.store(0, moRelaxed)
  result.senders.store(0, moRelaxed)
  result.receivers.store(0, moRelaxed)

proc freeChannel(chan: ChannelRaw) =
  deinitLock(chan.lock)
  deinitCond(chan.spaceAvailableCV)
  deinitCond(chan.dataAvailableCV)

  deallocShared(chan)

proc freeSenders(chan: ChannelRaw) =
  acquire(chan.lock)
  broadcast(chan.dataAvailableCV)
  release(chan.lock)

proc freeReceivers[T](chan: ChannelRaw) =
  acquire(chan.lock)

  # Because there are no more readers, there will be no more sending and no more
  # reading - we can destroy the pending items and free the channel buffer
  if not chan.buffer.isNil:
    let n = chan.numItems()
    for k in 0..<n:
      # Destroy the items in the same order a reader would dequeue them:
      # starting at the tail (read) index, in FIFO order
      let slotIdx = (chan.getTail() + k) mod chan.slots
      `=destroy`(cast[ptr T](chan.buffer[slotIdx * sizeOf(T)].addr)[])

    deallocShared(chan.buffer)
    chan.buffer = nil

  broadcast(chan.spaceAvailableCV)
  release(chan.lock)

# MPMC Channels (Multi-Producer Multi-Consumer)
# ------------------------------------------------------------------------------

proc channelSend(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  assert not chan.isNil
  assert not data.isNil

  when not blocking:
    if chan.isFull() or chan.closedForReceiving(): return false

  acquire(chan.lock)

  # check for when another thread was faster to fill, or the channel was
  # closed for receiving in the meantime
  when blocking:
    while chan.isFull() and not chan.closedForReceiving():
      wait(chan.spaceAvailableCV, chan.lock)
  else:
    if chan.isFull():
      release(chan.lock)
      return false

  if chan.closedForReceiving():
    release(chan.lock)
    return false

  assert not chan.isFull()

  let writeIdx = if chan.getHead() < chan.slots:
      chan.getHead()
    else:
      chan.getHead() - chan.slots

  copyMem(chan.buffer[writeIdx * size].addr, data, size)
  atomicInc(chan.head)
  if chan.getHead() == 2 * chan.slots:
    chan.setHead(0)

  signal(chan.dataAvailableCV)
  release(chan.lock)
  result = true

proc channelReceive(chan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  assert not chan.isNil
  assert not data.isNil

  when not blocking:
    if chan.isEmpty(): return false

  acquire(chan.lock)

  # check for when another thread was faster to empty
  when blocking:
    # Wait for data to become available or for the channel to be closed
    # for sending
    while chan.isEmpty():
      if chan.closedForSending():
        release(chan.lock)
        return false
      wait(chan.dataAvailableCV, chan.lock)
  else:
    if chan.isEmpty():
      release(chan.lock)
      return false

  assert not chan.isEmpty()

  let readIdx = if chan.getTail() < chan.slots:
      chan.getTail()
    else:
      chan.getTail() - chan.slots

  copyMem(data, chan.buffer[readIdx * size].addr, size)

  atomicInc(chan.tail)
  if chan.getTail() == 2 * chan.slots:
    chan.setTail(0)

  signal(chan.spaceAvailableCV)
  release(chan.lock)
  result = true

# Public API
# ------------------------------------------------------------------------------

type
  Sender*[T] = object ## Sending half of a channel pair
    d: ChannelRaw
  Receiver*[T] = object ## Receiving half of a channel pair
    d: ChannelRaw

# Reference counting helpers
# ------------------------------------------------------------------------------

template decRefCount(d: ChannelRaw) =
  if d.refCount.fetchSub(1, moAcquireRelease) == 1:
    # This was the last sender/receiver overall - free the channel
    freeChannel(d)

template decRefSender(d: ChannelRaw) =
  if d != nil:
    if d.senders.fetchSub(1, moAcquireRelease) == 1:
      # This was the last sender but maybe not the last reference: broadcast to
      # wake up any receivers blocked on dataAvailableCV.
      freeSenders(d)

    # Decrement refCount last in case senders and receivers are racing to close
    # the channel
    d.decRefCount()

template decRefReceiver[T](d: ChannelRaw) =
  if d != nil:
    if d.receivers.fetchSub(1, moAcquireRelease) == 1:
      # This was the last receiver but maybe not the last reference: destroy the
      # pending items, free the buffer, and broadcast to wake up any senders
      # blocked on spaceAvailableCV.
      freeReceivers[T](d)

    # Decrement refCount last in case senders and receivers are racing to close
    # the channel
    d.decRefCount()

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](s: Sender[T]) =
    decRefSender(s.d)

  proc `=destroy`*[T](r: Receiver[T]) =
    decRefReceiver[T](r.d)

else:
  proc `=destroy`*[T](s: var Sender[T]) =
    decRefSender(s.d)

  proc `=destroy`*[T](r: var Receiver[T]) =
    decRefReceiver[T](r.d)

proc `=wasMoved`*[T](x: var Sender[T]) =
  x.d = nil

proc `=wasMoved`*[T](x: var Receiver[T]) =
  x.d = nil

proc `=dup`*[T](src: Sender[T]): Sender[T] =
  if src.d != nil:
    discard fetchAdd(src.d.refCount, 1, moRelaxed)
    discard fetchAdd(src.d.senders, 1, moRelaxed)
  result.d = src.d

proc `=dup`*[T](src: Receiver[T]): Receiver[T] =
  if src.d != nil:
    discard fetchAdd(src.d.refCount, 1, moRelaxed)
    discard fetchAdd(src.d.receivers, 1, moRelaxed)
  result.d = src.d

proc `=copy`*[T](dest: var Sender[T], src: Sender[T]) =
  ## Shares the channel by reference counting.
  if src.d != nil:
    discard fetchAdd(src.d.refCount, 1, moRelaxed)
    discard fetchAdd(src.d.senders, 1, moRelaxed)
  `=destroy`(dest)
  dest.d = src.d

proc `=copy`*[T](dest: var Receiver[T], src: Receiver[T]) =
  ## Shares the channel by reference counting.
  if src.d != nil:
    discard fetchAdd(src.d.refCount, 1, moRelaxed)
    discard fetchAdd(src.d.receivers, 1, moRelaxed)
  `=destroy`(dest)
  dest.d = src.d

# Sender operations
# ------------------------------------------------------------------------------

proc trySend*[T](s: Sender[T], src: sink Isolated[T]): bool {.inline.} =
  ## Tries to send the message `src` to the channel `s`.
  ##
  ## The memory of `src` will be moved if possible.
  ## Doesn't block waiting for space in the channel to become available.
  ## Instead returns after an attempt to send a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` if the message was not sent because the number of pending
  ## messages in the channel exceeded its capacity, or because the channel is
  ## closed for receiving (all receivers are gone).
  result = channelSend(s.d, src.addr, sizeof(T), false)
  if result:
    wasMoved(src)

template trySend*[T](s: Sender[T], src: T): bool =
  ## Helper template for `trySend <#trySend,Sender[T],sinkIsolated[T]>`_.
  ##
  ## .. warning:: For repeated sends of the same value, consider using the
  ##    `tryTake <#tryTake,Sender[T],Isolated[T]>`_ proc with a pre-isolated
  ##    value to avoid unnecessary copying.
  mixin isolate
  trySend(s, isolate(src))

proc tryTake*[T](s: Sender[T], src: var Isolated[T]): bool {.inline.} =
  ## Tries to send the message `src` to the channel `s`.
  ##
  ## The memory of `src` is moved directly. Be careful not to reuse `src` afterwards.
  ## This proc is suitable when `src` cannot be copied.
  ##
  ## Doesn't block waiting for space in the channel to become available.
  ## Instead returns after an attempt to send a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` if the message was not sent because the number of pending
  ## messages in the channel exceeded its capacity, or because the channel is
  ## closed for receiving (all receivers are gone).
  result = channelSend(s.d, src.addr, sizeof(T), false)
  if result:
    wasMoved(src)

proc send*[T](s: Sender[T], src: sink Isolated[T]): bool {.inline.} =
  ## Sends the message `src` to the channel `s`.
  ## This blocks the sending thread until `src` was successfully sent.
  ##
  ## The memory of `src` is moved, not copied, even if the send fails.
  ##
  ## If the channel is already full with messages this will block the thread until
  ## messages from the channel are removed.
  ##
  ## Returns `false` if the channel is closed for receiving (all receivers are
  ## gone) and the message was not sent.
  when defined(gcOrc) and defined(nimSafeOrcSend):
    GC_runOrc()
  result = channelSend(s.d, src.addr, sizeof(T), true)
  wasMoved(src)

template send*[T](s: Sender[T]; src: T): bool =
  ## Helper template for `send <#send,Sender[T],sinkIsolated[T]>`_.
  ##
  ## Returns `false` if the channel is closed for receiving (all receivers are
  ## gone) and the message was not sent.
  mixin isolate
  send(s, isolate(src))

proc closed*[T](s: Sender[T]): bool {.inline.} =
  ## Returns true if all receivers are gone and the channel is closed for
  ## receiving.
  ##
  ## Once the channel is closed in either direction, that direction cannot be
  ## reopened.
  s.d.closedForReceiving()


# Receiver operations
# ------------------------------------------------------------------------------

proc tryRecv*[T](r: Receiver[T], dst: var T): bool {.inline.} =
  ## Tries to receive a message from the channel `r` and fill `dst` with its value.
  ##
  ## Doesn't block waiting for messages in the channel to become available.
  ## Instead returns after an attempt to receive a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` and does not change `dst` if no message was received,
  ## including when the channel is closed and fully drained.
  channelReceive(r.d, dst.addr, sizeof(T), false)

proc recv*[T](r: Receiver[T], dst: var T): bool {.inline.} =
  ## Receives a message from the channel `r` and fill `dst` with its value.
  ##
  ## This blocks the receiving thread until a message was successfully received
  ## or the channel is closed for sending.
  ##
  ## If the channel does not contain any messages this will block the thread until
  ## a message gets sent to the channel.
  ##
  ## Returns `true` if a message was received. If the channel is closed for
  ## sending (all senders are gone) and fully drained, `dst` is filled with
  ## `default(T)` and `false` is returned.
  result = channelReceive(r.d, dst.addr, sizeof(T), true)
  if not result:
    dst = default(T)

proc recv*[T](r: Receiver[T]): T {.inline.} =
  ## Receives a message from the channel `r`.
  ## A version of `recv`_ that returns the message.
  ##
  ## If the channel is closed (all senders are gone) and fully drained,
  ## `default(T)` is returned.
  if not channelReceive(r.d, result.addr, sizeof(T), true):
    result = default(T)

proc recvIso*[T](r: Receiver[T]): Isolated[T] {.inline.} =
  ## Receives a message from the channel `r`.
  ## A version of `recv`_ that returns the message and isolates it.
  ##
  ## If the channel is closed (all senders are gone) and fully drained,
  ## `default(T)` is returned.
  if not channelReceive(r.d, result.addr, sizeof(T), true):
    result = isolate(default(T))

proc closed*[T](s: Receiver[T]): bool {.inline.} =
  ## Returns true if all senders are gone and the channel is closed for
  ## sending, and all messages that were sent have been received (the queue
  ## is fully drained).
  ##
  ## Once the channel is closed in either direction, that direction cannot be
  ## reopened.
  s.d.closedForSending() and s.d.isEmpty()

# Channel pair
# ------------------------------------------------------------------------------

type ChannelPair*[T] = tuple[sender: Sender[T], receiver: Receiver[T]]

proc newChan*[T](elements: Positive = 30): ChannelPair[T] =
  ## Creates a new channel: a pair of a `Sender` and a `Receiver` connected to
  ## the same underlying fixed-size channel.
  ##
  ## `elements` is the capacity of the channel and thus how many messages it can hold
  ## before it refuses to accept any further messages.
  ##
  ## When the last `Sender` is destroyed, the channel is closed for sending:
  ## `Receiver`s drain any messages still in the queue and then start receiving
  ## `default(T)` values instead of sent messages. Symmetrically, when the last
  ## `Receiver` is destroyed, the channel is closed for receiving: `send` calls
  ## on the remaining `Sender`s return `false` and blocked senders are woken up.
  let raw = allocChannel(sizeof(T), elements)
  raw.refCount.store(2, moRelaxed)
  raw.senders.store(1, moRelaxed)
  raw.receivers.store(1, moRelaxed)
  result = (Sender[T](d: raw), Receiver[T](d: raw))

# Legacy API (deprecated)
# ------------------------------------------------------------------------------

{.push warning[Deprecated]: false.}
type Channel*[T] {.deprecated.} = ChannelPair[T]

proc send*[T](c: Channel[T], src: sink Isolated[T]) {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `send`_ on the `sender` half of the channel instead.
  discard send(c.sender, src)

template send*[T](c: Channel[T]; src: T) {.deprecated.} =
  ## Deprecated in 0.3.0: use `send`_ on the `sender` half of the channel instead.
  mixin isolate
  discard c.sender.send(src)

proc trySend*[T](c: Channel[T], src: sink Isolated[T]): bool {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `trysend`_ on the `sender` half of the channel instead.
  trySend(c.sender, src)

template trySend*[T](c: Channel[T], src: T): bool {.deprecated.} =
  ## Deprecated in 0.3.0: use `trysend`_ on the `sender` half of the channel instead.
  mixin isolate
  trySend(c.sender, isolate(src))

proc tryTake*[T](c: Channel[T], src: var Isolated[T]): bool {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `trytake`_ on the `sender` half of the channel instead.
  c.sender.tryTake(src)

proc tryRecv*[T](c: Channel[T], dst: var T): bool {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `tryrecv`_ on the `receiver` half of the channel instead.
  c.receiver.tryRecv(dst)

proc recv*[T](c: Channel[T], dst: var T) {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `recv`_ on the `receiver` half of the channel instead.
  discard c.receiver.recv(dst)

proc recv*[T](c: Channel[T]): T {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `recv`_ on the `receiver` half of the channel instead.
  c.receiver.recv()

proc recvIso*[T](c: Channel[T]): Isolated[T] {.deprecated, inline.} =
  ## Deprecated in 0.3.0: use `recviso`_ on the `receiver` half of the channel instead.
  c.receiver.recvIso()

proc peek*[T](c: Channel[T]): int {.deprecated, inline.} =
  ## Deprecated in 0.3.0: no replacement
  c.sender.d.numItems()
{.pop.}
