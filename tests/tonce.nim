import threading/once

var o = createOnce()
proc smokeOnce() =
  var a = 0
  o.once(a += 1)
  assert a == 1
  o.once(a += 1)
  assert a == 1

smokeOnce()
