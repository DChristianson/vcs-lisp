
DEFAULT_TARGET: all

ROMDIR = roms
ASMS = $(wildcard *.asm) 
SYSTEMS = NTSC PAL60
ROMS = $(foreach ASM, $(ASMS), $(foreach SYSTEM,$(SYSTEMS),$(ROMDIR)/$(ASM:.asm=)_$(SYSTEM).bin))
TIMESTAMP = `date +"%Y%m%d"`
PUBLISHDIR = publish

all: $(PUBLISHDIR) $(ROMDIR) $(ROMS) 

$(PUBLISHDIR):
	mkdir -p $@
	touch $@

$(ROMDIR):
	mkdir -p $@
	touch $@

$(ROMS): $(ASMS)
	$(eval ASM := $(word 2,$(subst _, ,$(subst /, ,$@))))
	$(eval SYSTEM := $(word 2,$(subst ., ,$(subst _, ,$@))))
	dasm $(ASM).asm -Iinclude -p10 -f3 -v4 -o$@ -s$(@:.bin=.sym) -l$(@:.bin=.lst) -MSYSTEM=$(SYSTEM) > $(@:.bin=.log)
	cat $(SYSTEM).script > $(@:.bin=.script)
	cp $@ $(PUBLISHDIR)/$(ASM)_$(SYSTEM)_$(TIMESTAMP).bin

.PHONY: clean
clean:
	rm $(ROMDIR)/*
