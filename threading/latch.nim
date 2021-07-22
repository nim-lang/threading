#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Antonis Geralis
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
import std/locks

{.push stackTrace: off.}

type
  Latch* = object
    c: Cond
    L: Lock
    counter: int

proc `=destroy`*(x: var Latch) =
  deinitCond(x.c)
  deinitLock(x.L)

proc `=sink`*(dest: var Latch; source: Latch) {.error.}
proc `=copy`*(dest: var Latch; source: Latch) {.error.}

proc init*(x: var Latch, count: Natural) =
  x.counter = count
  initCond(x.c)
  initLock(x.L)

proc dec*(x: var Latch) =
  acquire(x.L)
  if x.counter > 0:
    dec x.counter
    if x.counter == 0:
      broadcast(x.c)
  release(x.L)

proc wait*(x: var Latch) =
  acquire(x.L)
  while x.counter > 0:
    wait(x.c, x.L)
  release(x.L)

{.pop.}
