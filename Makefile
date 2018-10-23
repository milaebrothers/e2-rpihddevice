#
# Makefile for a Enigma2 rpihddevice library
#
# $Id: Makefile 2.18 2013/01/12 13:45:01 kls Exp $

# The official name of this E2 lib.
# By default the main source file also carries this name.

E2LIB = rpihddevice

### The version number of this lib (taken from the main source file):

VERSION = $(shell grep 'static const char \*VERSION *=' $(E2LIB).cpp | awk '{ print $$6 }' | sed -e 's/[";]//g')

### The directory environment:

# Use package data if installed...otherwise assume we're under the VDR source directory:
PKGCFG = $(if $(VDRDIR),$(shell pkg-config --variable=$(1) $(VDRDIR)/vdr.pc),$(shell PKG_CONFIG_PATH="$$PKG_CONFIG_PATH:../../.." pkg-config --variable=$(1) vdr))
LIBDIR = $(call PKGCFG,libdir)
LOCDIR = $(call PKGCFG,locdir)
PLGCFG = $(call PKGCFG,plgcfg)
#
TMPDIR ?= /tmp

### The compiler options:

export CFLAGS   = $(call PKGCFG,cflags)
export CXXFLAGS = $(call PKGCFG,cxxflags)

### The version number of E2's lib API:

APIVERSION = $(call PKGCFG,apiversion)

### Allow user defined options to overwrite defaults:

-include $(PLGCFG)

### The name of the distribution archive:

ARCHIVE = $(E2LIB)-$(VERSION)
PACKAGE = e2-$(ARCHIVE)

### The name of the shared object file:

SOFILE = e2-$(E2LIB).so

### Includes and Defines (add further entries here):

DEFINES += -DPLUGIN_NAME_I18N='"$(E2LIB)"'
DEFINES += -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -DUSE_EXTERNAL_OMX -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM
DEFINES += -Wno-psabi -Wno-write-strings -fpermissive
DEFINES += -D__STL_CONFIG_H

CXXFLAGS += -D__STDC_CONSTANT_MACROS

ILCDIR   =ilclient
VCINCDIR =$(SDKSTAGE)/opt/vc/include
VCLIBDIR =$(SDKSTAGE)/opt/vc/lib
SIGC2LIBDIR =/usr/include/sigc++-2.0
SIGC2LIBDIR2 =/usr/lib/arm-linux-gnueabihf/sigc++-2.0/include

INCLUDES += -I$(ILCDIR) -I$(VCINCDIR) -I$(VCINCDIR)/interface/vcos/pthreads 
INCLUDES += -I$(VCINCDIR)/interface/vmcs_host/linux -I$(SIGC2LIBDIR) -I$(SIGC2LIBDIR2)

LDLIBS  += -lbcm_host -lvcos -lvchiq_arm -lopenmaxil -lGLESv2 -lEGL -lpthread -lrt
LDLIBS  += -Wl,--whole-archive $(ILCDIR)/libilclient.a -Wl,--no-whole-archive
LDFLAGS += -L$(VCLIBDIR)

DEBUG ?= 0
ifeq ($(DEBUG), 1)
    DEFINES += -DDEBUG
endif

DEBUG_BUFFERSTAT ?= 0
ifeq ($(DEBUG_BUFFERSTAT), 1)
    DEFINES += -DDEBUG_BUFFERSTAT
endif

DEBUG_BUFFERS ?= 0
ifeq ($(DEBUG_BUFFERS), 1)
    DEFINES += -DDEBUG_BUFFERS
endif

DEBUG_OVGSTAT ?= 0
ifeq ($(DEBUG_OVGSTAT), 1)
    DEFINES += -DDEBUG_OVGSTAT
endif

ENABLE_AAC_LATM ?= 0
ifeq ($(ENABLE_AAC_LATM), 1)
    DEFINES += -DENABLE_AAC_LATM
endif

# ffmpeg/libav configuration
ifdef EXT_LIBAV
	LIBAV_PKGCFG = $(shell PKG_CONFIG_PATH=$(EXT_LIBAV)/lib/pkgconfig pkg-config $(1))
else
	LIBAV_PKGCFG = $(shell pkg-config $(1))
endif

LDLIBS   += $(call LIBAV_PKGCFG,--libs libavcodec) $(call LIBAV_PKGCFG,--libs libavformat)
INCLUDES += $(call LIBAV_PKGCFG,--cflags libavcodec) $(call LIBAV_PKGCFG,--cflags libavformat)

ifeq ($(call LIBAV_PKGCFG,--exists libswresample && echo 1), 1)
	DEFINES  += -DHAVE_LIBSWRESAMPLE
	LDLIBS   += $(call LIBAV_PKGCFG,--libs libswresample)
	INCLUDES += $(call LIBAV_PKGCFG,--cflags libswresample)
else
ifeq ($(call LIBAV_PKGCFG,--exists libavresample && echo 1), 1)
	DEFINES  += -DHAVE_LIBAVRESAMPLE
	LDLIBS   += $(call LIBAV_PKGCFG,--libs libavresample)
	INCLUDES += $(call LIBAV_PKGCFG,--cflags libavresample)
endif
endif

LDLIBS   += $(shell pkg-config --libs freetype2)
INCLUDES += $(shell pkg-config --cflags freetype2)

### The object files (add further files here):

ILCLIENT = $(ILCDIR)/libilclient.a
OBJS = $(E2LIB).o rpitools.o rpisetup.o omx.o rpiaudio.o omxdecoder.o rpidisplay.o

### The main target:

all: $(SOFILE)

### Implicit rules:

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $(DEFINES) $(INCLUDES) -o $@ $<

### Dependencies:

MAKEDEP = $(CXX) -MM -MG
DEPFILE = .dependencies
$(DEPFILE): Makefile
	@$(MAKEDEP) $(CXXFLAGS) $(DEFINES) $(INCLUDES) $(OBJS:%.o=%.cpp) > $@

-include $(DEPFILE)

### Targets:

$(SOFILE): $(ILCLIENT) $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared $(OBJS) $(LDLIBS) -o $@

$(ILCLIENT):
	$(MAKE) --no-print-directory -C $(ILCDIR) all

install-lib: $(SOFILE)
	install -D $^ $(DESTDIR)$(LIBDIR)/$^.$(APIVERSION)

install: install-lib

dist: $(I18Npo) clean
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@mkdir $(TMPDIR)/$(ARCHIVE)
	@cp -a * $(TMPDIR)/$(ARCHIVE)
	@tar czf $(PACKAGE).tgz -C $(TMPDIR) $(ARCHIVE)
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@echo Distribution package created as $(PACKAGE).tgz

clean:
	@-rm -f $(OBJS) $(DEPFILE) *.so *.tgz core* *~
	$(MAKE) --no-print-directory -C $(ILCDIR) clean

.PHONY:	cppcheck
cppcheck:
	@cppcheck --language=c++ --enable=all --suppress=unusedFunction -v -f .
