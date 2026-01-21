import threading/channels
import std/unittest

const
  BufferSize = 3

suite "Ring Buffer Channel Tests":
  test "Non-blocking ring buffer behavior":
    
    proc fillBuffer(n: int): seq[int] =
      var chan = newChan[int](BufferSize)
      # Fill the buffer
      for i in 0..<BufferSize+n:
        chan.push(i)
      
      # Receive values - should get BufferSize as first value
      var values: seq[int]
      for i in 0..<BufferSize:
        var x: int
        if not chan.tryRecv(x):
          break
        values.add(x)
      
      # Verify we got the most recent values
      result = values
    
    check fillBuffer(0) == @[0, 1, 2]
    check fillBuffer(1) == @[1, 2, 3]
    check fillBuffer(2) == @[2, 3, 4]
    check fillBuffer(3) == @[3, 4, 5]
    check fillBuffer(4) == @[4, 5, 6]
    check fillBuffer(5) == @[5, 6, 7]
    check fillBuffer(6) == @[6, 7, 8]
    check fillBuffer(7) == @[7, 8, 9]
    check fillBuffer(8) == @[8, 9, 10]

  test "Non-blocking ring buffer behavior with size 1":
    var chan = newChan[int](1)
    chan.push(1)
    chan.push(2)
    var x: int
    check chan.tryRecv(x)
    check x == 2
