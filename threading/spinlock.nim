import atomics

{.push stackTrace: off.}

type
  SpinLock* = object
    lock: Atomic[bool]

proc `=sink`*(dest: var SpinLock; source: SpinLock) {.error.}
proc `=copy`*(dest: var SpinLock; source: SpinLock) {.error.}

proc acquire*(s: var SpinLock) =
  while true:
    if not s.lock.exchange(true, Acquire):
      return
    else:
      while s.lock.load(Relaxed): cpuRelax()

proc tryAcquire*(s: var SpinLock): bool =
  result = not s.lock.load(Relaxed) and
      not s.lock.exchange(true, Acquire)

proc release*(s: var SpinLock) =
  s.lock.store(false, Release)

template withLock*(a: SpinLock, body: untyped) =
  acquire(a)
  {.locks: [a].}:
    try:
      body
    finally:
      release(a)

{.pop.}
