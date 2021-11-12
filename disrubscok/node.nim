import disrubscok/spec
import wtbanland/[atomics, tagptr, memalloc, volatile]

template nodePadding: int =
  cacheLineSize - sizeof(pointer) * 4 - sizeof(uint) * 2 - 2

type
  NodePtr* = Atomic[TagPtr]
  Node* = object # Cache line aligned
    parent*: NodePtr
    left*: NodePtr
    next*: NodePtr
    right*: NodePtr
    value*: Atomic[uint]
    key*: Atomic[uint]
    inserting*: Atomic[uint8]
    parentDirection*: Atomic[uint8]
    padding: array[nodePadding, char]

template `@=`*(d: NodePtr, v: TagPtr) = d.store(v, moRlx)
template `[]`*(d: NodePtr): TagPtr = d.load(moRlx)
template `@=`*[T](d: var Atomic[T], v: T) = d.store(v, moRlx)
template `[]`*[T](d: var Atomic[T]): T = d.load(moRlx)
template `<-`*(dest: ptr NodePtr, src: NodePtr) = dest = src.unsafeAddr()
template `<-`*(dest: ptr NodePtr, src: ptr NodePtr) = dest = src
converter toNodePtr*(x: ptr NodePtr): NodePtr = x[]

const ctx* = initContext[Node](3)

template tagPtr*(nptr: ptr Node | SomeInteger | pointer): TagPtr = cast[TagPtr](nptr)

template getFlags*(tptr: TagPtr): untyped = getFlags(tptr, ctx)
template getPtr*(tptr: TagPtr): untyped = getPtr(tptr, ctx)
template getNode*(nptr: NodePtr): untyped = cast[ptr Node](nptr[])[]
# template getFlags*(nptr: NodePtr): untyped = getFlags(nptr.rawLoad(), ctx)
# template getPtr*(nptr: NodePtr): untyped = getPtr(nptr.rawLoad(), ctx)

template markDelete*(v: NodePtr): TagPtr = v.fetchOr(deleteFlag)
template markInsert*(v: NodePtr): TagPtr = v.fetchOr(insertFlag)
template markLeaf*(v: NodePtr): TagPtr = v.fetchOr(leafFlag)
template markDelete*(v: TagPtr): TagPtr = v or deleteFlag
template markInsert*(v: TagPtr): TagPtr = v or insertFlag
template markLeaf*(v: TagPtr): TagPtr = v or leafFlag

proc createNode*(): ptr Node =
  result = createShared(Node)
  result.volatileStore(Node())

proc freeNode*(n: ptr Node) =
  freeShared(n)