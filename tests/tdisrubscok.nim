import disrubscok

type
  Obj = ref object
    field1: int
    field2: int

var myobj = Obj(field1: 5, field2: 19)

var tsl = newTslQueue[Obj](1)
echo tsl.push(1, myobj)
echo tsl.pop().repr

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
