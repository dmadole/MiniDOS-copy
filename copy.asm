
;  Copyright 2023, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


          ; Definition files

          #include include/bios.inc
          #include include/kernel.inc


          ; Unpublished kernel vector points

d_ideread:  equ   0447h
d_idewrite: equ   044ah


          ; Executable header block

            org   1ffah
            dw    begin
            dw    end-begin
            dw    begin

begin:      br    start

            db    5+80h                 ; month
            db    18                    ; day
            dw    2024                  ; year
            dw    3                     ; build

            db    'See github/dmadole/Elfos-copy for more information',0


start:      ldi   0                     ; clear flags
            phi   r9

skipini:    lda   ra                    ; skip any leading spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipini

            sdi   ' '-'-'               ; a dash starts an option
            lbnz  notdash

chkopts:    lda   ra
            smi   'v'
            lbnz  notvopt

            ghi   r9                    ; set the flag for verbose
            ori   1
            phi   r9

            lbr   endopts

notvopt:    smi   'd'-'v'
            lbnz  notdopt

            ghi   r9                    ; set the flag for directory
            ori   2
            phi   r9

            lbr   endopts

notdopt:    smi   'f'-'d'
            lbnz  notfopt

            ghi   r9                    ; set the flag for flags
            ori   4
            phi   r9

            lbr   endopts

notfopt:    smi   't'-'f'
            lbnz  nottopt

            ghi   r9                    ; set the flag for time
            ori   8
            phi   r9

            lbr   endopts

nottopt:    smi   'a'-'t'
            lbnz  dousage

            ghi   r9                    ; set the flag for flags and time
            ori   4+8
            phi   r9

endopts:    lda   ra                    ; see if spaces follow
            lbz   dousage
            sdi   ' '
            lbdf  skipini

            dec   ra                    ; if not check another option
            lbr   chkopts


          ; If not an option, then it is the source path name.
            
notdash:    dec   ra                    ; back up to first space

            ghi   ra                    ; switch to rf to reuse ra
            phi   rf
            glo   ra
            plo   rf

            ldi   srcname.1             ; pointer to source path buffer
            phi   ra
            ldi   srcname.0
            plo   ra

            dec   ra                    ; terminator for scanning backwards
            ldi   '/'
            str   ra
            inc   ra

copysrc:    lda   rf                    ; if only one argument then error
            lbz   dousage

            str   ra                    ; copy until space
            inc   ra
            sdi   ' '
            lbnf  copysrc

            dec   ra                    ; terminate at first space
            ldi   0
            str   ra


          ; Next get the second argument, of the target path name.

skipspc:    lda   rf                    ; skip any leading spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipspc

            dec   rf                    ; back up to first non-space

            ldi   dstname.1             ; pointer to target name buffer
            phi   rb
            ldi   dstname.0
            plo   rb
 
copydst:    lda   rf                    ; if end then all done
            lbz   endargs

            str   rb                    ; else copy until space
            inc   rb
            sdi   ' '
            lbnf  copydst

            dec   rb                    ; terminate at first space
            ldi   0
            str   rb


          ; We now have both arguments, skip any trailing space.

skipend:    lda   ra                    ; skip any trailing spaces
            lbz   endargs
            sdi   ' '
            lbdf  skipend

dousage:    sep   scall                 ; anything else following is error
            dw    o_inmsg
            db    'USAGE: copy [-v] [-d] [-f|-t|-a] source dest',13,10,0

            sep   sret


          ; ------------------------------------------------------------------
          ; We now have all the arguments and options, proceed with the copy.

          ; If the source path does not end in a slash then add one so that
          ; opendir tries to open the path as a directory. Leave RA pointing
          ; to the slash, not the terminator so we know that we added it.

endargs:    dec   ra                    ; if already a slash do nothing
            lda   ra
            smi   '/'
            lbz   slashed

            ldi   '/'                   ; else add a slash
            str   ra
            inc   ra

            ldi   0                     ; terminate but point to slash
            str   ra
            dec   ra


          ; And do the same for the target path but with RB as the pointer.

slashed:    ldi   0
            str   rb

            dec   rb                    ; if already a slash do nothing
            lda   rb
            smi   '/'
            lbz   cheksrc

            ldi   '/'                   ; else add a slash
            str   rb
            inc   rb

            ldi   0                     ; terminate but point to slash
            str   rb
            dec   rb


          ; Try to open the source as a directory using o_opendir. If this
          ; succeeds, then proceed in directory copy mode. Because the path
          ; ends in a slash, it will only open if its a directory.

cheksrc:    ldi   srcfile.1              ; pointer to source fildes
            phi   rd
            ldi   srcfile.0
            plo   rd

            ldi   srcname.1             ; pointer to source name
            phi   rf
            ldi   srcname.0
            plo   rf

            sep   scall                 ; try to open as directory
            dw    opendir
            lbnf  dirmode


          ; If the open failed, then it either does not exist or it is not
          ; a directory. If the path was given with the slash, then the user
          ;  was explicitly specifying a directory, so fail now.

            ldn   ra                    ; fail if slash was given
            lbnz  unslash

            sep   scall                 ; asked for dir but its a file
            dw    o_inmsg
            db    'ERROR: source is not a directory',13,10,0

            sep   sret                  ; return


          ; Otherwise, we added the slash so remove it and try to open the
          ; source as a file instead.

unslash:    ldi   0                     ; overwrite the slash
            str   ra

            ldi   srcname.1             ; pointer to source name
            phi   rf
            ldi   srcname.0
            plo   rf

            ldi   0                     ; ordinary file open
            plo   r7

            sep   scall                 ; if exists then check target
            dw    o_open
            lbnf  filcopy

            sep   sret                  ; it doesn't exist so fail
            dw    o_inmsg
            db    'ERROR: can not open source',13,10,0

            sep   sret


          ; ------------------------------------------------------------------
          ; At this point we know we are doing a single-file copy operation.

          ; Try to open the target as a directory using opendir. If this
          ; succeeds, then copy file into the directory.

filcopy:    ldi   dstfile.1              ; pointer to target fildes
            phi   rd
            ldi   dstfile.0
            plo   rd

            ldi   dstname.1             ; pointer to target name
            phi   rf
            ldi   dstname.0
            plo   rf

            ldi   dstname.1             ; pointer to target name
            phi   rf
            ldi   dstname.0
            plo   rf

            sep   scall                 ; try to open as directory
            dw    opendir
            lbnf  dirdest


          ; If the destination ends with a slash provided by the user, try
          ; to create the directory since it doesn't exist.

            ldn   rb                    ; try as file if we added the slash
            lbnz  tryfile

            sep   scall                 ; try to create directory
            dw    makedir
            lbnf  dirdest

            sep   scall                 ; probably it exists as a file
            dw    o_inmsg
            db    'ERROR: can not create target',13,10,0

            sep   sret                  ; return


          ; The destination is a directory so we need to append the source
          ; filename to it to build the full destination path. Start by
          ; scanning back from end of source to slash or start of string.

dirdest:    ghi   ra                    ; get end of source path
            phi   rf
            glo   ra
            plo   rf

            ldn   rb                    ; overwrite trailing slash
            lbnz  finddir
            dec   rb

finddir:    dec   rf                    ; scan backwards to slash
            ldn   rf
            smi   '/'
            lbnz  finddir

appfile:    lda   rf                    ; append file part to target
            str   rb
            inc   rb
            lbnz  appfile


            ldi   dstname.1             ; pointer to source name
            phi   rf
            ldi   dstname.0
            plo   rf


          ; We are going to try to copy to the target file, either the
          ; one specified originally, or the new one with the source file
          ; name part appended to it, if it was a direcotry. Open the source
          ; file and then call the copy file subroutine.

tryfile:    ldi   0                     ; remove the slash if we added
            str   rb

            ldi   srcfile.1             ; pointer to source fildes
            phi   rd
            ldi   srcfile.0
            plo   rd

            ldi   srcname.1             ; pointer to source name
            phi   rf
            ldi   srcname.0
            plo   rf

            ldi   0                     ; ordinary open for reading
            plo   r7

            sep   scall                 ; open the source file
            dw    o_open
            lbdf  inpfail

            sep   scall                 ; copy the file
            dw    cpyfile

            sep   sret                  ; and return


          ; If the source file could not be opened after all attempts.

inpfail:    sep   scall                 ; can't read the source
            dw    o_inmsg
            db    'ERROR: can not read input file',13,10,0

            sep   sret                  ; return


          ; ------------------------------------------------------------------
          ; We know now that the source is a directory, so the target mush be
          ; a directory also, and we will do a copy of the source contents.

          ; Try to open the destination as a directory. If this fails, then
          ; it doesn't exist and we need to make it, or it is a file.

dirmode:    glo   ra                    ; if just a slash, confirm
            smi   1+srcname.0
            lbz   confirm

            ldn   ra                    ; if user added slash, proceed
            lbz   copydir

confirm:    ghi   r9                    ; if -d option given, proceed
            ani   2
            lbnz  skpslsh

            sep   scall                 ; prompt user
            dw    o_inmsg
            db    'copy files in directory ',0

            ldi   0                     ; remove trailing slash
            str   ra

            ldi   srcname.1             ; get path to name
            phi   rf
            ldi   srcname.0
            plo   rf

            sep   scall                 ; output name
            dw    o_msg

            sep   scall                 ; make it a question
            dw    o_inmsg
            db    '? ',0

            ldi   buffer.1              ; buffer for answer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; get users input
            dw    o_input
             
            sep   scall                 ; move to new line
            dw    o_inmsg
            db    13,10,0

            ldi   buffer.1              ; pointer to input
            phi   rf
            ldi   buffer.0
            plo   rf

            ldn   rf                    ; if confirmed, proceed
            smi   'y'
            lbz   addslsh

            smi   'y'-'Y'               ; else abandon
            lbnz  return

addslsh:    ldi   '/'                   ; add slash back on
            str   ra
skpslsh:    inc   ra


copydir:    ldi   dstfile.1             ; pointer to target fildes
            phi   rd
            ldi   dstfile.0
            plo   rd

            ldi   dstname.1             ; pointer to target name
            phi   rf
            ldi   dstname.0
            plo   rf

          ; The kernel overwrites any trailing slash in o_mkdir so work
          ; around that by positioning to replace it after if needed. Do
          ; it this way so it will still work if o_mkdir is fixed later.

            ldn   rb                    ; point to slash
            lbnz  atslash
            dec   rb

atslash:    sep   scall                 ; if target exists then copy
            dw    opendir
            lbnf  destdir

            sep   scall                 ; else create then copy
            dw    makedir
            lbnf  destdir

            sep   scall                 ; else it must be a file so fail
            dw    o_inmsg
            db    "ERROR: target not a directory",13,10,0

return:     sep   sret                  ; return


          ; The destination directory now exists one way or the other, so
          ; start the directory to directory copy process now.

destdir:    ldi   '/'                   ; fix slash and position after
            str   rb
            inc   rb

            ldn   ra                    ; position after slash
            lbz   nextent 
            inc   ra


          ; Read the next file name entry from the source directory.

nextent:    ldi   srcfile.1             ; pointer to source directory
            phi   rd
            ldi   srcfile.0
            plo   rd

            ldi   dirent.1              ; pointer to buffer for dirent
            phi   rf
            ldi   dirent.0
            plo   rf

            ldi   32.1                  ; each entry is 32 bytes
            phi   rc
            ldi   32.0
            plo   rc

            sep   scall                 ; read next entry
            dw    o_read
            lbdf  dirfail

            glo   rc                    ; if 32 bytes read then copy
            smi   32
            lbz   moredir
 
dirfail:    sep   sret                  ; else end of file


          ; Got a directory entry, if it is empty or if it is a directory,
          ; then skip over it as we only copy files.

moredir:    ldi   dirent.1              ; get pointer to entry
            phi   rf
            ldi   dirent.0
            plo   rf

            lda   rf                    ; if au is zero then not used
            lbnz  entused+0
            lda   rf
            lbnz  entused+1
            lda   rf
            lbnz  entused+2
            lda   rf
            lbnz  entused+3

            lbr    nextent

entused:    inc   rf                    ; move to flags byte
            inc   rf
            inc   rf
            inc   rf
            inc   rf

            ldn   rf                    ; if a directory then skip
            ani   1
            lbnz  nextent


          ; We have a good file entry so make up the full paths by appending
          ; the filename to both the source and destination paths.
          
            ghi   ra                    ; end of source path string
            phi   r7
            glo   ra
            plo   r7

            ghi   rb                    ; end of destination path string
            phi   r8
            glo   rb
            plo   r8

            ldi   (dirent+12).1         ; pointer to name in dirent
            phi   rf
            ldi   (dirent+12).0
            plo   rf

filesrc:    lda   rf                    ; append name to both paths
            str   r7
            inc   r7
            str   r8
            inc   r8
            lbnz  filesrc


          ; Open the input file using the fildes decriptor since the source
          ; descriptor is reading the source directory.

            ldi   tmpfile.1              ; get temporary descriptor
            phi   rd
            ldi   tmpfile.0
            plo   rd

            ldi   srcname.1              ; source with file part added
            phi   rf
            ldi   srcname.0
            plo   rf

            ldi   0                      ; ordinary file open
            plo   r7

            sep   scall                  ; fail if it does not open
            dw    o_open
            lbdf  inpfail

            sep   scall                  ; open the destination and copy
            dw    cpyfile

            lbr   nextent                ; loop back for next entry


          ; ------------------------------------------------------------------
          ; Attempt to create a destination directory, saving RA around it
          ; since there is a kernel issue in Elf/OS 4 and o_mkdir corrupts
          ; that register.

makedir:    ldi   dstname.1             ; get pointer to target name
            phi   rf
            ldi   dstname.0
            plo   rf

            glo   ra                    ; mkdir corrupts ra
            stxd
            ghi   ra
            stxd

            sep   scall                 ; make the directory
            dw    o_mkdir

            irx                         ; restore saved ra
            ldxa
            phi   ra
            ldx
            plo   ra

            sep   sret                  ; return


          ; -----------------------------------------------------------------
          ; Copy a file, assuming the source is already open through the
          ; descriptor pointer to by RD. The destination will be opened
          ; using the target descriptor and name in dstname.

cpyfile:    ghi   r9
            ani   1
            lbz   notverb

            ldi   srcname.1
            phi   rf
            ldi   srcname.0
            plo   rf
      
            sep   scall
            dw    o_msg
            sep   scall

            dw    o_inmsg
            db    ' -> ',0

            ldi   dstname.1
            phi   rf
            ldi   dstname.0
            plo   rf
      
            sep   scall
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    13,10,0

notverb:    glo   rd                    ; save source fildes
            stxd
            ghi   rd
            stxd


          ; If the copy flags or time options are set, then get the flags and
          ; time from the source file from the directory entry. Unfortunately
          ; there isn't currently a way to do this without a sector read.

            ghi   r9                    ; skip if copy options not set
            ani   4+8
            lbz   opendst

            glo   rd                    ; get pointer to dir sector
            adi   9
            plo   rc
            ghi   rd
            adci  0
            phi   rc

            lda   rc                    ; get destination file dir sector
            phi   r8
            lda   rc
            plo   r8
            lda   rc
            phi   r7
            lda   rc
            plo   r7

            ldi   buffer.1              ; pointer to buffer
            phi   rf
            ldi   buffer.0
            plo   rf
   
            sep   scall                 ; load directory sector
            dw    d_ideread
            lbdf  endcopy

            inc   rc                    ; point to flags in buffer
            ldn   rc
            adi   (buffer+6).0
            plo   rf
            dec   rc
            ldn   rc
            adci  (buffer+6).1
            phi   rf

            lda   rf                    ; get flags
            plo   r9

            ldi   datetim.1             ; point to save area
            phi   rc
            ldi   datetim.0
            plo   rc

            ldi   4                     ; length of date and time
            plo   re

savtime:    lda   rf                    ; copy data from source
            str   rc
            inc   rc

            dec   re                    ; repeat for all bytes
            glo   re
            lbnz  savtime


          ; Open the destination file now to receive the copy.

opendst:    ldi   dstname.1             ; destination file name
            phi   rf
            ldi   dstname.0
            plo   rf

            ldi   dstfile.1              ; destination file descriptor
            phi   rd
            ldi   dstfile.0
            plo   rd

            ldi   1+2                   ; create or truncate if needed
            plo   r7

            sep   scall                 ; open the destination file
            dw    o_open
            lbnf  cpyloop

            sep   scall
            dw    o_inmsg
            db    "ERROR: can not create target",13,10,0

            lbr   endcopy


          ; Copy the file one sector-sized buffer at a time from source to
          ; destination using the standard o_read and o_write calls.

cpyloop:    irx                         ; restore source fildes
            ldxa
            phi   rd
            ldx
            plo   rd

            ldi   buffer.1              ; pointer to data buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   512.1                 ; transfer one sector of data
            phi   rc
            ldi   512.0
            plo   rc

            sep   scall                 ; read data, check for error later
            dw    o_read


          ; Switch file descriptors to the destination file, needed whether
          ; we have data to write, or even if we are just closing the file.

            glo   rd                    ; save source fildes
            stxd
            ghi   rd
            stxd

            ldi   dstfile.1              ; get target descriptor
            phi   rd
            ldi   dstfile.0
            plo   rd


          ; If reading the input failed, output a message and stop the copy
          ; at this point, closing the output file without setting flags.

            lbnf  gotread

            sep   scall
            dw    o_inmsg
            db    "ERROR: can not read source",13,10,0

            lbr   endcopy


          ; If read successful but no data returned then we are at end of
          ; file, no need to write, just set flags and close the target.

gotread:    glo   rc
            lbnz  wrtdata
            ghi   rc
            lbz   setflag


          ; The read was good and there is data in the buffer so write it.

wrtdata:    ldi   buffer.1              ; pointer to data buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; write buffer to file
            dw    o_write
            lbnf  chkmore


          ; If write failed then output an error, close the target file and
          ; exit without setting any flags.

            sep   scall
            dw    o_inmsg
            db    "ERROR: can not write target",13,10,0

            lbr   endcopy


          ; If this was a full buffer then there is more data in the file,
          ; loop back and get the next chunk. Otherwise, we are done.

chkmore:    glo   rc                    ; done if less than 512 bytes
            smi   512.0
            ghi   rc
            smbi  512.1

            lbdf  cpyloop               ; loop until done


          ; Close the output file, but first get the address of its directory
          ; sector in case we need to set flags or date on it.

setflag:    glo   rd                    ; get pointer to dir sector
            adi   9
            plo   rc
            ghi   rd
            adci  0
            phi   rc

            lda   rc                    ; get destination file dir sector
            phi   r8
            lda   rc
            plo   r8
            lda   rc
            phi   r7
            lda   rc
            plo   r7

            sep   scall                 ; close destination file
            dw    o_close


          ; If copy flags or time options were set then load the directory
          ; sector of the destination file so we can chance them.

            ghi   r9                    ; copy flags or time not set
            ani   4+8
            lbz   endcopy

            ghi   r9                    ; if not copy flags then dont test
            ani   4
            lbz   loaddir

            glo   r9                    ; else only load if flags are set
            lbz   endcopy

loaddir:    ldi   buffer.1              ; pointer to buffer
            phi   rf
            ldi   buffer.0
            plo   rf
   
            sep   scall                 ; load directory sector
            dw    d_ideread
            lbdf  endcopy

            inc   rc                    ; pointer to flags byte of entry
            ldn   rc
            adi   (buffer+6).0
            plo   rf
            dec   rc
            ldn   rc
            adci  (buffer+6).1
            phi   rf

            ghi   r9                    ; dont set flags if not option
            ani   4
            lbz   settime

            glo   r9                    ; else set flags from source
            str   rf

            ghi   r9                    ; dont set time if not option
            ani   8
            lbz   savflag

settime:    inc   rf                    ; move to date and time

            ldi   datetim.1             ; pointer to saved time
            phi   rc
            ldi   datetim.0
            plo   rc

            ldi   4                     ; four bytes to copy
            plo   re

copytim:    lda   rc                    ; copy date and time
            str   rf
            inc   rf

            dec   re                    ; repeat for four bytes
            glo   re
            lbnz  copytim


          ; If either flags or time was change then write the directory
          ; sector back out to save.

savflag:    ldi   buffer.1              ; pointer to buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; write dir sector back out
            dw    d_idewrite
            lbdf  endcopy


          ; All data has been copied, restore source fildes and return.

endcopy:    irx                         ; restore source fildes
            ldxa
            phi   rd
            ldx
            plo   rd

            sep   sret                  ; return


          ; ------------------------------------------------------------------
          ; The o_open call can't open the root directory, but o_opendir can,
          ; however on Elf/OS 4 it returns a system filedescriptor that will
          ; be overwritten when opening the next file. So we call o_opendir
          ; but then create a copy of the file descriptor in that case.

opendir:    glo   rd                    ; save the passed descriptor
            stxd
            ghi   rd
            stxd

            glo   ra                    ; in elf/os 4 opendir trashes ra
            stxd
            ghi   ra
            stxd

            glo   r9                    ; and also r9
            stxd
            ghi   r9
            stxd

            sep   scall                 ; open the directory
            dw    o_opendir

            irx                         ; restore original r9
            ldxa
            phi   r9
            ldxa
            plo   r9

            ldxa                        ; and ra
            phi   ra
            ldxa
            plo   ra


          ; If opendir failed then no need to copy the descriptor, just 
          ; restore the original RD and return.

            lbnf  success               ; did opendir succeed?

            ldxa                        ; if not restore original rd
            phi   rd
            ldx
            plo   rd

            sep   sret                  ; and return


          ; If RD did not change, then opendir might have failed, or it may
          ; have succeeded on a later version of Elf/OS that uses the passed
          ; descriptor rather than a system descriptor. Either way, return.

success:    ghi   rd                    ; see if rd changed
            xor
            lbnz  changed

            irx                         ; if not, don't copy fildes
            sep   sret


          ; Otherwise, we opened the directory, but have been returned a 
          ; pointer to a system file descriptor. Copy it before returning.

changed:    ldxa                        ; get saved rd into r9
            phi   rf
            ldx
            plo   rf

            ldi   4                     ; first 4 bytes are offset
            plo   re

copyfd1:    lda   rd                    ; copy them 
            str   rf
            inc   rf

            dec   re                    ; until all 4 complete
            glo   re
            lbnz  copyfd1

            lda   rd                    ; next 2 are the dta pointer
            phi   r7
            lda   rd
            plo   r7

            lda   rf                    ; get for source and destination
            phi   r8
            lda   rf
            plo   r8

            ldi   13                    ; remaining byte count in fildes
            plo   re

copyfd2:    lda   rd                    ; copy remaining bytes
            str   rf
            inc   rf

            dec   re                    ; complete to total of 19 bytes
            glo   re
            lbnz  copyfd2

            ldi   255                   ; count to copy, mind the msb
            plo   re
            inc   re

copydta:    lda   r7                    ; copy two bytes at a time
            str   r8
            inc   r8
            lda   r7
            str   r8
            inc   r8

            dec   re                    ; continue until dta copied
            glo   re
            lbnz  copydta

            glo   rf                    ; set copy fildes back into rd
            smi   19
            plo   rd
            ghi   rf
            smbi  0
            phi   rd

            adi   0                     ; return with df cleared
            sep   sret


          ; ------------------------------------------------------------------
          ; Static data definitions follow for the file descriptors used.
          ; These are included in the binary so they are initialized.

srcfile:    db    0,0,0,0
            dw    dta1
            db    0,0,0,0,0,0,0,0,0,0,0,0,0

dstfile:    db    0,0,0,0
            dw    dta2
            db    0,0,0,0,0,0,0,0,0,0,0,0,0

tmpfile:    db    0,0,0,0
            dw    dta3
            db    0,0,0,0,0,0,0,0,0,0,0,0,0


          ; ------------------------------------------------------------------
          ; The following data areas are in static memory following the 
          ; executable but are not included in the executable. They will be
          ; reflected in the header size though so that the kernel will check
          ; that there is enough room before running the program.

datetim:    ds    4                     ; to dave date and time

dirent:     ds    32                    ; directory entry buffer

srcname:    ds    256                   ; path name buffers
dstname:    ds    256

buffer:     ds    512                   ; sector buffer for copies

dta1:       ds    512                   ; data transfer areas for fildes
dta2:       ds    512
dta3:       ds    512

end:        end    begin                ; end of the program

