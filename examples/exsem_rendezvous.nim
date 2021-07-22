import std/os, threading/semaphore

const
  N = 2

var
  aThread, bThread: Thread[void]
  aArrived, bArrived: Semaphore

proc a =
  echo "A starts"
  signal aArrived
  wait bArrived
  sleep(1000)
  echo "A progresses"

proc b =
  echo "B starts"
  signal bArrived
  wait aArrived
  sleep(2000)
  echo "B progresses"

proc main =
  #randomize()
  init aArrived
  init bArrived

  createThread(aThread, b)
  createThread(bThread, a)
  joinThread(aThread)
  joinThread(bThread)

main()
