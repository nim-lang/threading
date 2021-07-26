import sync/spsc, std/isolation

const
  seed = 99
  bufCap = 20
  numIters = 1000

type
  Foo = ref object
    id: string

type
  WorkerKind = enum
    Producer
    Consumer

  ThreadArgs = object
    case id: WorkerKind
    of Producer:
      tx: SpscSender[Foo]
    of Consumer:
      rx: SpscReceiver[Foo]

template sendLoop(tx, data: typed, body: untyped): untyped =
  while not tx.trySend(data):
    body

template recvLoop(rx, data: typed, body: untyped): untyped =
  while not rx.tryRecv(data):
    body

proc threadFn(args: ThreadArgs) =
  case args.id
  of Consumer:
    for i in 0 ..< numIters:
      var res: Foo
      recvLoop(args.rx, res): cpuRelax()
      #echo " >> received ", res.id, " ", $(seed + i)
      assert res.id == $(seed + i)
  of Producer:
    for i in 0 ..< numIters:
      var p = isolate(Foo(id: $(i + seed)))
      sendLoop(args.tx, p): cpuRelax()
      #echo " >> sent ", $(i + seed)

proc testSpScRing =
  let (tx, rx) = newSpscChannel[Foo](bufCap) # tx for transmission, rx for receiving
  var thr1, thr2: Thread[ThreadArgs]
  createThread(thr1, threadFn, ThreadArgs(id: Producer, tx: tx))
  createThread(thr2, threadFn, ThreadArgs(id: Consumer, rx: rx))
  joinThread(thr1)
  joinThread(thr2)

testSpScRing()
