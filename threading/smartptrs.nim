#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Nim contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

## C++11 like smart pointers. They always use the shared allocator.
import std/[isolation, atomics]
from typetraits import supportsCopyMem

proc raiseNilAccess() {.noinline.} =
  raise newException(NilAccessDefect, "dereferencing nil smart pointer")

template checkNotNil(p: typed) =
  when compileOption("boundChecks"):
    {.line.}:
      if p.isNil:
        raiseNilAccess()

# mimic deallocShared signature
type Deleter = proc(p: pointer) {.noconv, raises: [], gcsafe.}

type
  UniquePtr*[T] = object
    ## Non copyable pointer to a value of type `T` with exclusive ownership.
    val: ptr T
    memalloc: pointer
    deleter: Deleter

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](p: UniquePtr[T]) =
    if p.val != nil:
      `=destroy`(p.val[])
      p.deleter(p.memalloc)
else:
  proc `=destroy`*[T](p: var UniquePtr[T]) =
    if p.val != nil:
      `=destroy`(p.val[])
      p.deleter(p.memalloc)

proc `=dup`*[T](src: UniquePtr[T]): UniquePtr[T] {.error.}
  ## The dup operation is disallowed for `UniquePtr`, it
  ## can only be moved.

proc `=copy`*[T](dest: var UniquePtr[T], src: UniquePtr[T]) {.error.}
  ## The copy operation is disallowed for `UniquePtr`, it
  ## can only be moved.

proc newUniquePtr*[T](val: sink Isolated[T]): UniquePtr[T] {.nodestroy.} =
  ## Returns a unique pointer which has exclusive ownership of the value.
  result.val = cast[ptr T](allocShared(sizeof(T)))
  # thanks to '.nodestroy' we don't have to use allocShared0 here.
  # This is compiled into a copyMem operation, no need for a sink
  # here either.
  result.val[] = extract val
  # no destructor call for 'val: sink T' here either.
  result.memalloc = cast[pointer](result.val)
  result.deleter = deallocShared

template newUniquePtr*[T](val: T): UniquePtr[T] =
  newUniquePtr(isolate(val))

proc newUniquePtr*[T](t: typedesc[T]): UniquePtr[T] =
  ## Returns a unique pointer. It is not initialized,
  ## so reading from it before writing to it is undefined behaviour!
  when not supportsCopyMem(T):
    result.val = cast[ptr T](allocShared0(sizeof(T)))
  else:
    result.val = cast[ptr T](allocShared(sizeof(T)))
  result.memalloc = cast[pointer](result.val)
  result.deleter = deallocShared

proc wrapUniquePtr*[T](p: ptr T, memalloc: pointer, deleter: Deleter): UniquePtr[T] =
  ## Returns a unique pointer that wraps a raw pointer.
  ## On destruction calls deleter on memalloc.
  result.val = p
  result.memalloc = memalloc
  result.deleter = deleter

proc get*[T](p: UniquePtr[T]): ptr T {.inline.} =
  p.val

proc isNil*[T](p: UniquePtr[T]): bool {.inline.} =
  p.val == nil

proc `[]`*[T](p: UniquePtr[T]): var T {.inline.} =
  ## Returns a mutable view of the internal value of `p`.
  checkNotNil(p)
  p.val[]

proc `[]=`*[T](p: UniquePtr[T], val: sink Isolated[T]) {.inline.} =
  checkNotNil(p)
  p.val[] = extract val

template `[]=`*[T](p: UniquePtr[T]; val: T) =
  `[]=`(p, isolate(val))

proc `$`*[T](p: UniquePtr[T]): string {.inline.} =
  if p.val == nil: "nil"
  else: "(val: " & $p.val[] & ")"

#------------------------------------------------------------------------------

type
  SharedPtr*[T] = object
    ## Shared ownership reference counting pointer.
    val: ptr T
    ctx: ptr tuple[counter: Atomic[int], memalloc: pointer, deleter: Deleter]

template frees(p) =
  if p.ctx != nil:
    # this `fetchSub` returns current val then subs
    # so count == 0 means we're the last
    if p.ctx.counter.fetchSub(1, moAcquireRelease) == 0:
      if p.val != nil:
        `=destroy`(p.val[])
      p.ctx.deleter(p.ctx.memalloc)
      `=destroy`(p.ctx[])
      deallocShared(p.ctx)

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](p: SharedPtr[T]) =
    frees(p)
else:
  proc `=destroy`*[T](p: var SharedPtr[T]) =
    frees(p)

proc `=wasMoved`*[T](p: var SharedPtr[T]) =
  p.val = nil
  p.ctx = nil

proc `=dup`*[T](src: SharedPtr[T]): SharedPtr[T] =
  if src.ctx != nil:
    discard fetchAdd(src.ctx.counter, 1, moRelaxed)
  result.val = src.val
  result.ctx = src.ctx

proc `=copy`*[T](dest: var SharedPtr[T], src: SharedPtr[T]) =
  if src.ctx != nil:
    discard fetchAdd(src.ctx.counter, 1, moRelaxed)
  `=destroy`(dest)
  dest.val = src.val
  dest.ctx = src.ctx

proc newSharedPtr*[T](val: sink Isolated[T]): SharedPtr[T] {.nodestroy.} =
  ## Returns a shared pointer which shares
  ## ownership of the object by reference counting.
  result.val = cast[ptr T](allocShared(sizeof(T)))
  result.ctx = cast[typeof(result.ctx)](allocShared(sizeof(result.ctx[])))
  result.ctx.counter.store(0, moRelaxed)
  result.ctx.memalloc = result.val
  result.ctx.deleter = deallocShared
  result.val[] = extract val

template newSharedPtr*[T](val: T): SharedPtr[T] =
  newSharedPtr(isolate(val))

proc newSharedPtr*[T](t: typedesc[T]): SharedPtr[T] =
  ## Returns a shared pointer. It is not initialized,
  ## so reading from it before writing to it is undefined behaviour!
  when not supportsCopyMem(T):
    result.val = cast[ptr T](allocShared0(sizeof(T)))
  else:
    result.val = cast[ptr T](allocShared(sizeof(T)))
  result.ctx = cast[typeof(result.ctx)](allocShared(sizeof(result.ctx[])))
  result.ctx.counter.store(0, moRelaxed)
  result.ctx.memalloc = result.val
  result.ctx.deleter = deallocShared

proc wrapSharedPtr*[T](p: ptr T, memalloc: pointer, deleter: Deleter): SharedPtr[T] =
  ## Returns a shared pointer that wraps a raw pointer.
  ## On destruction calls deleter on memalloc.
  result.val = p
  result.ctx = cast[typeof(result.ctx)](allocShared(sizeof(result.ctx[])))
  result.ctx.counter.store(0, moRelaxed)
  result.ctx.memalloc = memalloc
  result.ctx.deleter = deleter

proc get*[T](p: SharedPtr[T]): ptr T {.inline.} =
  p.val

proc isNil*[T](p: SharedPtr[T]): bool {.inline.} =
  p.val == nil

proc `[]`*[T](p: SharedPtr[T]): var T {.inline.} =
  checkNotNil(p)
  p.val[]

proc `[]=`*[T](p: SharedPtr[T], val: sink Isolated[T]) {.inline.} =
  checkNotNil(p)
  p.val[] = extract val

template `[]=`*[T](p: SharedPtr[T]; val: T) =
  `[]=`(p, isolate(val))

proc isUniqueRef*[T](p: SharedPtr[T]): bool =
  if p.val == nil:
    return true
  p.val.counter.load(moAcquireRelease) == 0
  

proc `$`*[T](p: SharedPtr[T]): string {.inline.} =
  if p.val == nil: "nil"
  else: "(val: " & $p.val[] & ")"

#------------------------------------------------------------------------------

type
  ConstPtr*[T] = distinct SharedPtr[T]
    ## Distinct version of `SharedPtr[T]`, which doesn't allow mutating the underlying value.

proc newConstPtr*[T](val: sink Isolated[T]): ConstPtr[T] {.nodestroy, inline.} =
  ## Similar to `newSharedPtr<#newSharedPtr,T>`_, but the underlying value can't be mutated.
  ConstPtr[T](newSharedPtr(val))

template newConstPtr*[T](val: T): ConstPtr[T] =
  newConstPtr(isolate(val))

proc wrapConstPtr*[T](p: ptr T, memalloc: pointer, deleter: Deleter): ConstPtr[T] {.inline.} =
  ## Returns a const pointer that wraps a raw pointer.
  ## On destruction calls deleter on memalloc.
  ConstPtr[T](wrapSharedPtr(p, memalloc, deleter))

proc get*[T](p: ConstPtr[T]): ptr T {.inline.} =
  return p.val

proc isNil*[T](p: ConstPtr[T]): bool {.inline.} =
  SharedPtr[T](p).val == nil

proc `[]`*[T](p: ConstPtr[T]): lent T {.inline.} =
  ## Returns an immutable view of the internal value of `p`.
  checkNotNil(p)
  SharedPtr[T](p).val[]

proc `[]=`*[T](p: ConstPtr[T], v: T) {.error: "`ConstPtr` cannot be assigned.".}

proc `$`*[T](p: ConstPtr[T]): string {.inline.} =
  $SharedPtr[T](p)
