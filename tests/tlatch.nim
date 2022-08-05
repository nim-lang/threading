import threading/latch

var
  L: Latch

# test zero count latch
proc test =
  init L, 0
  # wait should not block
  wait(L)
  # decrement should have no effect
  dec(L)
  dec(L)
  # wait should not block
  wait(L)

test()
