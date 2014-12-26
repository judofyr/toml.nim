# TOML Walker

This package implements a TOML parser using the walker pattern:

```nim
import toml
var walker: TomlWalker
walker.initWalker(readFile("example.toml"))

for path in walker.sections:
  if path.isNil:
    # We're in the main section:
    for key in walker.keys:
      if key == "title":
        echo "Title: ", walker.readString
      else:
        walker.skip
  elif path.len == 1 and path[0] == "user"
    for key in walker.keys:
      # ...
  else:
    walker.skipSection
```

