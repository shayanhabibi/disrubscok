import disrubscok

var tsl = newTslQueue[int](5)

echo tsl.insert(5'u, 10'u)
echo tsl.insert(2'u, 5'u)
echo tsl.insert(3'u, 10'u)
echo tsl.insert(7'u, 5'u)
echo tsl.insert(10'u, 10'u)
echo tsl.deleteMin()
echo tsl.insert(2'u, 5'u)
echo tsl.insert(2'u, 10'u)
echo tsl.deleteMin()
echo tsl.deleteMin()
echo tsl.deleteMin()
echo tsl.deleteMin()
