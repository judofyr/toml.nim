import toml

var walker: TomlWalker

# Parsing a simple number
walker.initWalker("data = 123")

assert(walker.kind == TKey)
assert(walker.readKey == "data")

assert(walker.kind == TNum)
assert(walker.readInt == 123)

assert(walker.isDone)

# Parsing a simple string
walker.initWalker("data = '123'")

assert(walker.kind == TKey)
assert(walker.readKey == "data")

assert(walker.kind == TString)
assert(walker.readString == "123")

assert(walker.isDone)
