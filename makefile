DC = rdmd

IMPDIR = /home/jason/projects/spinna/project/src \
         /home/jason/projects/dyaml_0.4/source \
         /home/jason/projects/fixdb/src \
         /home/jason/projects/dbsql/src \
         

BININSTALL = /usr/local/bin

LIBDIR = .
LIBS = dyaml

LIBFLAGS= $(addprefix -L-l,$(LIBS)) $(addprefix -L-L,$(LIBDIR))

JFLAGS = $(addprefix -J,$(IMPDIR))
IFLAGS = $(addprefix -I,$(IMPDIR))

DFLAGS = $(IFLAGS) $(JFLAGS)

RDFLAGS = $(DFLAGS) -release -O
DDFLAGS = $(DFLAGS) -g -debug

LFLAGS = $(LIBFLAGS)


build: bin/makefixdb

bin/makefixdb: src/makefixdb.d src/jaypha/fixdb/literal.d src/jaypha/fixdb/dbdef.d src/jaypha/fixdb/build.d
	$(DC) $(RDFLAGS) $(LFLAGS) -ofbin/makefixdb --build-only src/makefixdb.d
	strip bin/makefixdb

install:
	cp bin/makefixdb /usr/local/bin

clean:
	rm bin/*