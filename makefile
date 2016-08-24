#
# makefile
#
# Copyright (C) 2016 Jaypha.
#
# Author: Jason den Dulk

PROJDIR = .
SRCDIR = $(PROJDIR)/src

PROJECT = fixdb

EXENAME = makefixdb
EXEDIR = $(DESTDIR)/usr/local/bin


LIBDIR = /usr/lib64/mysql $(DUBDIR)/dyaml-0.5.2
LIBS = mysqlclient dyaml


# Non-dub depedency dir

REPODIR = ~/projects/github/dbsql/src

# Dub packages

DUB_PACKAGES += jaypha-base-1.0.3/src \
                dyaml-0.5.2/source \
                tinyendian-0.1.2/source


# Local project dependencies

LOCAL_DEPS += $(REPODIR)/dbsql/src

all: bin/$(EXENAME)

include $(PROJDIR)/makefile.universal.inc
         
bin/$(EXENAME): src/makefixdb.d src/jaypha/fixdb/literal.d src/jaypha/fixdb/dbdef.d src/jaypha/fixdb/build.d
	$(DC) $(RDFLAGS) $(LFLAGS) -ofbin/$(EXENAME) src/makefixdb.d
	strip bin/$(EXENAME)

install:
	install -d $(EXEDIR)
	cp bin/$(EXENAME) $(EXEDIR)

uninstall:
	sudo rm -f $(EXEDIR)/$(EXENAME)

clean:
	rm bin/$(EXENAME)

