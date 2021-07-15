# Package

version       = "0.1.0"
author        = "Araq"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4"


task test:
  exec "nim c -r tests/fake_test.nim"
