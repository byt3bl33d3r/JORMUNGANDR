#[
    References:
        - https://docs.python.org/3/extending/embedding.html
        - https://python.readthedocs.io/en/stable/extending/extending.html
        - https://github.com/pyinstaller/pyinstaller/blob/21f0c5fe7158b31de9937e5ecb09c9c7c75bb312/bootloader/src/pyi_pythonlib.c#L434
        - https://github.com/python/cpython/blob/master/Programs/_testembed.c
        - https://github.com/n1nj4sec/pupy/tree/d82ebd43545d0b4247fce2e8e5154f466f354d4e/client/common

]#

import http
import utils
import memorymodule
import os
import zippy/ziparchives
import streams
import strformat
import tables
import md5

{.pragma: pyfunc, cdecl, gcsafe.}

type
    wchar_t {.importc.} = object
    #[
    Py_ssize_t = int
    PPyObject = distinct pointer
    PyObject = ref object
        rawPyObj: PPyObject

    PyCFunction* = proc(s, a: PPyObject): PPyObject {.cdecl.}

    PyCFunctionWithKeywords* = proc(s, a, k: PPyObject): PPyObject {.cdecl.}

    PyMethodDef* = object
        ml_name*: cstring
        ml_meth*: PyCFunctionWithKeywords
        ml_flags*: cint
        ml_doc*: cstring

    PyObjectObj* {.pure, inheritable.} = object
        # extra: PyObject_HEAD_EXTRA # in runtime depends on traceRefs. see pyAlloc
        ob_refcnt*: Py_ssize_t
        ob_type*: pointer

    PyModuleDef_Base* = object
        ob_base*: PyObjectObj
        m_init*: proc(): PPyObject {.cdecl.}
        m_index*: Py_ssize_t
        m_copy*: PPyObject

    PyModuleDef_Slot* = object
        slot*: cint
        value*: pointer

    PyModuleDef* = object
        m_base*: PyModuleDef_Base
        m_name*: cstring
        m_doc*: cstring
        m_size*: Py_ssize_t
        m_methods*: ptr PyMethodDef
        m_slots*: ptr PyModuleDef_Slot
        m_traverse*: pointer

        m_clear*: pointer
        m_free*: pointer
]#
let
    TMPDIR = os.getEnv("LOCALAPPDATA") 
    pythonStdlibPath = TMPDIR / fmt"{toMD5(getMacAddr())}.zip"

proc isPythonLibHandleinMemory(h: HMEMORYMODULE): bool {.inline.} =
    let s = MemoryGetProcAddress(h, "PyModule_AddObject")
    not s.isNil

proc symNotLoadedErr(s: cstring) =
    raise newException(ValueError, "Symbol not loaded: " & $s)

proc pyExecutionErr(s: string) =
    raise newException(ValueError, "Error occured when executing Python: " & $s)

when defined(amd64):
    const URL = "https://www.python.org/ftp/python/3.9.2/python-3.9.2-embed-amd64.zip"
elif defined(i386):
    const URL = "https://www.python.org/ftp/python/3.9.2/python-3.9.2-embed-win32.zip"

when defined(stageless):
    const STDLIB = slurp("resources/python39.zip")
    const MODULE = slurp("resources/python39.dll")
else:
    var STDLIB, MODULE: string

    let
        archive = ZipArchive()
        dataStream = newStringStream(httpGetRequest(URL))

    archive.open(dataStream)

    for k in archive.contents.keys:
        if k == "python39.dll":
            echo "+ Found python39.dll in zip"
            MODULE = archive.contents["python39.dll"].contents
        elif k == "python39.zip":
            echo "+ Found python stdlib in zip"
            STDLIB = archive.contents["python39.zip"].contents

    archive.clear()

let hPython = MemoryLoadLibrary(MODULE.cstring, MODULE.len)

if not isPythonLibHandleinMemory(hPython):
    symNotLoadedErr("Symbol check failed for Python DLL")

let
    Py_InitializeEx = cast[proc(i: cint){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_InitializeEx"))
    Py_Initialize = cast[proc(){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_Initialize"))
    Py_SetProgramName = cast[proc(str: pointer){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_SetProgramName"))
    PySys_SetArgvEx = cast[proc(argc: cint, argv: pointer, updatepath: cint){.pyfunc.}](MemoryGetProcAddress(hPython, "PySys_SetArgvEx"))
    Py_ImportAddModule = cast[proc(str: cstring): pointer {.pyfunc.}](MemoryGetProcAddress(hPython, "PyImport_AddModule"))
    Py_ModuleGetDict = cast[proc(p: pointer): pointer {.pyfunc.}](MemoryGetProcAddress(hPython, "PyModule_GetDict"))
    Py_CodeNewEmpty = cast[proc(str1, str2: cstring; i: cint): pointer {.pyfunc.}](MemoryGetProcAddress(hPython, "PyCode_NewEmpty"))
    Py_FrameNew = cast[proc(p1, p2, p3, p4: pointer): pointer {.pyfunc.}](MemoryGetProcAddress(hPython, "PyFrame_New"))
    PyRun_SimpleString = cast[proc(command: cstring): cint {.pyfunc.}](MemoryGetProcAddress(hPython, "PyRun_SimpleString"))
    Py_FinalizeEx = cast[proc(): cint {.pyfunc.}](MemoryGetProcAddress(hPython, "Py_FinalizeEx"))
    PyMem_RawFree = cast[proc(str: pointer){.pyfunc.}](MemoryGetProcAddress(hPython, "PyMem_RawFree"))
    Py_SetPath = cast[proc(str: pointer){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_SetPath"))
    Py_GetPath = cast[proc(): ptr wchar_t {.pyfunc.}](MemoryGetProcAddress(hPython, "Py_GetPath"))
    Py_SetPythonHome = cast[proc(home: pointer){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_SetPythonHome"))
    PySys_SetPath = cast[proc(path: pointer){.pyfunc.}](MemoryGetProcAddress(hPython, "PySys_SetPath"))
    Py_DecodeLocale = cast[proc(str: cstring, size: csize_t): ptr wchar_t {.pyfunc.}](MemoryGetProcAddress(hPython, "Py_DecodeLocale"))
    Py_SetStandardStreamEncoding = cast[proc(encoding, errors: cstring): int {.pyfunc.}](MemoryGetProcAddress(hPython, "Py_SetStandardStreamEncoding"))
    #[
    PyEval_GetBuiltins = cast[proc(): PPyObject {.pyfunc.}](MemoryGetProcAddress(hPython, "PyEval_GetBuiltins"))
    PyDict_New = cast[proc(): PPyObject {.pyfunc.}](MemoryGetProcAddress(hPython, "PyDict_New"))
    PyUnicode_FromStringAndSize = cast[proc(u: cstring, size: Py_ssize_t): PPyObject {.pyfunc.}](MemoryGetProcAddress(hPython, "PyUnicode_FromStringAndSize"))
    PyUnicode_FromString = cast[proc(u: cstring): PPyObject {.pyfunc.}](MemoryGetProcAddress(hPython, "PyUnicode_FromString"))
    PyDict_SetItem = cast[proc(p, k, v: PPyObject): cint {.pyfunc.}](MemoryGetProcAddress(hPython, "PyDict_SetItem"))
    PyImport_AppendInittab = cast[proc(name: cstring, initfuncPtr: PPyObject) : cint {.pyfunc.}](MemoryGetProcAddress(hPython, "PyImport_AppendInittab"))
    PyModule_Create = cast[proc(def: pointer): PPyObject {.pyfunc.}](MemoryGetProcAddress(hPython, "PyModule_Create"))
    Py_DECREF = cast[proc(o: PPyObject){.pyfunc.}](MemoryGetProcAddress(hPython, "Py_DECREF"))
    ]#

var
    Py_FileSystemDefaultEncoding = MemoryGetProcAddress(hPython, "Py_FileSystemDefaultEncoding")
    Py_IgnoreEnvironmentFlag = MemoryGetProcAddress(hPython, "Py_IgnoreEnvironmentFlag")
    Py_NoSiteFlag = MemoryGetProcAddress(hPython, "Py_NoSiteFlag")
    Py_NoUserSiteDirectory = MemoryGetProcAddress(hPython, "Py_NoUserSiteDirectory")
    Py_OptimizeFlag = MemoryGetProcAddress(hPython, "Py_OptimizeFlag")
    Py_IsolatedFlag = MemoryGetProcAddress(hPython, "Py_IsolatedFlag")
    Py_DontWriteBytecodeFlag = MemoryGetProcAddress(hPython, "Py_DontWriteBytecodeFlag")

proc extractStdlib*(path: string) =
    var archive = ZipArchive()
    let stdlibStream = newStringStream(STDLIB)

    archive.open(stdlibStream)
    archive.extractAll(path)
    archive.clear()

proc runSimpleString*(script: cstring, name: string = "JORMUNGANDR") = 
    let
        program = Py_DecodeLocale(name, 0)
        resource_path = Py_DecodeLocale(pythonStdlibPath, 0)
        python_home = Py_DecodeLocale("", 0)
        sys_path = Py_DecodeLocale("", 0)

    if program.isNil:
        pyExecutionErr("Py_DecodeLocale returned null")

    if not os.fileExists(pythonStdlibPath):
        echo "* Writing Python stdlib to ", pythonStdlibPath
        writeFile(pythonStdlibPath, STDLIB)
    else:
        echo "+ Found Python stdlib already present"

    Py_SetProgramName(program)
    Py_SetPythonHome(python_home)
    discard Py_GetPath()
    Py_SetPath(resource_path)

    #cast[ptr cstring](Py_FileSystemDefaultEncoding)[] = "mbcs"
    #dump cast[ptr cstring](Py_FileSystemDefaultEncoding)[]
    cast[ptr cint](Py_IgnoreEnvironmentFlag)[] = 1
    cast[ptr cint](Py_NoSiteFlag)[] = 1
    cast[ptr cint](Py_NoUserSiteDirectory)[] = 1
    cast[ptr cint](Py_OptimizeFlag)[] = 2
    cast[ptr cint](Py_DontWriteBytecodeFlag)[] = 1
    cast[ptr cint](Py_IsolatedFlag)[] = 1

    discard Py_SetStandardStreamEncoding(nil, nil)
    Py_InitializeEx(0)
    #Py_Initialize()
    PySys_SetPath(resource_path)

    discard PyRun_SimpleString(script)

    if Py_FinalizeEx() < 0:
        pyExecutionErr("- Py_FinalizeEx returned non-zero value")

    PyMem_RawFree(program)

#[
proc createPyDict*() =
    echo "Creating"
    echo PyDict_New.isNil
    var obj = PyDict_New()

    echo "Assigning key"
    var k = PyUnicode_FromString("test".cstring)

    echo "Assigning value"
    var v = PyUnicode_FromString("wat".cstring)

    echo "Setting"
    echo PyDict_SetItem(obj, k, v)

    echo "DECREF"
    Py_DECREF(k)
    Py_DECREF(v)
]#