version = "0.1.0"
author = "Marcello Salvati (@byt3bl33d3r)"
description = "Execute Python from an interpreter embedded within a Nim binary"
license = "BSD"
skipDirs = @["jormungandr"]
bin = @["jormungandr"]

requires "nim >= 0.19.0"
requires "zippy >= 0.5.4"
requires "winim"