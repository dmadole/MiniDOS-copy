
all: copy.bin

lbr: copy.lbr

clean:
	rm -f copy.lst
	rm -f copy.bin
	rm -f copy.lbr

copy.bin: copy.asm include/bios.inc include/kernel.inc
	asm02 -L -b copy.asm
	rm -f copy.build

copy.lbr: copy.bin
	rm -f copy.lbr
	lbradd copy.lbr copy.bin

