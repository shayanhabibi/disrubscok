import disrubscok/spec
import disrubscok/node
import disrubscok/wtbanland/[atomics, tagptr, memalloc]
from std/random import rand

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

var previousHead, previousDummy {.threadvar.}: TagPtr

template readLeft(): untyped {.dirty.} =
  operationMark @= parentNode.getNode.next[].getFlags
  parentNodeLeft = parentNode.getNode.left[]
  childNode <- parentNodeLeft.getPtr.tagPtr
  childMark @= parentNodeLeft.getFlags
  parentDirection = LeftDir

template readRight(): untyped {.dirty.} =
  operationMark @= parentNode.getNode.next[].getFlags
  parentNodeRight = parentNode.getNode.right[]
  childNode <- parentNodeRight.getPtr.tagPtr
  childMark @= parentNodeRight.getFlags
  parentDirection = RightDir

template traverse(): untyped {.dirty.} =
  if key <= parentNode.getNode.key:
    operationMark @= parentNode.getNode.next[].getFlags
    parentNodeLeft = parentNode.getNode.left[]
    childNode <- parentNodeLeft.getPtr
    childMark @= parentNodeLeft.getFlags
    parentDirection = LeftDir
  else:
    operationMark @= parentNode.getNode.next[].getFlags
    parentNodeRight = parentNode.getNode.right[]
    childNode <- parentNodeRight.getPtr
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

proc pqSize[T](tsl: TslQueue[T]): int =
  var prevNode, leafNode = TagPtr
  var nextLeaf, head: ptr NodePtr
  head <- set.head
  leafNode = head.getNode.next[].getPtr.tagPtr
  nextLeaf <- leafNode.getPtr[].next[].getPtr.tagPtr
  while not leafNode.getPtr.isNil:
    nextLeaf <- leafNode.getPtr[].next[].getPtr
    if leafNode.getPtr[].next[].getFlags == 0'u and
        not nextLeaf.isNil:
      inc result
    leafNode = leafNode.getPtr[].next.getPtr.tagPtr

proc deleteMin[T](tsl: TslQueue[T]): uint =
  var leafNode, nextLeaf, head: ptr NodePtr
  var xorNode, currentNext, headItemNode, newHead: TagPtr
  var value: uint

  head <- tsl.head
  headItemNode = head.getNode.next[]
  leafNode <- head.getNode.next

  if previousHead == leafNode[]:
    leafNode <- previousDummy
  else:
    previousHead = headItemNode
  while true:
    currentNext = leafNode.getNode.next[]
    nextLeaf <- currentNext.getPtr
    if nextLeaf.isNil:
      previousDummy = leafNode[]
      return 0'u
    else:
      if currentNext.getFlags != 0'u:
        leafNode <- nextLeaf
        continue
      xorNode = leafNode.getNode.next.fetchXor(1)
      if xorNode.getFlags == 0'u:
        value = xorNode.getPtr[].value[]
        previousDummy = xorNode
        if rand(high(uint)) >= physicalDeleteRate:
          return value
        if head.getNode.next[] == headItemNode:
          if true: # FIXME CAS
            previousHead = xorNode
            if xorNode.getPtr[].key[] != 0'u:
              xorNode.getPtr[].key @= 0'u
              # FIXME physicalDelete(tsl, xorNode)
              nextLeaf <- headItemNode.getPtr
              while nextLeaf[] != xorNode:
                currentNext = nextLeaf[]
                nextLeaf <- nextLeaf.getNode.next[].getPtr
                freeNode(currentNext.getPtr)
        return value
      leafNode <- xorNode.getPtr


proc physicalDelete[T](tsl: TslQueue[T], dummyNode: ptr NodePtr) =
  var childNode, childNext, grandParentNode, parentNode, root: ptr NodePtr
  root <- tsl.root
  var parentDirection: Direction
  var clear: uint8
  var parentNodeLeft, parentNodeRight, casVal, currentNext, markedNode: TagPtr
  var operationMark, childMark: Atomic[uint]

  parentNode <- root
  childNode <- root.getNode.left
  
  block finish:
    while true:
      if operationMark == deleteFlag:
        readRight()
        markedNode = parentNode[]
        while true:
          if operationMark == deleteFlag:
            if childMark != leafFlag:
              parentNode <- childNode
              readRight()
              continue
            else:
              childNode <- childNode.getNode.next[].getPtr
              if childNext.getNode.inserting != 0'u8 and
                  childNext.getNode.parent[] == parentNode[]:
                ## FIXME tryHelpingInsert(childNext)
              elif parentNode.getNode.right[] == childNode[].markLeaf:
                if grandParentNode.getNode.key[] != 0'u:
                  grandParentNode.getNode.key @= 0'u
                  break finish
              readRight()
              continue
          else:
            if not grandParentNode.getNode.next[].getFlags != 0'u:
              if grandParentNode.getNode.left[] == markedNode:
                if true: # FIXME CAS
                  readLeft()
                  break
                parentNode <- grandParentNode
                readLeft()
                break
            break finish
      else:
        if childMark[] != leafFlag:
          if parentNode.getNode.key[] == 0'u or parentNode == dummyNode:
            if parentNode.getNode.key[] != 0'u:
              parentNode.getNode.key @= 0'u
            break finish
          grandParentNode <- parentNode
          parentNode <- childNode
          readLeft()
          continue
        else:
          currentNext = childNode.getNode.next[]
          childNext = currentNext.getPtr
          if currentNext.getFlags != 0'u:
            if childNext.getNode.insert[] != 0'u8 and
                childNext.getNode.parent.addr == parentNode:
              ## tryHelpingInsert(childNext)
            elif parentNode.getNode.left[] == childNode[].markLeaf:
              if childNext.getNode.key[] != 0'u:
                childNext.getNode.key @= 0'u
              break finish
            readLeft()
            continue


proc tryHelpingInsert(nptrptr: ptr NodePtr, newNode: ptr Node) =
  var parentDirection: Direction
  var casNode1, casNode2: ptr NodePtr
  parentDirection = cast[Direction](newNode[].parentDirection[])
  casNode1 <- newNode[].parent
  casNode2 <- newNode[].left

  if parentDirection == LeftDir and newNode[].inserting[] != 0'u8:
    if newNode[].inserting[] != 0'u8:
      # FIXME casNode1.compareExchange(casNode2[], newNode.tagPtr)
      if newNode[].inserting[] != 0'u8:
        newNode[].inserting @= 0'u8
  elif parentDirection == RightDir and newNode[].insert[] != 0'u8:
    if newNode[].insert[] != 0'u8:
      # FIXME CAS
      if newNode[].insert[] != 0'u8:
        newNode[].inserting @= 0'u8

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
            parentNode <- childNode
            readRight()
            continue
          else:
            parentNode <- childNode.getNode.next[].getPtr
            readRight()
            break
        else:
          if rand(high(uint32)) < insertCleanRate:
            if not (grandParentNode.getNode.next[].getFlags != 0'u) and
                grandParentNode.getNode.left.getNode == markedNode:
              discard
          traverse()
          break
      continue
    if childMark[] != leafFlag:
      grandParentNode <- parentNode
      parentNode <- childNode
      traverse()
    else:
      currentNext = childNode.getNode.next[]
      childNext = currentNext.getPtr
      if currentNext.getFlags != 0'u:
        # FIXME GO_NEXT
        parentNode <- childNext
        readRight()
      elif (not childNext.isNil()) and childNext[].inserting[] != 0'u:
        # FIXME tryHelpingInsert(childNext)
        parentNode <- childNext
        traverse()
      elif (not childNext.isNil()) and childNext[].key[] == key:
        insSeek.duplicate = DuplDir
        return insSeek
      elif (parentDirection == LeftDir and
          parentNode.getNode.left[] == childNode[].markLeaf()) or
          (parentDirection == RightDir and
          parentNode.getNode.right[] == childNode[].markLeaf()):
        insSeek.child @= childNode[]
        insSeek.casNode1 @= parentNode[]
        insSeek.casNode2 @= childNode[].markLeaf()
        insSeek.nextNode @= childNext.tagPtr
        insSeek.parentDirection = parentDirection
        return insSeek
      else:
        traverse()

proc insert*[T](tsl: TslQueue[T]; key, value: uint): uint8 =
  var casNode1, casNode2, leafNode: ptr NodePtr
  var nextLeaf: TagPtr
  var parentDirection: Direction
  var insSeek: RecordInfo

  var newNode: ptr NodePtr
  newNode <- createNode()

  newNode.getNode.right @= newNode[].markLeaf
  newNode.getNode.key @= key
  newNode.getNode.value @= value
  while true:
    casNode1 = nil
    casNode2 = nil
    insSeek = insertSearch(tsl, key)
    if insSeek.duplicate == DuplDirection:
      freeNode(cast[ptr Node](newNode))
      return 0'u8
    elif insSeek.child[].getPtr.isNil:
      continue
    parentDirection = insSeek.parentDirection
    casNode1 <- insSeek.casNode1
    casNode2 <- insSeek.casNode2
    leafNode <- insSeek.child
    nextLeaf = insSeek.nextNode[]

    newNode.getNode.left @= leafNode[].markLeaf
    newNode.getNode.parentDirection = parentDirection
    newNode.getNode.parent @= casNode1
    newNode.getNode.next @= nextLeaf
    newNode.getNode.inserting @= 1'u8
    if leafNode.getNode.next[] == nextLeaf:
      if parentDirection == RightDir:
        ## FIXME
      elif parentDirection == leftDir:
        if leafNode.getNode.next[] == nextLeaf:
          if true: # FIXME CAS
            if newNode.getNode.inserting[] != 0'u8:
              if casNode1.getNode.left == casNode2:
                ## FIXME CAS
              if newNode.getNode.inserting[] != 0'u8:
                newNode.getNode.inserting @= 0'u8
            return 1
