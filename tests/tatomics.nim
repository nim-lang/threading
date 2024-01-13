import std/bitops, threading/atomics
# Atomic operations for trivial objects

block trivialLoad:
  var location: Atomic[int]
  location.store(1)
  doAssert location.load == 1
  location.store(2)
  doAssert location.load(Relaxed) == 2
  location.store(3)
  doAssert location.load(Acquire) == 3

block trivialStore:
  var location: Atomic[int]
  location.store(1)
  doAssert location.load == 1
  location.store(2, Relaxed)
  doAssert location.load == 2
  location.store(3, Release)
  doAssert location.load == 3

block trivialExchange:
  var location: Atomic[int]
  location.store(1)
  doAssert location.exchange(2) == 1
  doAssert location.exchange(3, Relaxed) == 2
  doAssert location.exchange(4, Acquire) == 3
  doAssert location.exchange(5, Release) == 4
  doAssert location.exchange(6, AcqRel) == 5
  doAssert location.load == 6

block trivialCompareExchangeDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  doAssert location.compareExchange(expected, 2)
  doAssert expected == 1
  doAssert location.load == 2
  expected = 2
  doAssert location.compareExchange(expected, 3, Relaxed)
  doAssert expected == 2
  doAssert location.load == 3
  expected = 3
  doAssert location.compareExchange(expected, 4, Acquire)
  doAssert expected == 3
  doAssert location.load == 4
  expected = 4
  doAssert location.compareExchange(expected, 5, Release)
  doAssert expected == 4
  doAssert location.load == 5
  expected = 5
  doAssert location.compareExchange(expected, 6, AcqRel)
  doAssert expected == 5
  doAssert location.load == 6

block trivialCompareExchangeDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  doAssert not location.compareExchange(expected, 2)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 3, Relaxed)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 4, Acquire)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 5, Release)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 6, AcqRel)
  doAssert expected == 1
  doAssert location.load == 1

block trivialCompareExchangeSuccessFailureDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  doAssert location.compareExchange(expected, 2, SeqCst, SeqCst)
  doAssert expected == 1
  doAssert location.load == 2
  expected = 2
  doAssert location.compareExchange(expected, 3, Relaxed, Relaxed)
  doAssert expected == 2
  doAssert location.load == 3
  expected = 3
  doAssert location.compareExchange(expected, 4, Acquire, Acquire)
  doAssert expected == 3
  doAssert location.load == 4
  expected = 4
  doAssert location.compareExchange(expected, 5, Release, Release)
  doAssert expected == 4
  doAssert location.load == 5
  expected = 5
  doAssert location.compareExchange(expected, 6, AcqRel, AcqRel)
  doAssert expected == 5
  doAssert location.load == 6

block trivialCompareExchangeSuccessFailureDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  doAssert not location.compareExchange(expected, 2, SeqCst, SeqCst)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 3, Relaxed, Relaxed)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 4, Acquire, Acquire)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 5, Release, Release)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchange(expected, 6, AcqRel, AcqRel)
  doAssert expected == 1
  doAssert location.load == 1

block trivialCompareExchangeWeakDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  doAssert location.compareExchangeWeak(expected, 2)
  doAssert expected == 1
  doAssert location.load == 2
  expected = 2
  doAssert location.compareExchangeWeak(expected, 3, Relaxed)
  doAssert expected == 2
  doAssert location.load == 3
  expected = 3
  doAssert location.compareExchangeWeak(expected, 4, Acquire)
  doAssert expected == 3
  doAssert location.load == 4
  expected = 4
  doAssert location.compareExchangeWeak(expected, 5, Release)
  doAssert expected == 4
  doAssert location.load == 5
  expected = 5
  doAssert location.compareExchangeWeak(expected, 6, AcqRel)
  doAssert expected == 5
  doAssert location.load == 6

block trivialCompareExchangeWeakDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  doAssert not location.compareExchangeWeak(expected, 2)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 3, Relaxed)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 4, Acquire)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 5, Release)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 6, AcqRel)
  doAssert expected == 1
  doAssert location.load == 1

block trivialCompareExchangeWeakSuccessFailureDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  doAssert location.compareExchangeWeak(expected, 2, SeqCst, SeqCst)
  doAssert expected == 1
  doAssert location.load == 2
  expected = 2
  doAssert location.compareExchangeWeak(expected, 3, Relaxed, Relaxed)
  doAssert expected == 2
  doAssert location.load == 3
  expected = 3
  doAssert location.compareExchangeWeak(expected, 4, Acquire, Acquire)
  doAssert expected == 3
  doAssert location.load == 4
  expected = 4
  doAssert location.compareExchangeWeak(expected, 5, Release, Release)
  doAssert expected == 4
  doAssert location.load == 5
  expected = 5
  doAssert location.compareExchangeWeak(expected, 6, AcqRel, AcqRel)
  doAssert expected == 5
  doAssert location.load == 6

block trivialCompareExchangeWeakSuccessFailureDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  doAssert not location.compareExchangeWeak(expected, 2, SeqCst, SeqCst)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 3, Relaxed, Relaxed)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 4, Acquire, Acquire)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 5, Release, Release)
  doAssert expected == 1
  doAssert location.load == 1
  expected = 10
  doAssert not location.compareExchangeWeak(expected, 6, AcqRel, AcqRel)
  doAssert expected == 1
  doAssert location.load == 1

# Numerical operations

block fetchAdd:
  var location: Atomic[int]
  doAssert location.fetchAdd(1) == 0
  doAssert location.fetchAdd(1, Relaxed) == 1
  doAssert location.fetchAdd(1, Release) == 2
  doAssert location.load == 3

block fetchSub:
  var location: Atomic[int]
  doAssert location.fetchSub(1) == 0
  doAssert location.fetchSub(1, Relaxed) == -1
  doAssert location.fetchSub(1, Release) == -2
  doAssert location.load == -3

block fetchAnd:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchAnd(j) == i)
      doAssert(location.load == i.bitand(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchAnd(j, Relaxed) == i)
      doAssert(location.load == i.bitand(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchAnd(j, Release) == i)
      doAssert(location.load == i.bitand(j))

block fetchOr:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchOr(j) == i)
      doAssert(location.load == i.bitor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchOr(j, Relaxed) == i)
      doAssert(location.load == i.bitor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchOr(j, Release) == i)
      doAssert(location.load == i.bitor(j))

block fetchXor:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchXor(j) == i)
      doAssert(location.load == i.bitxor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchXor(j, Relaxed) == i)
      doAssert(location.load == i.bitxor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      doAssert(location.fetchXor(j, Release) == i)
      doAssert(location.load == i.bitxor(j))

block atomicInc:
  var location: Atomic[int]
  location.atomicInc
  doAssert location.load == 1
  location.atomicInc(1)
  doAssert location.load == 2
  location += 1
  doAssert location.load == 3

block atomicDec:
  var location: Atomic[int]
  location.atomicDec
  doAssert location.load == -1
  location.atomicDec(1)
  doAssert location.load == -2
  location -= 1
  doAssert location.load == -3
