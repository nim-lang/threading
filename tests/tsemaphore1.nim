import threading/semaphore

var
  semS, semT = createSemaphore()
  aArrived, cArrived = false
  thread: Thread[void]

proc routine =
  # Section C
  cArrived = true
  signal semT
  wait semS
  # Section D
  assert aArrived, "Constraint: Section A precedes D"

proc testRendezvous =
  createThread(thread, routine)
  # Section A
  aArrived = true
  signal semS
  wait semT
  # Section B
  assert cArrived, "Constraint: Section C precedes B"
  joinThread thread

testRendezvous()
