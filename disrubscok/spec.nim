# import wtbanland/cacheline # Not ready to be used yet; just use a const
const cacheLineSize = 64

import wtbanland/[atomics, tagptr, memalloc]

const
  deleteFlag = 1                      # 1
  insertFlag = 1 shl 1                # 2
  leafFlag = deleteFlag or insertFlag # 3

  flagsMask = ((1 shl 2) - 1).uint
  ptrMask = high(uint) xor flagsMask

template nodePadding: untyped =
  cacheLineSize - sizeof(pointer) * 4 - sizeof(uint) * 2 - 2
template tslPadding: untyped =
  cacheLineSize - sizeof(ptr Node) * 2 - sizeof(uint) - sizeof(uint32)
template infoPadding: untyped =
  cacheLineSize - sizeof(ptr Node) * 4 - 2

type
  Node = object # Cache line aligned
    parent: pointer
    left: pointer
    next: pointer
    right: pointer
    value: uint
    key: uint
    inserting: uint8
    parentDirection: uint8
    padding: array[nodePadding, char]

  TslQueue = object
    head: ptr Node
    root: ptr Node
    threadNum: uint
    delScale: uint32
    padding: array[tslPadding, char]

  NextCast = object
    next: pointer
    right: pointer
  
  RecordInfo = object
    child: ptr Node
    nextNode: ptr Node
    casNode1: ptr Node
    casNode2: ptr Node
    duplicate: uint8
    parentDirection: uint8
    padding: array[infoPadding, char]


  