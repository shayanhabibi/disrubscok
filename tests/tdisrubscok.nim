import disrubscok

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

# type
#   Obj = ref object
#     field1: int
#     field2: int

# var myobj = Obj(field1: 5, field2: 19)

# var tsl = newTslQueue[Obj](1)
# doAssert tsl.push(1, myobj) == true
# doAssert tsl.pop() == myobj

# var tsl = newTslQueue[int](5)

# echo tsl.push(5, 10)
# echo tsl.push(2, 5)
# echo tsl.push(3, 10)
# echo tsl.push(7, 5)
# echo tsl.push(10, 10)
# echo tsl.pop()
# echo tsl.push(2, 5)
# echo tsl.push(2, 10)
# echo tsl.pop()
# echo tsl.pop()
# echo tsl.pop()
# echo tsl.pop()
