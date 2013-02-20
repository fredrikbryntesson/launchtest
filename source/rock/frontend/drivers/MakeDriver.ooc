
// sdk stuff
import io/[File, FileWriter]
import structs/[List, ArrayList, HashMap]

// our stuff
import Driver, SequenceDriver, CCompiler, Flags, SourceFolder

import rock/frontend/[BuildParams, Target]
import rock/middle/Module
import rock/backend/cnaughty/CGenerator

/**
 * Generate the .c source files in a build/ directory, along with a
 * Makefile that allows to build a version of your program without any
 * ooc-related dependency.
 *
 * :author: Amos Wenger (nddrylliog)
 */
MakeDriver: class extends SequenceDriver {

    // the self-containing directory containing buildable C sources
    builddir: File

    // build/Makefile
    makefile: File
    
    // Original output path (e.g. "rock_tmp")
    originalOutPath: File

    init: func (.params) { super(params) }

    setup: func {
        wasSetup := static false
        if(wasSetup) return

        // no lib-caching for the make driver!
        params libcache = false

        // keeping them for later (ie. Makefile invocation)
        params clean = false

        // build/
        builddir = File new("build")

        // build/rock_tmp/
        originalOutPath = params outPath
        params outPath = File new(builddir, params outPath getPath())
        params outPath mkdirs()

        // build/Makefile
        makefile = File new(builddir, "Makefile")

        wasSetup = true
    }

    compile: func (module: Module) -> Int {

        if(params verbose) {
           "Make driver" println()
        }

        setup()

        params outPath mkdirs()

        toCompile := ArrayList<Module> new()
        sourceFolders := collectDeps(module, HashMap<String, SourceFolder> new(), toCompile)
        uses := collectUses(module)

        for(candidate in toCompile) {
            CGenerator new(params, candidate) write()
        }

        params libcachePath = params outPath path
        copyLocals(module, params)

        params libcachePath = originalOutPath path
        params libcache = true
        flags := Flags new(null, params)

        // we'll handle the GC flags ourselves, thanks
        enableGC := params enableGC
        params enableGC = false
        flags absorb(params)
        params enableGC = enableGC

        for (sourceFolder in sourceFolders) {
            flags absorb(sourceFolder)
        }
        params libcache = false

        "Writing to %s" printfln(makefile path)
        fW := FileWriter new(makefile)

        fW write("# Makefile generated by rock, the ooc compiler written in ooc\n\n")
        fW write("CC=%s\n" format(params compiler executableName))

        fW write("# try to determine the OS and architecture\n")
        fW write("MYOS := $(shell uname -s)\n")
        fW write("MACHINE := $(shell uname -m)\n")
        fW write("ifeq ($(MYOS), Linux)\n")
        fW write("    ARCH=linux\n")
        fW write("else ifeq ($(MYOS), FreeBSD)\n")
        fW write("    ARCH=freebsd\n")
        fW write("else ifeq ($(MYOS), OpenBSD)\n")
        fW write("    ARCH=openbsd\n")
        fW write("else ifeq ($(MYOS), NetBSD)\n")
        fW write("    ARCH=netbsd\n")
        fW write("else ifeq ($(MYOS), DragonFly)\n")
        fW write("    ARCH=dragonfly\n")
        fW write("else ifeq ($(MYOS), Darwin)\n")
        fW write("    ARCH=osx\n")
        fW write("else ifeq ($(MYOS), CYGWIN_NT-5.1)\n")
        fW write("    ARCH=win\n")
        fW write("else ifeq ($(MYOS), MINGW32_NT-5.1)\n")
        fW write("    ARCH=win\n")
        fW write("else ifeq ($(MYOS), MINGW32_NT-6.1)\n")
        fW write("    ARCH=win\n")
        fW write("else ifeq ($(MYOS),)\n")
        fW write("  ifeq (${OS}, Windows_NT)\n")
        fW write("    ARCH=win\n")
        fW write("  else\n")
        fW write("    $(error \"OS ${OS} doesn't have pre-built Boehm GC packages. Please compile and install your own and recompile with GC_PATH=-lgc\")\n")
        fW write("  endif\n")
        fW write("endif\n")

        fW write("ifneq ($(ARCH), osx)\n")
        fW write("  ifeq ($(MACHINE), x86_64)\n")
        fW write("    ARCH:=${ARCH}64\n")
        fW write("  else ifeq (${PROCESSOR_ARCHITECTURE}, AMD64)\n")
        fW write("    ARCH:=${ARCH}64\n")
        fW write("  else\n")
        fW write("    ARCH:=${ARCH}32\n")
        fW write("  endif\n")
        fW write("endif\n")

        fW write("# this folder must contains libs/\n")
        fW write("ROCK_DIST?=$(shell dirname $(shell dirname $(shell which rock)))\n")

        fW write("ifeq ($(MYOS), FreeBSD)\n")
        fW write("    GC_PATH?=-lgc\n")
        fW write("else ifeq ($(MYOS), OpenBSD)\n")
        fW write("    GC_PATH?=-lgc\n")
        fW write("else ifeq ($(MYOS), NetBSD)\n")
        fW write("    GC_PATH?=-lgc\n")
        fW write("else ifeq ($(MYOS), DragonFly)\n")
        fW write("    GC_PATH?=-lgc\n")
        fW write("else\n")
        fW write("ifeq (${DYN_GC},)\n")
        fW write("    GC_PATH?=${ROCK_DIST}/libs/${ARCH}/libgc.a\n")
        fW write("else\n")
        fW write("    GC_PATH?=-lgc\n")
        fW write("endif\n")
        fW write("endif\n")

        fW write("CFLAGS+=")

        fW write(" -I ${ROCK_DIST}/libs/headers/ -L/usr/local/lib -L/usr/pkg/lib -I/usr/local/include -I/usr/pkg/include -std=gnu99 -Wall")

        for (flag in flags compilerFlags) {
            fW write(" "). write(flag)
        }
        fW write("\n")

        fW write("EXECUTABLE=")
        if(params binaryPath != "") {
            fW write(params binaryPath)
        } else {
            fW write(module simpleName)
        }
        fW write("\n")

        fW write("OBJECT_FILES:=")

        for (currentModule in toCompile) {
            path := File new(originalOutPath, currentModule getPath("")) getPath()
            fW write(path). write(".o ")
        }

        for (uze in uses) {
            // FIXME: that's no good for MakeDriver - we should write conditions instead
            props := uze getRelevantProperties(params)

            for (additional in props additionals) {
                cPath := File new(File new(originalOutPath, uze identifier), additional relative) path
                oPath := "%s.o" format(cPath[0..-3])
                
                if (params verbose) {
                    "cPath = %s" printfln(cPath)
                    "oPath = %s" printfln(oPath)
                }

                fW write(oPath). write(" ")
            }
        }

        fW write("\n\n.PHONY: compile link\n\n")

        fW write("all: compile link\n\n")

        fW write("compile: ${OBJECT_FILES}")

        fW write("\n\t@echo \"Finished compiling for arch ${ARCH}\"\n")

        fW write("\n\n")

        oPaths := ArrayList<String> new()

        for(currentModule in toCompile) {
            path := File new(originalOutPath, currentModule getPath("")) getPath()
            oPath := path + ".o"
            cPath := path + ".c"
            oPaths add(oPath)

            fW write(oPath). write(": ").
               write(cPath). write(" ").
               write(path). write(".h ").
               write(path). write("-fwd.h\n")

            fW write("\t${CC} ${CFLAGS} -c %s -o %s\n" format(cPath, oPath))
        }

        for (uze in uses) {
            // FIXME: that's no good for MakeDriver - we should write conditions instead
            props := uze getRelevantProperties(params)

            for (additional in props additionals) {
                cPath := File new(File new(originalOutPath, uze identifier), additional relative) path
                oPath := "%s.o" format(cPath[0..-3])

                if (params verbose) {
                    "cPath = %s" printfln(cPath)
                    "oPath = %s" printfln(oPath)
                }

                fW write(oPath). write(": ").
                   write(cPath). write("\n")
                fW write("\t${CC} ${CFLAGS} -c %s -o %s\n" format(cPath, oPath))
            }
        }

        fW write("\nlink: ${OBJECT_FILES}\n")

        fW write("\t${CC} ${CFLAGS} ${OBJECT_FILES} ")

        for(dynamicLib in params dynamicLibs) {
            fW write(" -l "). write(dynamicLib)
        }

        for(libPath in params libPath getPaths()) {
            fW write(" -L "). write(libPath getPath())
        }

        fW write(" -o ${EXECUTABLE}")

        for(linkerFlag in flags linkerFlags) {
            fW write(" "). write(linkerFlag)
        }

        if(params enableGC) {
            if(params dynGC) {
                fW write("-lgc")
            } else {
                arch := params arch equals?("") ? Target getArch() : params arch
                Target toString(arch)
                fW write(" ${GC_PATH}")
            }
            fW write(" -lpthread")
        }

        fW write("\n\n")

        fW write("\nclean:\n")

        fW write("\trm -rf ${OBJECT_FILES}\n")
        fW write("\n\n")

        fW write("\n.PHONY: clean")
        fW write("\n\n")

        fW close()

        return 0

    }

}
