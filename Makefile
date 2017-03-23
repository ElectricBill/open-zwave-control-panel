#
# Makefile for OpenzWave Control Panel application
# Greg Satz

# GNU make only

.SUFFIXES:	.cpp .o .a .s

CC     := $(CROSS_COMPILE)gcc
CXX    := $(CROSS_COMPILE)g++
LD     := $(CROSS_COMPILE)g++
AR     := $(CROSS_COMPILE)ar rc
RANLIB := $(CROSS_COMPILE)ranlib

DEBUG_CFLAGS    := -Wall -Wno-unknown-pragmas -Wno-inline -Wno-format -g -DDEBUG -ggdb -O0
RELEASE_CFLAGS  := -Wall -Wno-unknown-pragmas -Werror -Wno-format -O3 -DNDEBUG

DEBUG_LDFLAGS	:= -g

# Change for DEBUG or RELEASE
# The NO_MKSTEMPS indicates to the compiler that mkstemps(3) is unavailable.  The code
# to use calls mktemp instead.  This generates linker warnings.  It is benign but annoying.
CFLAGS	:= -c -std=c++11 $(DEBUG_CFLAGS) # -DNO_MKSTEMPS
LDFLAGS	:= $(DEBUG_LDFLAGS)

# Assume all Z-Wave stuff under our parent directory, library in sibling...
PWD := $(shell pwd)
ZWAVE := $(shell dirname $(PWD))

OPENZWAVE := $(ZWAVE)/open-zwave
LIBZWAVE := -L$(ZWAVE)/open-zwave -lopenzwave
LIBZWAVEARC := $(ZWAVE)/open-zwave/libopenzwave.a

# Locally built vs. installed as binary with package manager, or equiv...
#LIBMICROHTTPD := -L/usr/local/lib/ -lmicrohttpd
LIBMICROHTTPD := -lmicrohttpd

INCLUDES := -I $(OPENZWAVE)/cpp/src -I $(OPENZWAVE)/cpp/src/command_classes/ \
	-I $(OPENZWAVE)/cpp/src/value_classes/ -I $(OPENZWAVE)/cpp/src/platform/ \
	-I $(OPENZWAVE)/cpp/src/platform/unix -I $(OPENZWAVE)/cpp/tinyxml/ \
	-I /usr/local/include/

# gnutls support
GNUTLS := -lgnutls

# for Linux
LIBUSB := -ludev
LIBS := $(LIBZWAVE) $(GNUTLS) $(LIBMICROHTTPD) -lpthread $(LIBUSB) -lresolv

# Installation at
PGMDIR := /usr/local/bin
RUNSHLIBDIR := /usr/local/lib
CONFDIR := /var/lib/ozwcp
RUNDIR := /var/cache/ozwcp
# The user login and id that will run the package
#OZU := ozw
OZUN := 9281 # the most random number evar
OZU := bill
WPORT := 8821 # HTTP service on this port

# for Mac OS X - which I do not have to test with
#ARCH := -arch i386 -arch x86_64
#CFLAGS += $(ARCH)
#LIBZWAVE := $(wildcard $(OPENZWAVE)/cpp/lib/mac/*.a)
#LIBUSB := -framework IOKit -framework CoreFoundation
#LIBS := $(LIBZWAVE) $(GNUTLS) $(LIBMICROHTTPD) -pthread $(LIBUSB) $(ARCH) -lresolv

%.o : %.cpp
	$(CXX) $(CFLAGS) $(INCLUDES) -o $@ $<

%.o : %.c
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $<

all: ozwcp


defs:
ifeq ($(LIBZWAVE),)
	@echo Please edit the Makefile to avoid this error message.
	@exit 1
endif

ozwcp.o: ozwcp.h webserver.h $(OPENZWAVE)/cpp/src/Options.h $(OPENZWAVE)/cpp/src/Manager.h \
	$(OPENZWAVE)/cpp/src/Node.h $(OPENZWAVE)/cpp/src/Group.h \
	$(OPENZWAVE)/cpp/src/Notification.h $(OPENZWAVE)/cpp/src/platform/Log.h

webserver.o: webserver.h ozwcp.h $(OPENZWAVE)/cpp/src/Options.h $(OPENZWAVE)/cpp/src/Manager.h \
	$(OPENZWAVE)/cpp/src/Node.h $(OPENZWAVE)/cpp/src/Group.h \
	$(OPENZWAVE)/cpp/src/Notification.h $(OPENZWAVE)/cpp/src/platform/Log.h

ozwcp:	ozwcp.o webserver.o zwavelib.o $(LIBZWAVEARC)
	$(LD) -o $@ $(LDFLAGS) ozwcp.o webserver.o zwavelib.o $(LIBS)

dist:	ozwcp
	rm -f ozwcp.tar.gz
	tar -c --exclude=".svn" -hvzf ozwcp.tar.gz ozwcp config/ cp.html cp.js openzwavetinyicon.png README

clean:
	rm -f ozwcp *.o

install:
	echo $(ZWAVE)
	cp $(OPENZWAVE)/libopenzwave.so* $(RUNSHLIBDIR)
	chmod ugo+r $(RUNSHLIBDIR)/libopenzwave.so*
	cp ozwcp $(PGMDIR)
	mkdir -p $(RUNDIR)
#	useradd -m -b $(RUNDIR) -s /bin/bash -c "OpenZWave Panel Operation" $(OZU)
	cp *.js *.css cp.html $(RUNDIR)
	mkdir -p $(CONFDIR)
	cp -r $(OPENZWAVE)/config $(CONFDIR)
	rm -f $(RUNDIR)/config # prep for symlink
	ln -s $(CONFDIR) $(RUNDIR)/config
	./genrun $(PGMDIR) $(RUNDIR) $(WPORT) $(RUNSHLIBDIR)
	chown -R $(OZU).$(OZU) $(RUNDIR) $(CONFDIR) $(PGMDIR)/*ozwcp
	chmod u+x $(PGMDIR)/*ozwcp
