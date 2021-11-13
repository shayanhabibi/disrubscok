# import wtbanland/cacheline # Not ready to be used yet; just use a const
const cacheLineSize* = 64

import wtbanland/[atomics, tagptr, memalloc, nuclear]

const
  deleteFlag* = 1                      # 1
  insertFlag* = 1 shl 1                # 2
  leafFlag* = deleteFlag or insertFlag # 3

  flagsMask* = ((1 shl 2) - 1).uint
  ptrMask* = high(uint) xor flagsMask

  physicalDeleteRate*: uint32 = 1
  insertCleanRate*: uint32 = 50
type
  Direction* = enum
    LeftDir, RightDir, DuplDir