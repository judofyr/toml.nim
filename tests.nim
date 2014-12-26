import toml
import unittest

var walker: TomlWalker

suite "walker":
  teardown:
    check walker.isDone

  test "simple number":
    walker.initWalker("data = 123")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TNum
    check walker.readInt == 123

  test "simple float":
    walker.initWalker("data = 1.2")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TNum
    check walker.readFloat == 1.2

  test "parsing int as float":
    walker.initWalker("data = 123")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TNum
    check walker.readFloat == 123

  test "parsing float as int":
    walker.initWalker("data = 1.2")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TNum
    expect TomlError:
      discard walker.readInt

    check walker.readFloat == 1.2

  test "simple string":
    walker.initWalker("data = '123'")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == "123"
