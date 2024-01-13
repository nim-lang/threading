import threading/smartptrs

block:
  var a1: UniquePtr[int]
  var a2 = newUniquePtr(0)

  doAssert $a1 == "nil"
  doAssert a1.isNil
  doAssert $a2 == "(val: 0)"
  doAssert not a2.isNil
  doAssert a2[] == 0

  # UniquePtr can't be copied but can be moved
  let a3 = move a2

  doAssert $a2 == "nil"
  doAssert a2.isNil

  doAssert $a3 == "(val: 0)"
  doAssert not a3.isNil
  doAssert a3[] == 0

  a1 = newUniquePtr(int)
  a1[] = 1
  doAssert a1[] == 1
  var a4 = newUniquePtr(string)
  a4[] = "hello world"
  doAssert a4[] == "hello world"

block:
  var a1: SharedPtr[int]
  let a2 = newSharedPtr(0)
  let a3 = a2

  doAssert $a1 == "nil"
  doAssert a1.isNil
  doAssert $a2 == "(val: 0)"
  doAssert not a2.isNil
  doAssert a2[] == 0
  doAssert $a3 == "(val: 0)"
  doAssert not a3.isNil
  doAssert a3[] == 0

  a1 = newSharedPtr(int)
  a1[] = 1
  doAssert a1[] == 1
  var a4 = newSharedPtr(string)
  a4[] = "hello world"
  doAssert a4[] == "hello world"

block:
  var a1: ConstPtr[float]
  let a2 = newConstPtr(0)
  let a3 = a2

  doAssert $a1 == "nil"
  doAssert a1.isNil
  doAssert $a2 == "(val: 0)"
  doAssert not a2.isNil
  doAssert a2[] == 0
  doAssert $a3 == "(val: 0)"
  doAssert not a3.isNil
  doAssert a3[] == 0
