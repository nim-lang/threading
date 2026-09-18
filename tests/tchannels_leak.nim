## Regression test: destroying all handles of a channel (including copies)
## must free the underlying channel. Measured via the process RSS growth:
## a leaked channel keeps its buffer alive, so the growth over many
## create/destroy cycles is proportional to the number of leaked channels.
##
## Handles are released with `s = Sender[T]()` (assignment of a nil handle),
## not `=destroy`: `=destroy` does not nil the handle's pointer, so an
## explicit `=destroy` on a local would be run a second time by the compiler
## at scope end and touch the channel again.

discard """
  matrix: "--threads:on --gc:orc; --threads:on --gc:arc"
  disabled: "freebsd, windows"
"""
import threading/channels
import std/strutils

when defined(linux):
  proc rssKb(): int64 =
    for line in lines("/proc/self/status"):
      if line.len > 5 and line[0..4] == "VmRSS":
        return parseInt(line.split(":")[1].strip().split()[0])

  when defined(tsan):
    const N = 20_000
  else:
    const N = 100_000

  # Allow 1 kB of growth per channel: the old leak cost ~2.2 kB per channel
  # (so it fails with a 2x margin), a leak-free build grows by a few MB
  # total (so it passes with a wide margin).
  const MaxGrowthKb = N

  let before = rssKb()
  for i in 0..<N:
    var (s, r) = newChan[string](elements = 100)
    var s2 = s
    var r2 = r
    s2.reset()
    r2.reset()
    s.reset()
    r.reset()
  let after = rssKb()
  doAssert after - before < MaxGrowthKb,
    "channel leak: RSS grew by " & $((after - before) * 1024) &
    " bytes over " & $N & " channels"
