import disrubscok/spec
import disrubscok/node
from std/random import rand
import nuclear
import nuclear/atomics as natomics
export nuclear

template tslPadding*: int =
  cacheLineSize - sizeof(ptr Node) * 2 - sizeof(uint) - sizeof(uint32)
template infoPadding*: int =
  cacheLineSize - sizeof(ptr Node) * 4 - 2

type
  TslQueue*[T] = ref object
    head: nuclear Node
    root: nuclear Node
    threadNum: int
    delScale: uint32
    padding: array[tslPadding, char]
  
  RecordInfo = object
    child: ptr Node
    nextNode: ptr Node
    casNode1: ptr Node
    casNode2: ptr Node
    duplicate: Direction
    parentDirection: Direction
    padding: array[infoPadding, char]

var previousHead, previousDummy: ptr Node

proc rand[T](tsl: TslQueue[T]): uint32 {.inline.} =
  cast[uint32](rand(tsl.delScale.int))

template readLeft(): untyped {.dirty.} =
  when operationMark is uint:
    operationMark = parentNode.next[].getMark
  else:
    operationMark = parentNode.next
  parentNodeLeft = parentNode.left[].cptr
  childNode = cast[nuclear Node](parentNodeLeft.address)
  when childMark is uint:
    childMark = parentNodeLeft.getMark
  else:
    childMark = parentNodeLeft.getMark
  parentDirection = LeftDir

template readRight(): untyped {.dirty.} =
  when operationMark is uint:
    operationMark = parentNode.next[].getMark
  else:
    operationMark = parentNode.next
  parentNodeRight = parentNode.right[].cptr
  childNode = cast[nuclear Node](parentNodeRight.address)
  when childMark is uint:
    childMark = parentNodeRight.getMark
  else:
    childMark = parentNodeRight
  parentDirection = RightDir

template traverse(): untyped {.dirty.} =
  if key <= parentNode.key[]:
    when operationMark is uint:
      operationMark = parentNode.next[].getMark
    else:
      operationMark = parentNode.next
    parentNodeLeft = parentNode.left[].cptr
    childNode = cast[nuclear Node](parentNodeLeft.address)
    when childMark is uint:
      childMark = parentNodeLeft.getMark
    else:
      childMark = parentNodeLeft
      parentDirection = LeftDir
  else:
    when operationMark is uint:
      operationMark = parentNode.next[].getMark
    else:
      operationMark = parentNode.next
    parentNodeRight = parentNode.right[].cptr
    childNode = cast[nuclear Node](parentNodeRight.address)
    when childMark is uint:
      childMark = parentNodeRight.getMark
    else:
      childMark = parentNodeRight
      parentDirection = RightDir


proc newTslQueue*[T](numThreads: int): TslQueue[T] =
  result = new TslQueue[T]

  var head = createNode()
  var root = createNode()
  var dummy = createNode()

  dummy.left[] = head
  dummy.right[] = markLeaf(dummy)
  dummy.parent[] = root


  head.next[] = dummy

  root.left[] = dummy
  root.key[] = 1'u
  result[].head.nuclearAddr()[] = head
  result[].root.nuclearAddr()[] = root
  result[].threadNum.nuclearAddr()[] = numThreads
  result[].delScale.nuclearAddr()[] = cast[uint32](numThreads.uint * 100.uint)

proc pqSize[T](tsl: TslQueue[T]): uint32 =
  var prevNode, leafNode, nextLeaf, head: ptr Node
  head = tsl.head.cptr

  leafNode = head[].next.cptr.address
  nextLeaf = leafNode[].next.cptr.address

  while not leafNode.isNil:
    nextLeaf = leafNode[].next.cptr.address
    if leafNode[].next.cptr.getMark == 0'u and not nextLeaf.isNil:
      inc result
    leafNode = leafNode[].next.cptr.address()
    
template tryHelpingInsert(newNode: nuclear Node) =
  var parentDirection: Direction
  var casNode1, casNode2: ptr Node
  parentDirection = newNode.parentDirection[]
  casNode1 = cptr(newNode.parent[])
  casNode2 = cptr(newNode.left[])

  if parentDirection == LeftDir and newNode.inserting[]:
    if newNode.inserting[]:
      discard casNode1.left.addr.compareExchange(casNode2, newNode)
      if newNode.inserting[]:
        newNode.inserting[] = false
  elif parentDirection == RightDir and newNode.inserting[]:
    if newNode.inserting[]:
      discard casNode1.right.addr.compareExchange(casNode2, newNode)
      if newNode.inserting[]:
        newNode.inserting[] = false


proc physicalDelete[T](tsl: TslQueue[T], dummyNode: nuclear Node) =
  var childNode, childNext, grandParentNode, parentNode, root: nuclear Node
  root = tsl[].root.nuclearAddr()[]
  var parentDirection: Direction
  var clear: uint8
  var parentNodeLeft, parentNodeRight, casVal, currentNext, markedNode: ptr Node
  var operationMark, childMark: uint

  parentNode = root
  childNode = root.left[]
  
  block finish:
    while true:
      if operationMark == deleteFlag:
        readRight()
        markedNode = parentNode.cptr
        while true:
          if operationMark == deleteFlag:
            if childMark != leafFlag:
              parentNode = childNode
              readRight()
              continue
            else:
              childNext = childNode.next[]
              if childNext.inserting[] and
                  childNext.parent[] == parentNode:
                tryHelpingInsert(childNext)
              elif parentNode.right[] == childNode.markLeaf:
                if grandParentNode.key[] != 0'u:
                  grandParentNode.key[] = 0'u
                  break finish
              readRight()
              continue
          else:
            if not grandParentNode.next[].getMark != 0'u:
              if grandParentNode.left[].cptr == markedNode:
                if grandParentNode.left.compareExchange(markedNode, parentNode):
                  readLeft()
                  break
                parentNode = grandParentNode
                readLeft()
                break
            break finish
      else:
        if childMark != leafFlag:
          if parentNode.key[] == 0'u or parentNode == dummyNode:
            if parentNode.key[] != 0'u:
              parentNode.key[] = 0'u
            break finish
          grandParentNode = parentNode
          parentNode = childNode
          readLeft()
          continue
        else:
          currentNext = childNode.next[].cptr
          childNext = cast[nuclear Node](currentNext.address)
          if currentNext.getMark != 0'u:
            if childNext.inserting[] and
                childNext.parent[] == parentNode:
              tryHelpingInsert(childNext)
            elif parentNode.left[] == childNode.markLeaf:
              if childNext.key[] != 0'u:
                childNext.key[] = 0'u
              break finish
            readLeft()
            continue


proc insertSearch[T](tsl: TslQueue[T], key: uint): RecordInfo =
  var childNode, grandParentNode, parentNode, root: nuclear Node
  var childNext, currentNext, parentNodeRight, parentNodeLeft, markedNode: ptr Node
  var parentDirection: Direction
  var operationMark: Nuclear[Nuclear[Node]]
  var childMark: ptr Node

  root = tsl[].root.nuclearAddr()[]

  var insSeek = RecordInfo()

  parentNode = root
  childNode = root.left[]
  while true:
    if not operationMark.isNil and operationMark[].getMark == deleteFlag.uint:
      readRight()
      markedNode = parentNode.cptr

      while true:
        if operationMark[].getMark == deleteFlag.uint:
          if childMark.getMark != leafFlag.uint:
            parentNode = childNode
            readRight()
            continue
          else:
            parentNode = childNode.next[].address
            readRight()
            break
        else:
          if rand(tsl) < insertCleanRate:
            if not (grandParentNode.next[].getMark != 0'u) and
                grandParentNode.left[].cptr == markedNode:
              discard grandParentNode.left.compareExchange(markedNode, parentNode)
          traverse()
          break
      continue
    if childMark.getMark != leafFlag:
      grandParentNode = parentNode
      parentNode = childNode
      traverse()
    else:
      currentNext = childNode.next[].cptr
      childNext = currentNext.address
      if currentNext.getMark != 0'u:
        # REVIEW GO_NEXT
        parentNode = cast[nuclear Node](childNext)
        readRight()
      elif (not childNext.isNil()) and childNext[].inserting:
        tryHelpingInsert(cast[nuclear Node](childNext))
        parentNode = cast[nuclear Node](childNext)
        traverse()
      elif (not childNext.isNil()) and childNext[].key == key:
        insSeek.duplicate = DuplDir
        return insSeek
      elif (parentDirection == LeftDir and
          parentNode.left[] == childNode.markLeaf()) or
          (parentDirection == RightDir and
          parentNode.right[] == childNode.markLeaf()):
        insSeek.child = childNode.cptr
        insSeek.casNode1 = parentNode.cptr
        insSeek.casNode2 = childNode.markLeaf().cptr
        insSeek.nextNode = childNext
        insSeek.parentDirection = parentDirection
        return insSeek
      else:
        traverse()

proc pop*[T](tsl: TslQueue[T]): T =
  ## Remove the object from the queue with the lowest key value.
  runnableExamples:
    type
      Obj = ref object
        field1: int
        field2: int

    var myobj = Obj(field1: 5, field2: 19)
    var myobj2 = Obj(field1: 3, field2: 12)
    var myobj3 = Obj(field1: 0, field2: 1)
    var tsl = newTslQueue[Obj](1)
    doAssert tsl.push(2, myobj) == true
    doAssert tsl.push(1, myobj2) == true
    doAssert tsl.push(3, myobj3) == true
    doAssert tsl.pop() == myobj2
    
  template ready(x: uint): T =
    when T is ref:
      let res = cast[T](x)
      GC_unref res
      res
    else:
      cast[T](x)
  var leafNode, nextLeaf, head: nuclear Node
  var xorNode, currentNext, headItemNode, newHead: ptr Node
  var value: uint

  head = tsl.head

  headItemNode = head.next[].cptr
  leafNode = cast[nuclear Node](headItemNode)

  if previousHead == leafNode.cptr:
    leafNode = cast[nuclear Node](previousDummy)
  else:
    previousHead = headItemNode
  while true:
    currentNext = leafNode.next[].cptr
    nextLeaf = cast[nuclear Node](currentNext)
    if nextLeaf.isNil:
      previousDummy = leafNode.cptr
      return
    else:
      if currentNext.getMark != 0'u:
        leafNode = nextLeaf
        continue
      xorNode = leafNode.next.fetchXor(1).cptr
      if xorNode.getMark == 0'u:
        value = xorNode.address()[].value
        previousDummy = xorNode
        if tsl.rand >= physicalDeleteRate:
          return value.ready
        if head.next[].cptr == headItemNode:
          if head.next.compareExchange(headItemNode, xorNode):
            previousHead = xorNode
            if xorNode[].key != 0'u:
              xorNode[].key = 0'u
              physicalDelete(tsl, cast[nuclear Node](xorNode))
              nextLeaf = cast[nuclear Node](headItemNode)
              while nextLeaf.cptr != xorNode:
                currentNext = nextLeaf.cptr
                nextLeaf = nextLeaf.next[].address
                freeNode(currentNext)
        return value.ready
      leafNode = cast[nuclear Node](xorNode.address)


proc push*[T](tsl: TslQueue[T]; vkey: Natural, val: T): bool =
  ## Try push an object onto the queue with a key for priority.
  ## Pops will remove the object with the lowest vkey first.
  ## You cannot have duplicate keys (for the moment).
  runnableExamples:
    type
      Obj = ref object
        field1: int
        field2: int

    var myobj = Obj(field1: 5, field2: 19)

    var tsl = newTslQueue[Obj](1)
    doAssert tsl.push(1, myobj) == true
    doAssert tsl.pop() == myobj
  
  var key = vkey.uint
  when T is ref:
    GC_ref val
  template clean: untyped =
    when T is ref:
      GC_unref val
    else:
      discard
  var value = cast[uint](val)
  var casNode1, casNode2, leafNode: nuclear Node
  var nextLeaf: ptr Node
  var parentDirection: Direction
  var insSeek: RecordInfo

  var newNode: nuclear Node = createNode()
  newNode.right[] = markLeaf(newNode)
  newNode.key[] = key
  newNode.value[] = value

  while true:
    casNode1 = nil
    casNode2 = nil
    insSeek = insertSearch(tsl, key)
    if insSeek.duplicate == DuplDir:
      freeNode(newNode)
      clean()
      return false
    elif insSeek.child.isNil:
      continue
    parentDirection = insSeek.parentDirection
    casNode1 = cast[nuclear Node](insSeek.casNode1)
    casNode2 = cast[nuclear Node](insSeek.casNode2)
    leafNode = cast[nuclear Node](insSeek.child)
    nextLeaf = insSeek.nextNode
    newNode.left[] = leafNode.markLeaf
    newNode.parentDirection[] = parentDirection
    newNode.parent[] = casNode1
    newNode.next[] = cast[nuclear Node](nextLeaf)
    newNode.inserting[] = true
    if leafNode.next[].cptr == nextLeaf:
      template casDir(casDir: Direction): untyped =
        if leafNode.next[].cptr == nextLeaf:
          if leafNode.next.compareExchange(nextLeaf, newNode):
            if newNode.inserting[]:
              when casDir == RightDir:
                if casNode1.right[] == casNode2:
                  discard casNode1.right.compareExchange(casNode2, newNode)

              elif casDir == LeftDir:
                if casNode1.left[] == casNode2:
                  discard casNode1.left.compareExchange(casNode2, newNode)

              if newNode.inserting[]:
                newNode.inserting[] = false
            return true

      if parentDirection == RightDir:
        casDir RightDir
      elif parentDirection == LeftDir:
        casDir LeftDir