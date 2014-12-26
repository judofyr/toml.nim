import strutils
import times
import unicode

type
  TomlNodeKind* = enum
    TKey, THeader, TTrue, TFalse, TNum, TString, TDatetime, TArray, TDone

  TomlWalker* = object
    buffer: string
    position: int
    depth: int

    inArrayTable*: bool
    kind*: TomlNodeKind

  TomlError* = object of Exception


proc lineInfo(walker: var TomlWalker, i: int): tuple[lineno: int, lineStart: int, lineStop: int] =
  let buffer = walker.buffer

  result.lineno = 1
  result.lineStop = buffer.len-1

  for j in 0..buffer.len-1:
    if buffer[j] == '\10':
      if j > i:
        result.lineStop = j-1
        return

      result.lineno += 1
      result.lineStart = j+1

template parserException(walker: var TomlWalker, i: int, msg: string): expr =
  let
    (lineno, lineStart, lineStop) = walker.lineInfo(i)
    line = walker.buffer.substr(lineStart, lineStop)
    space = repeatChar(i - lineStart)
    fullmsg = "$# at line $#:\n  $#\n  $#^" % [ msg, $lineno, line, space ]
  newException(TomlError, fullmsg)

template kindException(walker: var TomlWalker, msg: string): expr =
  parserException(walker, walker.position, "expected " & msg & " got " & $walker.kind)

proc processMain(walker: var TomlWalker)
proc processValue(walker: var TomlWalker)

proc process(walker: var TomlWalker) =
  if walker.depth > 0:
    walker.processValue
  else:
    walker.processMain

proc initWalker*(walker: var TomlWalker, buffer: string) =
  walker.buffer = buffer
  walker.position = 0
  walker.depth = 0
  walker.inArrayTable = false
  shallow(walker.buffer)
  walker.process

proc isDone*(walker: var TomlWalker):bool =
  walker.position >= walker.buffer.len

proc atKey*(walker: var TomlWalker): bool =
  walker.kind == TKey

proc processMain(walker: var TomlWalker) =
  var
    inComment = false
    i = walker.position
    len = walker.buffer.len

  while i < len:
    case walker.buffer[i]
    of '#':
      inComment = true
    of '\10':
      inComment = false
    of ' ', '\9', '\13':
      discard
    of '[':
      walker.kind = THeader
      break
    else:
      if not inComment:
        walker.kind = TKey
        break
    i = i+1

  walker.position = i

proc readHeader*(walker: var TomlWalker): seq[string] =
  if walker.kind != THeader:
    raise kindException(walker, "header")

  newSeq(result, 0)
  shallow(result)

  var
    i = walker.position
    start = i
    buffer = walker.buffer
    len = buffer.len
    isArray = false

  while i < len:
    let c = buffer[i]
    if c == '[':
      isArray = true
      start += 1
    elif c == '.' or c == ']':
      let name = buffer.substr(start, i-1)
      result.add(name)
      start = i+1
      if c == ']':
        break
    i += 1

  if isArray:
    i += 1
    walker.inArrayTable = true

  walker.position = i+1
  walker.processMain

proc processValue(walker: var TomlWalker) =
  var
    i = walker.position
    buffer = walker.buffer
    len = buffer.len

  while i < len:
    let c = buffer[i]
    case c
    of '=', ' ', '\9', '\10', '\13':
      discard
    of '"', '\'':
      walker.kind = TString
      break
    of '0'..'9':
      walker.kind = TNum
      for k in i+1..len-1:
        case buffer[k]:
        of '0'..'9':
          # nubmers are fine
          discard
        of '-':
          # dashes are only allowed in dates
          walker.kind = TDatetime
          break
        else:
          break
      break
    of '+', '-':
      walker.kind = TNum
      break
    of 't':
      walker.kind = TTrue
      i += 4
      break
    of 'f':
      walker.kind = TFalse
      i += 5
      break
    of '[':
      walker.kind = TArray
      walker.depth += 1
      i += 1
      break
    of ',':
      walker.kind = TArray
      i += 1
      break
    of ']':
      walker.kind = TDone
      walker.depth -= 1
      i += 1
      break
    else:
      raise parserException(walker, i, "unexpected char")
    i += 1

  walker.position = i

proc findNonws(walker: var TomlWalker): int =
  var
    buffer = walker.buffer
    len = buffer.len
    i = walker.position

  while i < len:
    let c = buffer[i]
    case c
    of '\10', '\13', ' ', '\9', ',', ']':
      break
    else:
      discard
    i += 1

  result = i

proc skipNonws(walker: var TomlWalker) =
  walker.position = walker.findNonws
  walker.process

proc readKey*(walker: var TomlWalker, skip = false): string =
  if walker.kind != TKey:
    raise kindException(walker, "Key")

  var
    i = walker.position
    start = i
    buffer = walker.buffer
    len = buffer.len

  while i < len:
    case buffer[i]:
    of '=', ' ', '\9':
      break
    else:
      discard
    i += 1

  assert(start != i)
      
  # We've got the name
  if not skip:
    result = buffer.substr(start, i-1)
  walker.position = i
  walker.processValue


proc readInt*(walker: var TomlWalker): int64 =
  if walker.kind != TNum:
    raise kindException(walker, "number")

  var
    buffer = walker.buffer
    len = buffer.len
    i = walker.position
    negative = false

  while i < len:
    let c = buffer[i]
    case c
    of '-':
      negative = true
    of '+':
      discard
    of '0'..'9':
      result = result*10 + int64(c) - int64('0')
    of '\10', '\13', ' ', '\9', ',', ']':
      break
    else:
      raise parserException(walker, i, "invalid number")
    i += 1

  if negative:
    result = -result

  walker.position = i
  walker.process

proc readFloat*(walker: var TomlWalker): float =
  if walker.kind != TNum:
    raise kindException(walker, "number")

  var
    buffer = walker.buffer
    start = walker.position

  let stop = walker.findNonws
  let str = buffer.substr(start, stop-1)
  result = parseFloat(str)
  walker.position = stop
  walker.process

proc readBool*(walker: var TomlWalker): bool =
  case walker.kind
  of TTrue:
    result = true
  of TFalse:
    result = false
  else:
    raise kindException(walker, "boolean")

  walker.process

proc readString*(walker: var TomlWalker, skip = false): string =
  if walker.kind != TString:
    raise kindException(walker, "string")

  result = ""

  var
    buffer = walker.buffer
    len = buffer.len
    i = walker.position+1
    start = i
    delim = buffer[i-1]

  while i < len:
    let c = buffer[i]
    if c == '\\':
      if not skip and i > start:
        result.add(buffer.substr(start, i-1))

      i += 1
      var extra_c: char
      let esc_c = buffer[i]

      case esc_c
      of 'b':
        extra_c = '\b'
      of 'f':
        extra_c = '\f'
      of 'n':
        extra_c = '\10'
      of 'r':
        extra_c = '\r'
      of 't':
        extra_c = '\t'
      of '"', '/', '\\':
        extra_c = esc_c
      of 'u':
        let code = parseHexInt(buffer.substr(i+1, i+4))
        result.add(Rune(code).toUTF8)
        i += 4
      of 'U':
        let code = parseHexInt(buffer.substr(i+1, i+8))
        result.add(Rune(code).toUTF8)
        i += 8
      else:
        raise parserException(walker, i, "unexpected escape")

      if not skip and extra_c != '\0':
        result.add(extra_c)

      start = i+1
    elif c == delim:
      break
    i += 1

  if not skip and i > start:
    result.add(buffer.substr(start, i-1))

  walker.position = i+1
  walker.process

proc readDatetime*(walker: var TomlWalker): Time =
  if walker.kind != TDatetime:
    raise kindException(walker, "datetime")

  var
    buffer = walker.buffer
    len = buffer.len
    i = walker.position
    num = 0
    parts: array[0..6-1, int]
    pi = 0

  while i < len:
    let c = buffer[i]
    case c:
    of '0'..'9':
      num = num*10 + int(c) - int('0')
    of '-', 'T', ':':
      parts[pi] = num
      num = 0
      pi += 1
    of 'Z':
      break
    else:
      raise parserException(walker, i, "invalid datetime")
    i += 1

  var timeinfo: TimeInfo
  timeinfo.year = parts[0]
  timeinfo.month = Month(parts[1] - 1)
  timeinfo.yearday = parts[2]
  timeinfo.hour = parts[3]
  timeinfo.minute = parts[4]
  timeinfo.second = parts[5]
  result = timeinfo.timeInfoToTime

  walker.position = i+1
  walker.process

proc nextItem*(walker: var TomlWalker): bool =
  if walker.kind != TArray and walker.kind != TDone:
    raise kindException(walker, "array element")

  if walker.kind != TDone:
    walker.process

  if walker.kind == TDone:
    walker.process
    return false
  else:
    return true

proc skip*(walker: var TomlWalker) =
  case walker.kind
  of TTrue, TFalse:
    walker.process
  of TNum:
    walker.skipNonws
  of TString:
    discard walker.readString(skip = true)
  of TDatetime:
    walker.skipNonws
  of TArray:
    while walker.nextItem:
      walker.skip
  else:
    raise kindException(walker, "value")

proc skipSection*(walker: var TomlWalker) =
  while walker.atKey:
    discard walker.readKey(skip = true)
    walker.skip

iterator sections*(walker: var TomlWalker): seq[string] =
  if walker.kind == TKey:
    yield nil

  while not walker.isDone:
    yield walker.readHeader

iterator keys*(walker: var TomlWalker): string =
  while walker.atKey:
    yield walker.readKey

