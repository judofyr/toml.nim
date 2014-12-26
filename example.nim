import toml
import times

type
  Main = object
    title: string
    person: Person
    database: Database

  Person = object
    name: string
    org: string
    bio: string
    dob: TTime

  Database = object
    server: string
    ports: seq[int]
    isEnabled: bool

var m: Main

var walker: TomlWalker
walker.initWalker(readFile("example.toml"))

proc processMain(walker: var TomlWalker) =
  for key in walker.keys:
    case key:
    of "title":
      m.title = walker.readString
    else:
      walker.skip

proc processPerson(walker: var TomlWalker) =
  for key in walker.keys:
    case key
    of "name":
      m.person.name = walker.readString
    of "organization":
      m.person.org = walker.readString
    of "bio":
      m.person.bio = walker.readString
    of "dob":
      m.person.dob = walker.readDatetime
    else:
      walker.skip

proc processDatabase(walker: var TomlWalker) =
  for key in walker.keys:
    case key
    of "server":
      m.database.server = walker.readString
    of "ports":
      m.database.ports = @[]
      while walker.nextItem:
        m.database.ports.add(int(walker.readInt))
    of "enabled":
      m.database.isEnabled = walker.readBool
    else:
      walker.skip

for path in walker.sections:
  if path.isNil:
    walker.processMain
  elif path[0] == "owner":
    walker.processPerson
  elif path[0] == "database":
    walker.processDatabase
  else:
    walker.skipSection

echo m

