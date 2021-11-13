{.push, header: "<stdatomic.h>".}

type
  MemoryOrder* {.importc: "memory_order".} = enum
    moRelaxed
    moConsume
    moAcquire
    moRelease
    moAcquireRelease
    moSequentiallyConsistent

type
  AtomicInt8 {.importc: "_Atomic NI8".} = int8
  AtomicInt16 {.importc: "_Atomic NI16".} = int16
  AtomicInt32 {.importc: "_Atomic NI32".} = int32
  AtomicInt64 {.importc: "_Atomic NI64".} = int64

template nonAtomicType*(T: typedesc): untyped =
    # Maps types to integers of the same size
    when sizeof(T) == 1: int8
    elif sizeof(T) == 2: int16
    elif sizeof(T) == 4: int32
    elif sizeof(T) == 8: int64

template atomicType*(T: typedesc): untyped =
  # Maps the size of a trivial type to it's internal atomic type
  when sizeof(T) == 1: AtomicInt8
  elif sizeof(T) == 2: AtomicInt16
  elif sizeof(T) == 4: AtomicInt32
  elif sizeof(T) == 8: AtomicInt64

# type
#   Atomic*[T] = object
#     value: T.atomicType

proc atomic_load_explicit[T, A](location: ptr A; order: MemoryOrder): T {.importc.}
proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.importc.}
proc atomic_exchange_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
proc atomic_compare_exchange_strong_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}
proc atomic_compare_exchange_weak_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}

# Numerical operations
proc atomic_fetch_add_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
proc atomic_fetch_sub_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
proc atomic_fetch_and_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
proc atomic_fetch_or_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
proc atomic_fetch_xor_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}

{.pop.}

# proc load*[T](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
#   cast[T](atomic_load_explicit[nonAtomicType(T), typeof(location.value)](addr(location.value), order))
# proc store*[T](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
#   atomic_store_explicit(addr(location.value), cast[nonAtomicType(T)](desired), order)


type
  NuclearPointer = pointer
  Nuclear*[T] = distinct T

## Nuclear
## Emulates volatile pointers
## Essentially, it replaces pointer/ptr T to ensure that every access of
## the memory contained is done atomically with relaxed memory  ordering
## which would achieve the same effect of Volatile Pointers.
## 
## Ie: All dereferences of the pointer would have to atomic load the memory
## at its destination and then convert it into the expected type
## All assignments to Nuclears will change the destination it points to.
## Nuclears can point to Nuclears.

# template toPtr[T](x: Nuclear[T]): ptr T = cast[ptr T](x)
# template toAtomicPtr[T](x: Nuclear[T]): ptr T.atomicType = cast[ptr T.atomicType](x)

proc `[]`*[T](x: var Nuclear[T]): T =
  ## This will return the value/object the nuclear is pointing to
  atomic_load_explicit[nonAtomicType(T), atomicType(T)](
    cast[ptr atomicType(T)](unsafeAddr(x)), moRelaxed
    )

proc `<-`*[T](x, y: var Nuclear[T]) =
  ## This changes the value the nuclear is pointing to
  atomic_store_explicit[nonAtomicType(T), atomicType(T)](
    # cast[ptr atomicType(T)](unsafeAddr(x)), cast[nonAtomicType(uint)](y), moRelaxed
    cast[ptr atomicType(T)](unsafeAddr(x)), y[], moRelaxed
    )

proc `<-`*[T](x: var Nuclear[T], y: T) =
  atomic_store_explicit[nonAtomicType(T), atomicType(T)](
    cast[ptr atomicType(T)](unsafeAddr(x)), y, moRelaxed
  )


# proc isNil[T](x: Nuclear[T]): bool {.inline.}
