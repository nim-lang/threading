discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""
import std/[os, osproc], threading/channels

const
  NTasks = 256'i16 # int16 allows using this in a Set
  SleepDurationMS = 3
  sentmsg = "task sent"

type
  Payload = tuple[sender: Sender[int16], idx: int16]

var
  sentmessages = newSeqOfCap[string](NTasks)
  receivedmessages = newSeqOfCap[int16](NTasks)

# A prototype of a task executing thread
proc runner(tasksCh: Receiver[Payload]) {.thread.} =
  var p: Payload
  while true:
    discard tasksCh.recv(p) # Get a message from the main thread
    if p.idx == -1: break # Check for an ad hoc stop signal
    else:
      sleep(SleepDurationMS) # Hard work
      discard p.sender.send(p.idx) # Notify a consumer

# A single thread receiving result from runner threads
proc consumer(args: tuple[resultsCh: Receiver[int16], tasks: int16]) {.thread.} =
  var idx: int16
  for _ in 0..<args.tasks: # We know the number of tasks and wait for them all
    discard args.resultsCh.recv(idx)
    {.gcsafe.}: # Don't do this. Here we know it's an exclusive access
      receivedmessages.add(idx) # Store which task was completed

proc main(chanSize: Natural) =
  sentmessages.setLen(0)
  receivedmessages.setLen(0)
  var
    taskThreads = newSeq[Thread[Receiver[Payload]]](countProcessors())
    consumerTh: Thread[tuple[resultsCh: Receiver[int16], tasks: int16]]
  let
    (tasksSender, tasksReceiver) = newChan[Payload](chanSize)
    (resultsSender, resultsReceiver) = newChan[int16](chanSize)

  # Consumer must be ready first to not block
  createThread(consumerTh, consumer, (resultsReceiver, NTasks))
  # Start runner threads
  for i in 0..high(taskThreads): createThread(taskThreads[i], runner, tasksReceiver)
  # Loop iterating fake data
  for idx in 0'i16..<NTasks:
    discard tasksSender.send((resultsSender, idx))
    sentmessages.add(sentmsg)

  for _ in taskThreads: # Stopping worker threads
    discard tasksSender.send((resultsSender, -1'i16)) # A thread can't get more than 1 stop signal
  joinThreads(taskThreads)
  joinThread(consumerTh)

#------------------------------------------------------------------------------

template runTests(bufferSize: Positive) =
  main(bufferSize)

  doAssert sentmessages.len == NTasks
  doAssert receivedmessages.len == Ntasks
  doAssert sentmessages[^1] == sentmsg

  var set = {0..NTasks-1}
  for i in receivedmessages: set.excl(i)
  doAssert set == {}


block buffered_channels:
  runTests(bufferSize = 2)

block unbuffered_channels:
  runTests(bufferSize = 1)
