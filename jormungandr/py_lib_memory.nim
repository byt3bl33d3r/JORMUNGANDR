import nimpy/py_lib
import nimpy/py_types
import memorymodule

const MODULE = slurp("resources/python39.dll")

{.pragma: pyfunc, cdecl, gcsafe.}

var pyLibMemory*: PyLib
var pyThreadFrameInitedfromMemory {.threadvar.}: bool

proc isPythonLibHandleinMemory*(h: HMEMORYMODULE): bool {.inline.} =
    let s = MemoryGetProcAddress(h, "PyModule_AddObject")
    not s.isNil

proc deallocPythonObj[TypeObjectType](p: PPyObject) {.gcsafe.} =
  let ob = p.to(PyObjectObj)
  let t = cast[TypeObjectType](ob.ob_type)
  t.tp_dealloc(cast[PPyObject](p))

proc symNotLoadedErr(s: cstring) =
  raise newException(ValueError, "Symbol not loaded: " & $s)

proc loadPyLibFromModuleinMemory(m: HMEMORYMODULE): PyLib =
  assert(not m.isNil)
  result = cast[PyLib](allocShared0(sizeof(result[])))
  let pl = result
  pl.module = m
  if not (MemoryGetProcAddress(m, "PyModule_Create2").isNil or
      MemoryGetProcAddress(m, "Py_InitModule4_64").isNil or
      MemoryGetProcAddress(m, "Py_InitModule4").isNil):
    # traceRefs mode
    pyObjectStartOffset = sizeof(PyObject_HEAD_EXTRA).uint

  template maybeLoad(v: untyped, name: cstring) =
    pl.v = cast[type(pl.v)](MemoryGetProcAddress(m, name))

  template load(v: untyped, name: cstring) =
    maybeLoad(v, name)
    if pl.v.isNil:
      symNotLoadedErr(name)

  template maybeLoad(v: untyped) = maybeLoad(v, astToStr(v))
  template load(v: untyped) = load(v, astToStr(v))

  template loadVar(v: untyped) =
    load(v)
    pl.v = cast[ptr PPyObject](pl.v)[]

  load Py_BuildValue, "_Py_BuildValue_SizeT"
  load PyTuple_New
  load PyTuple_Size
  load PyTuple_GetItem
  load PyTuple_SetItem

  load Py_None, "_Py_NoneStruct"
  load PyType_Ready
  load PyType_GenericNew
  load PyModule_AddObject

  load PyList_New
  load PyList_Size
  load PyList_GetItem
  load PyList_SetItem

  load PyObject_Call
  load PyObject_IsTrue
  # load PyObject_HasAttrString
  load PyObject_GetAttrString
  load PyObject_SetAttrString
  load PyObject_Dir
  load PyObject_Str
  load PyObject_GetIter
  load PyObject_GetItem
  load PyObject_SetItem
  load PyObject_RichCompareBool

  maybeLoad PyObject_GetBuffer
  maybeLoad PyBuffer_Release

  load PyIter_Next

  load PyNumber_Long
  load PyLong_AsLongLong
  load PyLong_AsUnsignedLongLong
  load PyFloat_AsDouble
  load PyBool_FromLong

  load PyBool_Type
  load PyFloat_Type
  load PyComplex_Type
  load PyCapsule_Type
  load PyTuple_Type
  load PyList_Type
  load PyUnicode_Type
  maybeLoad PyBytes_Type
  if pl.PyBytes_Type.isNil:
    # Needed for compatibility with Python 2
    load PyBytes_Type, "PyString_Type"


  maybeload PyUnicode_FromString
  if pl.PyUnicode_FromString.isNil:
    load PyUnicode_FromString, "PyString_FromString"

  load PyType_IsSubtype

  maybeLoad PyComplex_AsCComplex
  if pl.PyComplex_AsCComplex.isNil:
    load PyComplex_RealAsDouble
    load PyComplex_ImagAsDouble

  maybeLoad PyUnicode_CompareWithASCIIString
  if pl.PyUnicode_CompareWithASCIIString.isNil:
    load PyString_AsString

  maybeLoad PyUnicode_AsUTF8String
  if pl.PyUnicode_AsUTF8String.isNil:
    maybeLoad PyUnicode_AsUTF8String, "PyUnicodeUCS4_AsUTF8String"
    if pl.PyUnicode_AsUTF8String.isNil:
      load PyUnicode_AsUTF8String, "PyUnicodeUCS2_AsUTF8String"

  pl.pythonVersion = 3

  maybeLoad PyBytes_AsStringAndSize
  maybeLoad PyBytes_FromStringAndSize
  if pl.PyBytes_AsStringAndSize.isNil:
    load PyBytes_AsStringAndSize, "PyString_AsStringAndSize"
    load PyBytes_FromStringAndSize, "PyString_FromStringAndSize"
    pl.pythonVersion = 2

  load PyDict_Type
  load PyDict_New
  load PyDict_Size
  load PyDict_GetItemString
  load PyDict_SetItemString
  load PyDict_GetItem
  load PyDict_SetItem
  load PyDict_Keys
  load PyDict_Values
  load PyDict_Contains

  if pl.pythonVersion == 3:
    pl.PyDealloc = deallocPythonObj[PyTypeObject3]
  else:
    pl.PyDealloc = deallocPythonObj[PyTypeObject3] # Why does PyTypeObject3Obj work here and PyTypeObject2Obj does not???

  load PyErr_Clear
  load PyErr_SetString
  load PyErr_Occurred

  loadVar PyExc_TypeError

  load PyCapsule_New
  load PyCapsule_GetPointer

  load PyImport_ImportModule
  load PyEval_GetBuiltins
  load PyEval_GetGlobals
  load PyEval_GetLocals

  load PyCFunction_NewEx

  when not defined(release):
    load PyErr_Print

  load PyErr_Fetch
  load PyErr_NormalizeException
  load PyErr_GivenExceptionMatches

  load PyErr_NewException

  loadVar PyExc_ArithmeticError
  loadVar PyExc_FloatingPointError
  loadVar PyExc_OverflowError
  loadVar PyExc_ZeroDivisionError
  loadVar PyExc_AssertionError
  loadVar PyExc_OSError
  loadVar PyExc_IOError
  loadVar PyExc_ValueError
  loadVar PyExc_EOFError
  loadVar PyExc_MemoryError
  loadVar PyExc_IndexError
  loadVar PyExc_KeyError

proc initPyLibfromMemory(m: HMEMORYMODULE) =
  assert(pyLibMemory.isNil)

  #[
  # Setup modules before initialization when not compiled as .so/.dll
  when not compileOption("app", "lib"):
    loadModulesFromThisProcess(m)
  ]#

  let Py_InitializeEx = cast[proc(i: cint){.pyfunc.}](MemoryGetProcAddress(m, "Py_InitializeEx"))
  if Py_InitializeEx.isNil:
    symNotLoadedErr("Py_InitializeEx")

  Py_InitializeEx(0)

  let PySys_SetArgvEx = cast[proc(argc: cint, argv: pointer, updatepath: cint){.pyfunc.}](MemoryGetProcAddress(m, "PySys_SetArgvEx"))
  if not PySys_SetArgvEx.isNil:
    PySys_SetArgvEx(0, nil, 0)

  pyLibMemory = loadPyLibFromModuleinMemory(m)

proc initPyThreadFramefromMemory() =
  #[
  when nimpyTestLibPython.len != 0:
    if unlikely pyLibMemory.isNil:
      echo "Testing libpython: ", nimpyTestLibPython
      pyInitLibPath(nimpyTestLibPython)
  ]#

  # https://stackoverflow.com/questions/42974139/valueerror-call-stack-is-not-deep-enough-when-calling-ipython-embed-method
  # needed for eval and stuff like pandas.query() otherwise crash (call stack is not deep enough)
  if unlikely pyLibMemory.isNil:
    initPyLibfromMemory(MemoryLoadLibrary(MODULE.cstring, MODULE.len))
  pyThreadFrameInitedfromMemory = true

  let
    pyThreadStateGet = cast[proc(): pointer {.pyfunc.}](MemoryGetProcAddress(pyLibMemory.module, "PyThreadState_Get"))
    pyThread = pyThreadStateGet()

  case pyLibMemory.pythonVersion
  of 2:
    if not cast[ptr PyThreadState2](pyThread).frame.isNil: return
  of 3:
    if not cast[ptr PyThreadState3](pyThread).frame.isNil: return
  else:
    doAssert(false, "unreachable")

  let
    pyImportAddModule = cast[proc(str: cstring): pointer {.pyfunc.}](MemoryGetProcAddress(pyLibMemory.module, "PyImport_AddModule"))
    pyModuleGetDict = cast[proc(p: pointer): pointer {.pyfunc.}](MemoryGetProcAddress(pyLibMemory.module, "PyModule_GetDict"))
    pyCodeNewEmpty = cast[proc(str1, str2: cstring; i: cint): pointer {.pyfunc.}](MemoryGetProcAddress(pyLibMemory.module, "PyCode_NewEmpty"))
    pyFrameNew = cast[proc(p1, p2, p3, p4: pointer): pointer {.pyfunc.}](MemoryGetProcAddress(pyLibMemory.module, "PyFrame_New"))

  if not pyImportAddModule.isNil and not pyModuleGetDict.isNil and not pyCodeNewEmpty.isNil and not pyFrameNew.isNil:
    let
      main_module = pyImportAddModule("__main__")
      main_dict = pyModuleGetDict(main_module)
      code_object = pyCodeNewEmpty("null.py", "f", 0)
      root_frame = pyFrameNew(pyThread, code_object, main_dict, main_dict)

    case pyLibMemory.pythonVersion
    of 2:
      cast[ptr PyThreadState2](pyThread).frame = root_frame
    of 3:
      cast[ptr PyThreadState3](pyThread).frame = root_frame
    else:
      doAssert(false, "unreachable")

proc initPyLibfromMemoryIfNeeded*() {.inline.} =
  if unlikely(not pyThreadFrameInitedfromMemory):
    initPyThreadFramefromMemory()
