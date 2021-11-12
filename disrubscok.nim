import disrubscok/spec
import disrubscok/node
import disrubscok/wtbanland/[atomics, tagptr, memalloc]

template tslPadding*: int =
  cacheLineSize - sizeof(ptr Node) * 2 - sizeof(uint) - sizeof(uint32)
template infoPadding*: int =
  cacheLineSize - sizeof(ptr Node) * 4 - 2

type
  TslQueue*[T] = ref object
    head: NodePtr
    root: NodePtr
    threadNum: uint
    delScale: uint32
    padding: array[tslPadding, char]

  NextCast* = object
    next: NodePtr
    right: NodePtr
  
  RecordInfo* = object
    child: NodePtr
    nextNode: NodePtr
    casNode1: NodePtr
    casNode2: NodePtr
    duplicate: Atomic[uint8]
    parentDirection: Atomic[uint8]
    padding: array[infoPadding, char]

template readLeft(): untyped {.dirty.} =
  operationMark @= parentNode.getNode.next[].getFlags
  parentNodeLeft = parentNode.getNode.left[]
  childNode @= parentNodeLeft.getPtr.tagPtr
  childMark @= parentNodeLeft.getFlags
  parentDirection = LeftDir

template readRight(): untyped {.dirty.} =
  operationMark @= parentNode.getNode.next[].getFlags
  parentNodeRight = parentNode.getNode.right[]
  childNode @= parentNodeRight.getPtr.tagPtr
  childMark @= parentNodeRight.getFlags
  parentDirection = RightDir

template traverse(): untyped {.dirty.} =
  if key <= parentNode.getNode.key:
    operationMark @= parentNode.getNode.next[].getFlags
    parentNodeLeft = parentNode.getNode.left[]
    childNode @= parentNodeLeft.getPtr.tagPtr
    childMark @= parentNodeLeft.getFlags
    parentDirection = LeftDir
  else:
    operationMark @= parentNode.getNode.next[].getFlags
    parentNodeRight = parentNode.getNode.right[]
    childNode @= parentNodeRight.getPtr.tagPtr
    childMark @= parentNodeRight.getFlags
    parentDirection = RightDir


proc newTslQueue*[T](numThreads: int): TslQueue[T] =
  let head = createNode()
  let root = createNode()
  let dummy = createNode()

  dummy[].left @= head.tagPtr
  dummy[].right @= markLeaf(dummy.tagPtr)
  dummy[].parent @= root.tagPtr
  dummy[].next @= 0.tagPtr
  
  head[].next @= dummy.tagPtr

  root[].left @= dummy.tagPtr
  root[].key @= 1

  result = new TslQueue
  
  result.head @= head.tagPtr
  result.root @= root.tagPtr
  result.threadNum = numThreads.uint
  result.delScale = cast[uint32](numThreads.uint * 100.uint)

proc insertSearch[T](tsl: TslQueue[T], key: uint): RecordInfo =
  var childNode, grandParentNode, parentNode, root: ptr NodePtr
  var childNext, currentNext, parentNodeRight, parentNodeLeft, markedNode: TagPtr
  var parentDirection: Direction
  var operationMark, childMark: Atomic[uint]
  root <- tsl.root

  var insSeek = RecordInfo()

  parentNode <- root
  childNode <- root[].getPtr[].left

  while true:
    if operationMark[] == deleteFlag.uint:
      readRight()
      markedNode = parentNode[]

      while true:
        if operationMark[] == deleteFlag.uint:
          if childMark[] != leafFlag.uint:
            parentNode = childNode
            readRight()
            continue
          else:
            parentNode = childNode.getNode.next[].getPtr

proc insert*[T](tsl: TslQueue[T]; key, value: uint): uint8 =
  let newNode = createNode()
  newNode[].right @= markLeaf(newNode.tagPtr)
  newNode[].key @= key
  newNode[].value @= value
