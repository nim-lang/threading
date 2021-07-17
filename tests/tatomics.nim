import std/bitops, sync/atomics2
# Atomic operations for trivial objects

block trivialLoad:
  var location: Atomic[int]
  location.store(1)
  assert location.load == 1
  location.store(2)
  assert location.load(Relaxed) == 2
  location.store(3)
  assert location.load(Acquire) == 3

block trivialStore:
  var location: Atomic[int]
  location.store(1)
  assert location.load == 1
  location.store(2, Relaxed)
  assert location.load == 2
  location.store(3, Release)
  assert location.load == 3

block trivialExchange:
  var location: Atomic[int]
  location.store(1)
  assert location.exchange(2) == 1
  assert location.exchange(3, Relaxed) == 2
  assert location.exchange(4, Acquire) == 3
  assert location.exchange(5, Release) == 4
  assert location.exchange(6, AcqRel) == 5
  assert location.load == 6

block trivialCompareExchangeDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  assert location.compareExchange(expected, 2)
  assert expected == 1
  assert location.load == 2
  expected = 2
  assert location.compareExchange(expected, 3, Relaxed)
  assert expected == 2
  assert location.load == 3
  expected = 3
  assert location.compareExchange(expected, 4, Acquire)
  assert expected == 3
  assert location.load == 4
  expected = 4
  assert location.compareExchange(expected, 5, Release)
  assert expected == 4
  assert location.load == 5
  expected = 5
  assert location.compareExchange(expected, 6, AcqRel)
  assert expected == 5
  assert location.load == 6

block trivialCompareExchangeDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  assert not location.compareExchange(expected, 2)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 3, Relaxed)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 4, Acquire)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 5, Release)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 6, AcqRel)
  assert expected == 1
  assert location.load == 1

block trivialCompareExchangeSuccessFailureDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  assert location.compareExchange(expected, 2, SeqCst, SeqCst)
  assert expected == 1
  assert location.load == 2
  expected = 2
  assert location.compareExchange(expected, 3, Relaxed, Relaxed)
  assert expected == 2
  assert location.load == 3
  expected = 3
  assert location.compareExchange(expected, 4, Acquire, Acquire)
  assert expected == 3
  assert location.load == 4
  expected = 4
  assert location.compareExchange(expected, 5, Release, Release)
  assert expected == 4
  assert location.load == 5
  expected = 5
  assert location.compareExchange(expected, 6, AcqRel, AcqRel)
  assert expected == 5
  assert location.load == 6

block trivialCompareExchangeSuccessFailureDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  assert not location.compareExchange(expected, 2, SeqCst, SeqCst)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 3, Relaxed, Relaxed)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 4, Acquire, Acquire)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 5, Release, Release)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchange(expected, 6, AcqRel, AcqRel)
  assert expected == 1
  assert location.load == 1

block trivialCompareExchangeWeakDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  assert location.compareExchangeWeak(expected, 2)
  assert expected == 1
  assert location.load == 2
  expected = 2
  assert location.compareExchangeWeak(expected, 3, Relaxed)
  assert expected == 2
  assert location.load == 3
  expected = 3
  assert location.compareExchangeWeak(expected, 4, Acquire)
  assert expected == 3
  assert location.load == 4
  expected = 4
  assert location.compareExchangeWeak(expected, 5, Release)
  assert expected == 4
  assert location.load == 5
  expected = 5
  assert location.compareExchangeWeak(expected, 6, AcqRel)
  assert expected == 5
  assert location.load == 6

block trivialCompareExchangeWeakDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  assert not location.compareExchangeWeak(expected, 2)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 3, Relaxed)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 4, Acquire)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 5, Release)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 6, AcqRel)
  assert expected == 1
  assert location.load == 1

block trivialCompareExchangeWeakSuccessFailureDoesExchange:
  var location: Atomic[int]
  var expected = 1
  location.store(1)
  assert location.compareExchangeWeak(expected, 2, SeqCst, SeqCst)
  assert expected == 1
  assert location.load == 2
  expected = 2
  assert location.compareExchangeWeak(expected, 3, Relaxed, Relaxed)
  assert expected == 2
  assert location.load == 3
  expected = 3
  assert location.compareExchangeWeak(expected, 4, Acquire, Acquire)
  assert expected == 3
  assert location.load == 4
  expected = 4
  assert location.compareExchangeWeak(expected, 5, Release, Release)
  assert expected == 4
  assert location.load == 5
  expected = 5
  assert location.compareExchangeWeak(expected, 6, AcqRel, AcqRel)
  assert expected == 5
  assert location.load == 6

block trivialCompareExchangeWeakSuccessFailureDoesNotExchange:
  var location: Atomic[int]
  var expected = 10
  location.store(1)
  assert not location.compareExchangeWeak(expected, 2, SeqCst, SeqCst)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 3, Relaxed, Relaxed)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 4, Acquire, Acquire)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 5, Release, Release)
  assert expected == 1
  assert location.load == 1
  expected = 10
  assert not location.compareExchangeWeak(expected, 6, AcqRel, AcqRel)
  assert expected == 1
  assert location.load == 1

# Numerical operations

block fetchAdd:
  var location: Atomic[int]
  assert location.fetchAdd(1) == 0
  assert location.fetchAdd(1, Relaxed) == 1
  assert location.fetchAdd(1, Release) == 2
  assert location.load == 3

block fetchSub:
  var location: Atomic[int]
  assert location.fetchSub(1) == 0
  assert location.fetchSub(1, Relaxed) == -1
  assert location.fetchSub(1, Release) == -2
  assert location.load == -3

block fetchAnd:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchAnd(j) == i)
      assert(location.load == i.bitand(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchAnd(j, Relaxed) == i)
      assert(location.load == i.bitand(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchAnd(j, Release) == i)
      assert(location.load == i.bitand(j))

block fetchOr:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchOr(j) == i)
      assert(location.load == i.bitor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchOr(j, Relaxed) == i)
      assert(location.load == i.bitor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchOr(j, Release) == i)
      assert(location.load == i.bitor(j))

block fetchXor:
  var location: Atomic[int]

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchXor(j) == i)
      assert(location.load == i.bitxor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchXor(j, Relaxed) == i)
      assert(location.load == i.bitxor(j))

  for i in 0..16:
    for j in 0..16:
      location.store(i)
      assert(location.fetchXor(j, Release) == i)
      assert(location.load == i.bitxor(j))

block atomicInc:
  var location: Atomic[int]
  location.atomicInc
  assert location.load == 1
  location.atomicInc(1)
  assert location.load == 2
  location += 1
  assert location.load == 3

block atomicDec:
  var location: Atomic[int]
  location.atomicDec
  assert location.load == -1
  location.atomicDec(1)
  assert location.load == -2
  location -= 1
  assert location.load == -3
