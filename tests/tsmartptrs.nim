import sync/smartptrs

block:
  var a1: UniquePtr[int]
  var a2 = newUniquePtr(0)

  assert $a1 == "nil"
  assert a1.isNil
  assert $a2 == "(val: 0)"
  assert not a2.isNil
  assert a2[] == 0

  # UniquePtr can't be copied but can be moved
  let a3 = move a2

  assert $a2 == "nil"
  assert a2.isNil

  assert $a3 == "(val: 0)"
  assert not a3.isNil
  assert a3[] == 0

  a1 = newUniquePtr(int)
  a1[] = 1
  assert a1[] == 1
  var a4 = newUniquePtr(string)
  a4[] = "hello world"
  assert a4[] == "hello world"

block:
  var a1: SharedPtr[int]
  let a2 = newSharedPtr(0)
  let a3 = a2

  assert $a1 == "nil"
  assert a1.isNil
  assert $a2 == "(val: 0)"
  assert not a2.isNil
  assert a2[] == 0
  assert $a3 == "(val: 0)"
  assert not a3.isNil
  assert a3[] == 0

  a1 = newSharedPtr(int)
  a1[] = 1
  assert a1[] == 1
  var a4 = newSharedPtr(string)
  a4[] = "hello world"
  assert a4[] == "hello world"

block:
  var a1: ConstPtr[float]
  let a2 = newConstPtr(0)
  let a3 = a2

  assert $a1 == "nil"
  assert a1.isNil
  assert $a2 == "(val: 0)"
  assert not a2.isNil
  assert a2[] == 0
  assert $a3 == "(val: 0)"
  assert not a3.isNil
  assert a3[] == 0
