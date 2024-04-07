
copy.prg: copy.asm include/bios.inc include/kernel.inc
	asm02 -L -b copy.asm
	-rm -f copy.build

clean:
	-rm -f copy.lst
	-rm -f copy.bin

