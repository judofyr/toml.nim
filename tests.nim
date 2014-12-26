import toml
import unittest
import unicode

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

  test "string with escape codes":
    walker.initWalker("data = '123\\n123'\ndata = '\\n123'\ndata = '123\\n'")

    # Escape in the middle
    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == "123\n123"

    # Escape at beginning
    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == "\n123"

    # Escape at end
    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == "123\n"

  test "various escape code":
    walker.initWalker("data = '\\b\\t\\n\\f\\r\\\"\\/\\\\'")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == "\b\t\n\f\r\"/\\"

  test "unicode escape":
    walker.initWalker("data = '\\u2300'")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == Rune(0x2300).toUTF8

  test "big unicode escape":
    walker.initWalker("data = '\\U0001F4A9'")

    check walker.kind == TKey
    check walker.readKey == "data"

    check walker.kind == TString
    check walker.readString == Rune(0x1F4A9).toUTF8

