#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Antonis Geralis
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
import std/locks, atomics

{.push stackTrace: off.}

type
  Once* = object
    L: Lock
    finished: Atomic[bool]

proc `=destroy`*(o: var Once) =
  deinitLock(o.L)

proc `=sink`*(dest: var Once; source: Once) {.error.}
proc `=copy`*(dest: var Once; source: Once) {.error.}

proc init*(o: var Once) =
  bool(o.finished) = false
  initLock(o.L)

template once*(o: Once, body: untyped) =
  if not o.finished.load(Acquire):
    acquire(o.L)
    try:
      if not bool(o.finished):
        try:
          body
        finally:
          o.finished.store(true, Release)
    finally:
      release(o.L)

{.pop.}
