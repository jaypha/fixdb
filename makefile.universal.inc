#
# Universal makefile definitions for any DMD project.
#
# Copyright (C) 2015 Jaypha. Distrbuted under the Boost license.
#

# Development Environment Variables

DC = rdmd

# Main source directory of the project.
ifndef SRCDIR
SRCDIR = .
endif

# Main directory for dub packages.
ifndef DUBDIR
DUBDIR = $(HOME)/.dub/packages
endif

# Directories for libraries
ifndef LIBDIR
LIBDIR = 
endif

# Libraries to be linked
ifndef LIBS
LIBS =
endif

# Dub packages to be compiled in.
ifndef DUB_PACKAGES
DUB_PACKAGES =
endif

# Any other directories that need to be included in the include path
ifndef LOCAL_DEPS
LOCAL_DEPS =
endif


# Compiler defs

ifndef LOCALE 
LOCALE = en
endif

LIBFLAGS= $(addprefix -L-l,$(LIBS)) $(addprefix -L-L,$(LIBDIR))

IMPDIR = $(SRCDIR) \
         $(addprefix $(DUBDIR)/,$(DUB_PACKAGES)) \
         $(LOCAL_DEPS)

JFLAGS = $(addprefix -J,$(IMPDIR))
IFLAGS = $(addprefix -I,$(IMPDIR))

# Common D compiler flags
DFLAGS = $(IFLAGS) -odobj $(JFLAGS) --build-only

# Release compiler flags
RDFLAGS = $(DFLAGS) -release -O -inline

# Debug compiler flags
DDFLAGS = $(DFLAGS) -g -debug

# Linker flags
LFLAGS = $(LIBFLAGS)
