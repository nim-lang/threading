import threading/[once, atomics]

var o: Once
proc smokeOnce() =
  init o
  var a = 0
  o.once(a += 1)
  assert a == 1
  o.once(a += 1)
  assert a == 1

smokeOnce()
