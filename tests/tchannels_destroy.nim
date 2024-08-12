discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd"
"""

import threading/channels, std/os

type
  WorkRequest = ref object
    id: int

var
  chanIn: Chan[WorkRequest]
  thread: Thread[Chan[WorkRequest]]

proc workThread(chanIn: Chan[WorkRequest]) {.thread.} =
  echo "Started work thread"
  var req: WorkRequest
  chanIn.recv(req)
  echo "Got work ", req.id

proc main =
  chanIn = newChan[WorkRequest]()
  createThread(thread, workThread, chanIn)

  chanIn.send(WorkRequest(id: 1))

  sleep(100) # Give thread time to run
  # joinThread(thread)

main()
