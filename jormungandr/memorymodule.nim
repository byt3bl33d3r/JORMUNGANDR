{.compile: "MemoryModule/MemoryModule.c".}

type
  HMEMORYMODULE* = pointer
  HMEMORYRSRC* = pointer
  HCUSTOMMODULE* = pointer

{.push cdecl, importc, discardable.}

proc MemoryLoadLibrary*(loc: pointer, size: int): HMEMORYMODULE
proc MemoryLoadLibraryEx*(loc: pointer, size: int, allocMemory: pointer, freeMemory: pointer, loadLibrary: pointer, getProcAddress: pointer, freeLibrary: pointer, userdata: pointer): HMEMORYMODULE
proc MemoryGetProcAddress*(mMod: HMEMORYMODULE, pName: cstring): pointer
proc MemoryFreeLibrary*(mMod: HMEMORYMODULE)
proc MemoryCallEntryPoint*(mMod: HMEMORYMODULE): int
proc MemoryFindResource*(a1: HMEMORYMODULE; a2: cstring; a3: cstring): HMEMORYRSRC
proc MemoryFindResourceEx*(a1: HMEMORYMODULE; a2: cstring; a3: cstring; a4: int16): HMEMORYRSRC
proc MemorySizeofResource*(a1: HMEMORYMODULE; a2: HMEMORYRSRC): int32
proc MemoryLoadResource*(a1: HMEMORYMODULE; a2: HMEMORYRSRC): pointer
proc MemoryLoadString*(a1: HMEMORYMODULE; a2: uint; a3: cstring; a4: cint): cint
proc MemoryLoadStringEx*(a1: HMEMORYMODULE; a2: uint; a3: cstring; a4: cint; a5: int16): cint

{.pop.}
