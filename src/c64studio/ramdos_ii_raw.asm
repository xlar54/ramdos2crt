;
; change list after v1.0
;
;version .macro      ; declare 3 char version here
;  .byte "4.3"
;  .endm
;
; when     who  version what
; --------   ---  ----  ---------------------------------------------
; 11/08/18  scott hutter V4.3b   This version is a RAW memory dump of the
; code, disassembled.  It has many flaws but does work and will 
; compile.  The original v4.3 source code has apparently been
; lost in time. I am using the original c128devpak ramdos code
; to recreate this code with labels for c64studio.
;
; You can load and run the code with this basic program
;
;  0 if a=0 then a=1:sys65418:load"ramdos.bin",8,1
;  5 u=15:p=207:ml=25344:l=6:m=0
;  40 poke 780,u
;  50 poke 781,p
;  60 sys ml+l+m
;  70 print "ramdisk loaded as device 15"
;
;  it can also be modified and loaded to run in 128 mode

; 11/13/87   fab  V4.3  Added patch to correctly handle CLOSE for
;       C128 opration.  Patch added to match posted
;       version of RAMDOS128.BIN.
;
; 10/26/87   fab  V4.2  RBASIN did not check for prior status error-
;       added code at DISK_IO to exit if bad status.
;       This caused a problem especially for Relative
;       file reads of empty records.
;
;       EOF_CHECK did not preserve prior status-
;       added  ora status/ sta status.  This caused a
;       problem for file read loops expecting some kind
;       of error status when past end of file.
;
;       READ_BYTE did not set TIMEOUT status bit, and
;       now it does (eg, read past EOF & you get ST=66).
;
;       Relative file writes did not report OVERFLOW
;       if given too much data for one record, and
;       instead placed the excess data into subsequent
;       records.  Changed write_byte_rel to properly
;       update current record only and report error.
;       Fix assumes that a chkin/out implies a prior
;       clrchn was performed.
;
;       CLOSEing the command channel now closes all
;       other user channels on disk side, as it should.
;       Also, for C128 mode only, the status of carry
;       is important as it should be (i.e., c=1 means
;       not a real CLOSE, just remove crap from tables).
;
; 8/26/87    fab  V4.1  Added NEW command.  Simply sets disk_end=start.
;
;       Added range check to set_unit_number (4-30).
;
;       F access command string failed when a parameter
;       was equal to <CR>.  It's okay now.
;
;       Added code to strip trailing <CR> if any from
;       any filename processed by init_get_filename.
;
; 8/24/87    hcd  V4.0  added 'F' access ( as opposed to 'RWMA' ).
;
;       F access allows both reading and writing a
;       file like sequential read and sequential
;       write access. The file pointer merely points to
;       the byte to operate on for reads or writes.
;
;       F access is legal for SEQ or PRG files only.
;
;       F access allows the POSITION command to be used
;       to position the r/w head at any byte in the 
;       file. Positioning the head past the end of the
;       file causes the file to be expanded, $FF is the
;       padding char.
;
;       The format for the F access version of the
;       position command is:
;
;         P:<channel><lpage><hpage>[<byte>]
;
;       where:
;
;         <channel> is the file's channel
;         <hpage><lpage><byte> is a three byte
;         pointer into the file. Three nulls
;         would point the the first byte in the 
;         file.
;
;         <byte> is optional, if omitted it
;         defaults to zero.
;
;         Note the odd order for the arguements.
;
;
;
; 8/20/87    hcd  V3.6    added flush block call to read_byte_default.
;       This is required before all DMAs directly
;       to disk ram. Its omission had caused strange
;       happenings when a file was opened for write,
;       and a previously open read file was then opened.
;
;       The rule is that any system calls which 
;       access disk memory directly ( as opposed to
;       accessing disk memory via the default page ),
;       must flush the default block before execution,
;       and must unflush the block after execution.
;
;       added flush block to do_load also.
;
;       Corrected "FILE TOO LARGE" mispelling.
;
;       Fixed bug with cleanup command write call
;       to interpret command. Bad commands would
;       shown errors because the command would be
;       interpreted ( via cleanup ), then the commands
;       cr would be interpreted as an ok command
;       clearing the error channel. Fix was implemented
;       by causeing commands of a single <cr> to
;       have no effect on error channel.
;
;       Caused serial buss timeout bit to be set when
;       an attempt to read past the end of a file
;       occurs. This is to accomodate BASIC7.0 DOS
;       input command which is not satisfied by a
;       simple EOF status.
;
; 7/20/87    hcd  V3.5    BA ( the system bank variable ) was corrected
;       to reflect the proper address. It was $cb.
;       It is $c6.
;
;       Corrected "FILE NAME EXSISTS" mispelling.
;
;       Corrected "FILES SCRATCHED" error message
;       where the number of files scratched was
;       incorrect.
;
;       Removed enhancement allowing for files 
;       > 10K block long. This causes the
;       directory format display to be correct.
;       ( filenames were shifted one char right )
;
;       Caused cleanup_command_write to force any
;       command in buffer to interpreted. This is
;       in line with serial buss standard that clrch
;       can terminate a command.
;
; 5/27/87    hcd  V3.4  corrected save bug (saved 1 too many bytes
;       causing load to load 1 too many)
;
; 4/8/87     hcd  V3.3  corrected bug in sniff_disk_size which
;       smelled 512k when only 256k exsisted
;       on some ramdisk units. (erp)
;
; 11/12/86   hcd  V3.2  added copyright message to jump vectors.
;       corrected error 73 text to include Vx.x 
;       correctly from version macro.
;
; 11/11/86   hcd  V3.1  added USR files.
;       corrected error in M-W for unit change.
;       corrected pattern matching bug where ending *
;       in filename may mean 0-n chars.
;
;
c64  = 1          ; define this flag to force c65 assy
rel_flag =1       ; define this flag to enable rel file code....
position_flag =1  ; define this flag to allow position command on
                  ; program and relative files.
;
;
;!ifdef position_flag {
;  !ifndef rel_flag {
;  *** error *** illegal to assemble with position and no rel files
;  }
;}
;
!ifdef  c64 {
  ;.nam  C64 RAMDISK DOS
  default_unit_number = $08       ; unit 8
  default_interface_page  = $cf   ; place for interface page
  swapped_dos_base  = $6000       ; install the dos here....
} else {
  ;.nam  C128 RAMDISK DOS
  default_unit_number = $09       ; unit 9
  default_interface_page  = $0e   ; place for interface page
  down_load_area    = $3e4        ; start of down load area
  swapped_dos_base  = $2000       ; install the dos here....
}

curzpg  = $fe
curram  = swapped_dos_base
code_start = swapped_dos_base+$300
swapped_code_start = swapped_dos_base
swapped_code_size = $1fff

* = swapped_dos_base
data_block
!fill 256, $00

;
dir_filelen   = data_block      ; number of blocks for this file
dir_access    = data_block+2    ; access char if open, null otherwise ( R,W,L,$ )
dir_filetype  = data_block+3    ; type char for file ( S,P,L )
dir_last_byte = data_block+4    ; pointer to last byte
dir_end_record= data_block+5    ; two bytes indicating number of rel file records
dir_record_len= data_block+7    ; record length for rel files
dir_filename  = data_block+8
;       use rest of file for data
dir_data_start        = dir_filename+18
dir_data_offset       = dir_data_start-data_block
dir_load_addr         = dir_data_offset+data_block
dir_load_data_offset  = dir_data_offset+2
;
first_block
!fill 2, $00                    ; pointer to location of first data
                                ; on disk after dos code and ram
disk_end
!fill 2, $00                    ; pointer to one past last data block in disk
                                ; ( if disk_end == first_block then disk empty )
disk_max
!fill 2, $00                    ; highest legal value for disk_end
                                ; this is the number of blocks on the disk
channel_blocks
!fill 2, $00                    ; this stores the pointer to channel
                                ; storage on disk ( less than first block )
default_channel_number  
!byte $00                       ; current channel in default_channel
;
cleanup_vector
!fill 2, $00                    ; pointer to cleanup routine for fastop

default_channel = curram

channel_access
!fill 1, $00                    ; ( R,W,L,$ ) read/write/relative/directory
directory_block
!fill 2, $00                    ; ( first_block - 1 )
current_byte
!byte $00
current_block
!fill 2, $00                    ; point directly to next byte
end_byte
!byte $00
end_block
!fill 2, $00                    ; point directly to last byte

!ifdef rel_flag {
current_record_byte
!byte $00                       ; rel file, current byte in record
current_record
!fill 2, $00                    ; index of current record
current_record_len
!byte $00                       ; length of current record
                                ; ram rel_write_flag  flag for interface to disk_unlsn for rel only
end_record
!fill 2, $00                    ; index of last record in rel file
record_len    
!byte $00                       ; length of physical record
}
default_channel_end
channel_len = curram-default_channel ; used to allocate channels

;
default_block
!fill 2, $00                    ; current block in the data_block buffer
;
pntr
!fill 2, $00                    ; all I want is a pointer to use
pntr_save
!fill 2, $00                    ; save this too shithead....
;
;
eof_flag
!byte $00                       ; internal eof flag
data_byte
!byte $00                       ; data byte buffer
interface_page
!byte $00                       ; page number of the dma interface block
disk_fa
!byte $00                       ; our unit number ( can you say 9 )
alt_filename
!fill 17, $00                   ; alternate filename for copy/rename
;

;
;************************************************************************
;   DMA DECLARES
;************************************************************************
;
;
!ifndef c64 {
mmucr   = $ff00     ; mmu configuration 
mmurcr  = $d506
}
;
dma = $DF00         ; base of dma unit
vicspeed = $d030    ; must do for c64 mode on c128
;
dma_status  = dma   ; dma status
;   b7  - irq pending
;   b6  - dma complete
;   b5  - block verify error
;   b4  - size register
;   b3-0  - version
;
dma_cmd = dma+1     ; dma command
; b7 =1   arm transfer
; b6  
; b5 =1 autoload enable
; b4 =1 disable $ff00 decode
; b3  
; b2  
; b1:b0
;   00  write c128 --> disk
;   01  read  c128 <-- disk
;   10  swap  c128 <-> disk
;   11  compare c128 == disk
;
dma_immediate_write   = %10110000
dma_immediate_read    = %10110001
dma_immediate_swap    = %10110010
dma_immediate_compare = %10110011
;
dma_banked_write      = %10100000
dma_banked_read       = %10100001
dma_banked_swap       = %10100010
dma_banked_compare    = %10100011
;
dma_fastop_write      = %10010000
dma_fastop_read       = %10010001
;
dma_cpu_addr          = dma+2   ; c128 addr
dma_disk_addr         = dma+4   ; disk low order adder
dma_disk_block        = dma+5   ; disk block ( two bytes )
dma_disk_bank         = dma+6   ; disk bank
dma_len               = dma+7   ; two bytes for length of transfer
dma_ifr               = dma+9   ; interupt mask register
dma_acr               = dma+10  ; address_control_register

;************************************************************************
;   CODE START
;************************************************************************
;

* = code_start

JMP l7d99 ; INSTALL AT DEFAULT LOCATION
JMP l7dde ; REINSTALL AT DEFAULT LOCATION
JMP l7d9d ; INSTALL ANYWHERE
JMP l7de2 ; REINSTALL ANYWHERE
JMP l630f ; COPYRIGHT MESSAGE

;************************************************************************
;   EQUATES
;************************************************************************
;
cr  = $0d
;
; kernal_declares
;
status  = $90
svxt    = $92
verck   = $93
ldtnd   = $98
dfltn   = $99
dflto   = $9a
eal     = $ae
eah     = $af
fnlen   = $b7
la      = $b8
sa      = $b9
fa      = $ba
fnadr   = $bb
stal    = $c1
stah    = $c2
memuss  = $c3

!ifndef c64 {
ba      = $c6
fnbank  = $c7
}

inmi    = $0318
iopen   = $031a
iclose  = $031c
ichkin  = $031e
ickout  = $0320
iclrch  = $0322
ibasin  = $0324
ibsout  = $0326
; istop
igetin  = $032a
iclall  = $032c
; exmon
iload   = $0330
isave   = $0332
;
d1prb   = $dc01 ; key scan port
d1ddrb  = $dc03 ; key scan port ddr
d2icr   = $dd0d ; icr for nmni 6526


!ifdef c64 {
fat         = $0263
;
print       = $e716 ; direct entry to screen printer.
;
cheap_open  = $f34a
jxrmv       = $f2f2 ; remove lat fat sat entry whose index is in .a
lookup      = $f30f   
jltlk       = $f314
getlfs      = $f31f ; jz100
;
_luking     = $f5af ; print looking for filename
loding      = $f5d2 ; print loading
_saving     = $f68f ; print saving filename
;
no_restor_restore = $fe69 ; run stop restore less the restor....
fake_nmi    = $fe72 ; calls nmi232, and does a prend...
;
kernal_error= $f715 ; kernal error handler
ud60        = $f6bc
;
} else {
;
fat         = $036c
;
system_vector= $0a00
;
print       = $c00c ; direct entry into screen print...
;
cheap_open  = $efbd
jxrmv       = $f1e5 ; remove lat fat sat entry whose index is in .a
lookup      = $f202
jltlk       = $f207
getlfs      = $f212
;
_luking     = $f50f ; print looking for filename
loding      = $f533 ; print loading
_saving     = $f5bc ; print saving filename
;
no_restor_restore = $fa56 ; run stop restore less the restor....
fake_nmi    = $fa5f ; calls nmi232, and does a prend...
;
kernal_error= $f699 ; kernal error handler
fnadry      = $f7ae ; indirect load file name address
getcfg      = $ff6b ; .a <= mmu setting for config .x
ud60        = $f63d
;
}
;
cint    = $ff81
ioinit  = $ff84
restor  = $ff8a
clrch   = $ffcc
stop    = $ffe1
;
;
;************************************************************************
;   COPYRIGHT MESSAGE
;************************************************************************
;
l630f   LDX #$00
l_10    TXA 
        PHA 
        LDA l6321,X
        JSR print
        PLA 
        TAX 
        INX 
        CPX #$45
        BNE l_10
        RTS 
;;
l6321 !text $0D, "(C) 1986 COMMODORE ELECTRONICS", $0D, $0D
      !text $0D, "2MB PATCH BY ANDREW E MILESKI 1991", $0D, $00

l6367 !text "OK", $00, $01
      !text "FILES SCRATCHED", $00, $0d
      !text "DOS CONFUSED", $00, $1E
      !text "SYNTAX ERROR", $00, $1F
      !TEXT "SYNTAX ERROR", $00, $20
      !TEXT "SYNTAX ERROR", $00, $21
      !TEXT "SYNTAX ERROR", $00, $22
      !TEXT "SYNTAX ERROR", $00, $32
      !TEXT "RECORD NOT PRESENT", $00, $33
      !TEXT "OVERFLOW IN RECORD", $00, $34
      !TEXT "FILE TOO LARGE", $00, $3C
      !TEXT "FILE OPEN", $00, $3D
      !TEXT "FILE NOT OPEN", $00, $3E
      !TEXT "FILE NOT FOUND", $00, $3F
      !TEXT "FILE EXISTS", $00, $40
      !TEXT "FILE TYPE MISMATCH", $00, $42
      !TEXT "ILLEGAL TRACK AND SECTOR", $00, $46
      !TEXT "NO CHANNEL", $00, $48
      !TEXT "DISK FULL", $00, $49
      !TEXT "CBM DOS V4.3 17XX", $00, $00
      !TEXT "BAD ERROR NUMBER", $00

;error_cleanup  
l64A8 CLC 
      ADC $6169
      STA $6169
      RTS

;read_error_channel  
      LDX $6169
      CPX $616A
      BCC $64BF
      JSR $655F
      CLC 
      JMP $7995

      LDA #$A8
      LDX #$64
      STA cleanup_vector
      STX cleanup_vector + 1
      LDA #$37
      LDX #$01
      CLC 
      ADC $6169
      BCC $64D4
      INX 
      STA $DF04
      STX $DF05
      LDA #$00
      JSR $7EB0
      LDA $616A
      SEC 
      SBC $6169
      LDX $62F5
      LDY $62F6
      SEC 
      JMP $7AE2
      
      STA $616B

      ;error_channel_scratch_set_up
      STX $616C
      LDY #$01
      JSR $6580
      LDA #$00
      STA $616F
      LDA #$10
      LDX #$27
      JSR $6523
      LDA #$E8
      LDX #$03
      JSR $6523
      LDA #$64
      LDX #$00
      JSR $6523
      LDA $616B
      JSR $65A6
      JSR $65D4
      LDA #$00
      JMP $65A6


      STA $616D
      STX $616E
      LDA $616F
      AND #$F0
      STA $616F
      LDA $616B
      SEC 
      SBC $616D
      TAX 
      LDA $616C
      SBC $616E
      BCC $6553
      STA $616C
      STX $616B
      LDA $616F
      ADC #$00
      ORA #$30
      STA $616F
      BNE $6531
      LDA $616F
      BEQ $655B
      JSR $65D6
      RTS 


      LDY #$49
      BIT $00A0
      LDA #$00
      TAX 
      JMP $656E
      TAY 
      LDA current_block
      LDX current_block + 1
      JSR $6580
      LDA $6135
      JSR $65A6
      JSR $65D4
      LDA $6136
      JMP $65A6
      STY $6134
      STX $6135
      STA $6136
      LDA #$00
      STA $6169
      STA $616A
      LDA $6134
      JSR $65A6
      JSR $65D4
      LDA #$20
      JSR $65D6
      JSR $65EA
      JSR $65D4
      RTS 


      CMP #$64
      BCC $65C0
      CMP #$C8
      BCC $65B6
      SBC #$C8
      PHA 
      LDA #$02
      JMP $65BC
      SEC 
      SBC #$64
      PHA 
      LDA #$01
      JSR $65D1
      PLA 
      LDX #$FF
      INX 
      SEC 
      SBC #$0A
      BCS $65C2
      PHA 
      TXA 
      JSR $65D1
      PLA 
      CLC 
      ADC #$0A
      ORA #$30
      BIT $2CA9
      LDX $616A
      STA $6137,X
      CPX #$30
      BEQ $65E3
      INC $616A
      LDA #$00
      STA $6138,X
      CLC 
      RTS 


      LDA #$66
      LDX #$63
      STA $FE
      STX $FF
      LDA $6134
      LDX #$00
      CMP ($FE,X)
      BEQ $6600
      JSR $660D
      BNE $65F2
      JSR $6612
      BEQ $660B
      JSR $65D6
      JMP $6600
      CLC 
      RTS 


      JSR $6612
      BNE $660D
      INC $FE
      BNE $6618
      INC $FF
      LDX #$00
      LDA ($FE,X)
      RTS 
;******************************************************************
;   SELECT_CHANNELS
;******************************************************************
;
num_channels = 17
directory_channel = 16
;
init_channels
      LDX #$10
      TXA 
      JSR $663F
      JSR $662D
      LDX $6108
      DEX 
      BPL $661F
      RTS 

clear_channel   ; set all channel data to zero
      LDX #$0F
      LDA #$00
      STA $610B,X
      DEX 
      BPL $6631
      RTS 

select_channel_given_sa
      LDA $B9
      AND #$0F
      !byte $2c
;
select_dir_channel
      lda #16
      
select_channel_a
      CMP $6108
      BEQ $6670
      PHA 
      LDA #$0B
      LDX #$61
      STA $DF02
      STX $DF03
      LDA channel_blocks + 1
      JSR $7EB0
      LDA #$10
      LDX #$00
      STA $DF07
      STX $DF08
      LDA $6108
      LDY #$B0
      JSR $6678
      PLA 
      STA $6108
      LDY #$B1
      JSR $6678
      LDA $6108
      LDX $610B
      CLC 
      RTS 


      ASL A
      TAX 
      LDA $668D,X
      STA $DF04
      LDA $668E,X
      ADC channel_blocks
      STA $DF05
      STY $DF01
      RTS 

      !byte $00,$00
      BPL $6691
      JSR $3000
      !byte $00
      RTI 
      !byte $00
      BVC $6699
      RTS 
      !byte $00
      BVS $669D
      !byte $80, $00 
      BCC $66A1
      LDY #$00
      BCS $66A5
      CPY #$00
      BNE $66A9
      CPX #$00
      BEQ $66AD
      !byte $00, $01, $8D, $0f, $61, $8E
      BPL $6716
      LDA current_block
      LDX current_block + 1
      CPX default_block + 1
      BNE $66C3
      CMP default_block
      BEQ access_block_ret
      PHA 
      TXA 
      PHA 
      JSR $66D7
      PLA 
      TAX 
      PLA 
      STA default_block
      STX default_block + 1
unflush_block   ; read the new default block in.
      LDY #$B1
      BIT $B0A0
      JSR $66ED
      LDA default_block
      LDX default_block + 1
      STA $DF05
      JSR $7EB7
      STY $DF01
access_block_ret
      CLC 
      RTS 

dma_data_block_setup    ; set up dma controller for data block
      LDX #$0A
      LDA $66F9,X
      STA $DF02,X
      DEX 
      BPL $66EF
      RTS 

      !byte $00, $60, $00,$00,$00,$00,$01,$00,$00,$00,$00
      
;**************************************************************************
;   READ BYTE
;**************************************************************************
;
;
read_byte_given_sa      
      JSR $6638
      CMP #$0F
      BNE $670E
      JMP $64B0
      CPX #$00
      BNE $671B
      LDA #$46
      STA $90
      LDA #$46
      JMP $7992
      CPX #$24
      BNE $673A
      JMP $7458
read_byte_default_cleanup
      TAY 
      BEQ $6739
      CLC 
      ADC $610E
      STA $610E
      BCC $6736
      INC current_block
      BNE $6736
      INC current_block + 1
      JSR $66D4
      RTS 
;
;
;
read_byte_default
;
      LDA $610B
      CMP #$52
      BEQ $6751
      CMP #$46
      BEQ $6751
      CMP #$4C
      BNE $674C
      JMP $6A0E
      LDA #$3C
      JMP $7992
      SEC 
      LDA $6111
      SBC $610E
      TAY 
      LDA $6112
      SBC current_block
      TAX 
      LDA $6113
      SBC current_block + 1
      BCS $676B
      JMP $7989
      BNE $6770
      TXA 
      BEQ $6772
      LDY #$FF
      TYA 
      PHA 
      JSR $66D7
      PLA 
      TAY 
      BNE $6780
      LDA #$40
      STA $90
      INY 
      LDA #$22
      LDX #$67
      SEC 
      JMP $7AC7
;**************************************************************************
;   WRITE_BYTE
;**************************************************************************
;
write_byte_given_sa
      JSR $6638
      CMP #$0F
      BNE $6792
      JMP $7184
      CPX #$57
      BEQ $67DA
      CPX #$46
      BEQ $67DA
      CPX #$4C
      BNE $67A1
      JMP $6A43
      LDA #$46
      JMP $7992
      TAY 
      BEQ $67D7
      DEY 
      TYA 
      CLC 
      ADC $610E
      STA $610E
      LDX current_block + 1
      CPX $6113
      BNE $67C0
      LDX current_block
      CPX $6112
      BNE $67CA
      CMP $6111
      BCC $67CA
      STA $6111
      INC $610E
      BNE $67D7
      INC current_block
      BNE $67D7
      INC current_block + 1
      JMP $66D4
;
;
write_byte_default
;
      JSR $67FB
      BCS $67EA
      LDA #$00
      SEC 
      SBC $610E
      CMP #$00
      BNE $67ED
      CLC 
      JMP $79A3
      PHA 
      JSR $66D7
      PLA 
      TAY 
      LDA #$A6
      LDX #$67
      CLC 
      JMP $7AC7
;
;
; write_byte_immediate
;   writes data byte to current file at current file pointer
;   also may make an effort to expand the file. If file expansion
;   must take place, any expansion area is filled withg $FFs.
;
;
write_byte_immediate
;       while current_byte > end_byte
      LDA $6113
      CMP current_block + 1
      BNE $6811
      LDA $6112
      CMP current_block
      BNE $6811
      LDA $6111
      CMP $610E
      BCS $686F
      LDA $6111
      CMP #$FF
      BNE $6858
      LDA current_block
      LDX current_block + 1
      PHA 
      TXA 
      PHA 
      LDA $6112
      LDX $6113
      CLC 
      ADC #$01
      BCC $682F
      INX 
      JSR $6B1A
      TAY 
      PLA 
      TAX 
      PLA 
      STA current_block
      STX current_block + 1
      TYA 
      BCS $6889
      INC $6112
      BNE $6847
      INC $6113
      LDA directory_block
      LDX directory_block + 1
      JSR $66BB
      INC $6000
      BNE $6858
      INC $6001
      INC $6111
      LDA $6112
      LDX $6113
      JSR $66BB
      LDA #$FF
      LDY $6111
      STA $6000,Y
      JMP $67FB
      JSR $66B5
      LDY $610E
      LDA $6120
      STA $6000,Y
      INC $610E
      BNE $6888
      INC current_block
      BNE $6888
      INC current_block + 1
      CLC 
      RTS 

;**************************************************************************
;   REL FILES
;**************************************************************************
;
;directory:
; dir_record_len    1 record length
; dir_end_record    2 number of records we have
;
;channel  current_record    2 current record number
; current_record_byte 1 position in current record
; current_record_len  1 length of current record
; rel_write_flag    1 write flag...
; record_len    1 length of physical record
; end_record    2 maximum record number written
;
;access_record
; current_block/byte <= address of current_record,current_record_byte
;;
;add_record
; adds one record to end of file
; $ff plus nulls
;;
;fill_record
; fills current record from current byte to end of record with nulls.
; this may be a nop if current record is full
;;
;scan_record
; returns number of bytes in current record.
; this involves scanning the record.
;
;;; read_byte_rel
;;  always returns current byte ( even if past end of record )
;;  if past (conceptual )end of record
;;    will return nulls to end of physical record before eof
;;  otherwise will return bytes until EOF.
;;  at time EOF is returned, read_byte_rel will advance current record
;;  to start of succedding record.
;;
;; write_byte_rel
;;  if  record not present
;;    add records as neccesary
;;    if  error
;;      let user know about problem ( disk full ! )
;;  if  record is not full
;;    writes bytes at current record until record full.
;;  else
;;    returns record overflow error
;;
;; position command
;;  if  channel is not open
;;    no channel error
;;  if  not relative file
;;    complain
;;  set record number
;;  current_record_byte <= 0
;;  if  record length specified
;;    if  greater than max
;;      puke record_overflow
;;    else
;;      set current_record_byte
;;  if  record not present
;;    return record_not_present_error
;;
;;
;
;
; access_record
;
; sets current byte to point at area in current record/current_record_byte
;
; returns error if record not present
;
;
;  ram access_record_temp,3
access_record 
;       current_block <= start of file+current_record_byte
      CLC 
      LDA #$1A
      ADC $6114
      STA $610E
      LDA #$00
      LDX #$00
      ADC directory_block
      PHA 
      TXA 
      ADC directory_block + 1
      TAX 
      PLA 
      STA current_block
      STX current_block + 1
      LDY $610B
      CPY #$46
      BNE $68C4
      CLC 
      ADC $6115
      PHA 
      TXA 
      ADC $6116
      TAX 
      PLA 
      BCS $68C1
      STA current_block
      STX current_block + 1
      LDA #$34
      RTS 

      LDA #$00
      STA $6172
      LDA $6115
      LDX $6116
      STA $6170
      STX $6171
      LDA $611A
      LSR A
      PHA 
      BCC $68F8
      CLC 
      LDA $6170
      ADC $610E
      STA $610E
      LDA $6171
      ADC current_block
      STA current_block
      LDA $6172
      ADC current_block + 1
      STA current_block + 1
      ASL $6170
      ROL $6171
      ROL $6172
      PLA 
      BNE $68D8
      LDA #$32
      LDX $6116
      CPX $6119
      BNE $6914
      LDX $6115
      CPX $6118
      RTS 


      LDA $6115
      LDX $6116
      PHA 
      TXA 
      PHA 
      LDA $6114
      PHA 
      LDA $6120
      PHA 
      JSR $6940
      BCS $692C
      CLC 
      TAY 
      PLA 
      STA $6120
      PLA 
      STA $6114
      PLA 
      TAX 
      PLA 
      STA $6115
      STX $6116
      TYA 
      RTS 
;
;
;
;
;
      LDA $6118
      LDX $6119
      CPX #$FF
      BNE $694C
      CMP #$FF
      BCS $6977
      STA $6115
      STX $6116
      LDA #$00
      STA $6114
      JSR $688A
      LDA #$FF
      STA $6120
      JSR $67FB
      BCS $6976
      INC $6114
      JSR $697B
      BCS $6976
      INC $6118
      BNE $6976
      INC $6119
      RTS 


      LDA #$34
      SEC 
      RTS 

;
;
; pad_record  fills out remainder of record with nulls
;
;     NOTE: current_block/byte must be aligned with
;           current_record/current_record_byte before
;           using this routine. ( This can be done by
;           calling access_record first.
;
pad_record    ; fills out remainder of record with nulls
      LDA $6114
      CMP $611A
      BCS $6992
      LDA #$00
      STA $6120
      JSR $67FB
      BCS $6993
      INC $6114
      BNE $697B
      CLC 
      RTS 
;
;
scan_record
      LDA $6114
      PHA 
      LDA #$00
      STA $6114
      STA $6117
      JSR $688A
      BCS $69D6
      LDA $6114
      CMP $611A
      BCS $69D0
      JSR $66B5
      LDY $610E
      LDA $6000,Y
      BEQ $69BE
      LDA $6114
      STA $6117
      INC $610E
      BNE $69CB
      INC current_block
      BNE $69CB
      INC current_block + 1
      INC $6114
      BNE $69A5
      PLA 
      STA $6114
      CLC 
      RTS 


      TAY 
      PLA 
      TYA 
      RTS 

read_a_byte_from_the_record
      JSR $688A
      BCS $69E9
      JSR $66B5
      LDX $610E
      LDA $6000,X
      CLC 
      RTS 
;
;
;
; read_byte_rel
; always returns current byte ( even if past end of record )
; if past (conceptual )end of record
;   will return nulls to end of physical record before eof
; otherwise will return bytes until EOF.
; at time EOF is returned, read_byte_rel will advance current record
; to start of succedding record.
;
cleanup_write_byte_rel
;       correct current_record_byte
      JSR cleanup_read_byte_rel
      JSR $688A
      JSR $697B
      BCS $6A02
      INC $6115
      BNE $69FD
      INC $6116
      LDA #$00
      STA $6114
      CLC 
      RTS 

cleanup_read_byte_rel
      CLC 
      ADC $6114
      STA $6114
      JMP $66D4
;
read_byte_rel
      LDA #$04
      LDX #$6A
      STA cleanup_vector
      STX cleanup_vector + 1
      JSR $6994
      BCS $6A2D
      JSR $688A
      SEC 
      LDA $6117
      SBC $6114
      BEQ $6A30
      SEC 
      JMP $6A7F
      JMP $7992
      JSR $69DA
      LDX #$00
      STX $6114
      INC $6115
      BNE $6A40
      INC $6116
;

write_byte_rel
      JMP $799A
      CLC 
      JSR $6AA1
      BNE $6A69
      LDA #$EA
      LDX #$69
      STA cleanup_vector
      STX cleanup_vector + 1
      LDX $6116
      CPX $6119
      BNE $6A61
      LDX $6115
      CPX $6118
      BCC $6A6E
      JSR $6915
      BCC $6A53
      BIT $33A9
      JMP $7992
      LDA $611A
      SEC 
      SBC $6114
      BCC $6A69
      BEQ $6A69
      PHA 
      JSR $6AA1
      PLA 
      CLC 
      
rel_fastop
      PHP 
      PHA 
      JSR $688A
      JSR $66B5
      JSR $66D7
      LDA $610E
      STA $DF04
      LDA current_block
      LDX current_block + 1
      STA $DF05
      JSR $7EB7
      PLA 
      PLP 
      JMP $7AE2
;
;
write_byte_rel_flag_carry ;<4.2 fab & hcd>
;
      LDA $6121
      STA $FF
      LDA #$01
      STA $FE
      LDY #$00
      LDA ($FE),Y
      BCC $6AB3
      ROL A
      STA ($FE),Y
      RTS 
;
;
position_command
      JSR $6D58
      BCS $6B13
      TYA 
      AND #$0F
      JSR $663F
      LDA $610B
      CMP #$46
      BEQ $6ACA
      CMP #$4C
      BNE $6B10
      JSR $6D58
      TYA 
      BCS $6B13
      STA $6115
      JSR $6D58
      TYA 
      BCS $6B13
      STA $6116
      LDA #$00
      STA $6114
      JSR $6D58
      TYA 
      BCS $6AFD
      LDY $610B
      CPY #$46
      BEQ $6AFA
      CMP #$00
      BEQ $6AFD
      TAY 
      DEY 
      TYA 
      CMP $611A
      BCS $6B16
      STA $6114
      LDA $6115
      BNE $6B0A
      LDA $6116
      BEQ $6B0D
      DEC $6116
      DEC $6115
      JMP $688A
      LDA #$46
      BIT $1EA9
      BIT $33A9
      SEC 
      RTS 

;**************************************************************************
;   GROW DISK
;**************************************************************************
;
;  ram swap_block,2
;  ram swap_delta,2
; 
; entry:
;   x,a lowest block number to shift up by one.
;     ( if == disk end then disk simply expanded )
;
;
;
grow_disk
      STA $6173
      STX $6174
      LDA disk_end
      LDX disk_end + 1
      CLC 
      ADC #$01
      BNE $6B2C
      INX 
      CPX disk_max + 1
      BNE $6B34
      CMP disk_max
      BCC $6B39
      LDA #$48
      RTS 


      LDA #$01
      LDX #$00
      JSR $6B74
      LDA $6173
      LDX $6174
      JSR $66BB
      INC $6173
      BNE $6B51
      INC $6174
      JSR $66ED
      LDA $6173
      LDX $6174
      STA $DF05
      JSR $7EB7
      CPX $6103
      BNE $6B68
      CMP disk_end
      BCS $6B72
      LDA #$B2
      STA $DF01
      JMP $6B49
      CLC 
      RTS 
;
;
;
adjust_pointers
      STA $6175
      STX $6176
      LDA $6108
      PHA 
      LDX #$10
      TXA 
      JSR $663F
      LDA $610B
      BEQ $6BB6
      LDA $6112
      LDX $6113
      JSR $6BD1
      STA $6112
      STX $6113
      LDA current_block
      LDX current_block + 1
      JSR $6BD1
      STA current_block
      STX current_block + 1
      LDA directory_block
      LDX directory_block + 1
      JSR $6BD1
      STA directory_block
      STX directory_block + 1
      LDX $6108
      DEX 
      BPL $6B80
      PLA 
      JSR $663F
      LDA disk_end
      LDX disk_end + 1
      JSR $6BD1
      STA disk_end
      STX disk_end + 1
      CLC 
      RTS 
;
adjust_pointer

      CPX $6174
      BNE $6BD9
      CMP $6173
      BCC $6BE6
      CLC 
      ADC $6175
      PHA 
      TXA 
      ADC $6176
      TAX 
      PLA 
      RTS 

;************************************************************************
;   DELETE FILE ( also crushes disk )
;************************************************************************
;
;   delete_file
;     entry:  data page has directory block on it
;
delete_file
      LDA default_block
      LDX default_block + 1
      STA $6173
      STX $6174
      LDA $6000
      LDX $6001
      PHA 
      TXA 
      PHA 
      LDA $6000
      LDX $6001
      EOR #$FF
      TAY 
      TXA 
      EOR #$FF
      TAX 
      TYA 
      JSR $6B74
      PLA 
      TAX 
      PLA 
      STA $6175
      STX $6176
      LDA $6173
      LDX $6174
      SEC 
      ADC $6175
      PHA 
      TXA 
      ADC $6176
      TAX 
      PLA 
      JSR $66BB
      LDA $6173
      LDX $6174
      STA default_block
      STX default_block + 1
      INC $6173
      BNE $6C3E
      INC $6174
      LDA $6103
      CMP $6174
      BNE $6C4C
      LDA disk_end
      CMP $6173
      BCS $6C16
      RTS 

;************************************************************************
;     UTILITIES
;************************************************************************
;
to_lower
      CMP #$40
      BCC $6C5F
      CMP #$80
      BCC $6C5B
      CMP #$C0
      BCC $6C5F
      AND #$1F
      ORA #$40
      CLC 
      RTS 
      
exptab
      !byte $01,$02,$04,$08
      BPL $6C87
      rti
;************************************************************************
;   DIRECTORY OPERATIONS
;************************************************************************
;
;   find_a_file_for_open
;   find_nth_matching_file
; 
      !byte $80,$20,$3D,$66,$AD,$00,$61,$AE,$01,$61
      STA current_block
      STX current_block + 1
      CPX disk_end + 1
      BNE $6C80
      CMP disk_end
      BCC $6C8B
      BEQ $6C87
      LDA #$0D
      BIT $3EA9
      SEC 
      RTS 


      JSR $66B5
      BCS $6C89
      JSR $6CF6
      BCS $6C9C
      LDA current_block
      LDX current_block + 1
      RTS 


      LDA $6000
      LDX $6001
      SEC 
      ADC current_block
      PHA 
      TXA 
      ADC current_block + 1
      TAX 
      PLA 
      JMP $6C72
      
find_open_file      
      JSR $663D
      LDA first_block
      LDX first_block + 1
      STA current_block
      STX current_block + 1
      CPX disk_end + 1
      BNE $6CC7
      CMP disk_end
      BCC $6CD2
      BEQ $6CCE
      LDA #$0D
      BIT $3EA9
      SEC 
      RTS 


      JSR $66B5
      LDA $6002
      BEQ $6CE2
      LDA current_block
      LDX current_block + 1
      CLC 
      RTS 


      LDA $6000
      LDX $6001
      SEC 
      ADC current_block
      PHA 
      TXA 
      ADC current_block + 1
      TAX 
      PLA 
      JMP $6CB9
      
compare_filenames      
      LDX #$FF
      INX 
      LDA $6008,X
      BNE $6D09
      LDA $6177,X
      BEQ $6D07
      CMP #$2A
      BNE $6D1B
      CLC 
      RTS 

;************************************************************************
;   OPENS 
;************************************************************************
;
;
;
; open:
;   0-14  <$><:>filename<,<s|p|r>>
;     <@><<0>:>filename<,<s|p|r>><,<r|w|a|m>>
;   15 only:
;     Rename<0<:>>filename=<0<:>>filename
;     Copy<0<:>>filename=<0<:>>filename
;     Scratch<0<:>>filename
;     New<0<:>>filename,idh     <4.1 fab>
;     Initialize<0<:>>
;     Validate<0<:>>
;     P<96+channel_number><record_low><record_high><offset>
;     UJ:
;
;
; dir_file
; parse_filename
; second_filename
; file_type <p>,<s>,<r>
; access_type <r>,<w>,<m>,<a>
; replace_flag
;
;
; ram filename,17
; ram parse_access,1
; ram type_char,1
; ram wild_char,1
; ram replace_flag,1
; ram found_flag,1
;
;
;

;************************************************************************
;   PARSING low level utilities
;************************************************************************
;
      LDA $6177,X
      BEQ $6D1B
      CMP $6008,X
      BEQ $6CF8
      CMP #$3F
      BEQ $6CF8
      CMP #$2A
      BEQ $6D07
      SEC 
      RTS 

      LDA #$00
      STA $6189
      STA $618A
      STA $618B
      STA $618C
      STA $618D
      
init_get_filename
      JSR $7A01
      LDY $B7
      LDA $6191,Y
      LDX #$00
      BEQ igf_really
init_get_filename_from_command
      LDX #$01
      LDY $6292
      LDA $6292,Y
igf_really
      CMP #$0D
      BNE $6D47
      DEY 
      STX $6191
      STY $6190
      LDA #$00
      STA $618F
      CLC 
      RTS 
;
unget_filename_char
      DEC $618F
      RTS 

;
get_filename_char
      LDY $618F
      CPY $6190
      BCS $6D75
      LDA $6191
      BNE $6D6B
      LDA $6192,Y
      JMP $6D6E
      LDA $6293,Y
      INC $618F
      JSR $6D76
      CLC 
      RTS 

;
; classsify_char
;   entry:  a= char
;   exit: a = class
;     y = char
;     c = 0
;
classify_char
      LDX #$07
      CMP $6D95,X
      BEQ $6D84
      DEX 
      BNE $6D78
      TAY 
      LDA #$00
      RTS 


      TAY 
      LDA $6C61,X
      CMP #$04
      BEQ $6D90
      CMP #$02
      BNE $6D93
      STY $618B
      CLC 
      RTS 

classy_chars
  ;.byte ' ?*"@=$,'
  
;
;
; classes 7 6 5 4 3 2 1 0
; class <comma> <$> <=> <@> <"> <*> <?> < >
;   
;
      JSR $2A3F
      !byte $22
      RTI 
      AND $2C24,X
      
;************************************************************************
;   PARSING   mid level calls
;************************************************************************
; get_filename
;   entry:  cur_filename_char = users string
;   exit: cur_filename_char = advanced
; get_mod_type
;   entry:  cur_filename_char = pointer to users string
;
get_filename
      LDX #$FF
      INX 
      LDA #$00
      STA $6177,X
      JSR $6D58
      BCS $6DC4
      AND #$A0
      BNE $6DC1
      LDX #$FF
      INX 
      CPX #$10
      BEQ $6DC1
      LDA $6177,X
      BNE $6DB0
      TYA 
      STA $6177,X
      JMP $6D9F
      JSR $6D54
      CLC 
      RTS 

;
;
; get_mod_type
;   entry:  cur_filename_char = pointer to users string
;   exit: type & access flags set if such is found
;     things advanced
;     if  comma found, but not legal mod
;       routine pukes.
;
      JSR $6DCC
      JSR $6DCC
      JSR $6D58
      BCS $6E04
      CPY #$2C
      BNE $6E01
      JSR $6D58
      BCS $6E01
      TYA 
      JSR $6C4F
      CMP #$50
      BEQ $6E28
      CMP #$53
      BEQ $6E28
      CMP #$55
      BEQ $6E28
      CMP #$52
      BEQ $6E31
      CMP #$57
      BEQ $6E31
      CMP #$41
      BEQ $6E31
      CMP #$46
      BEQ $6E31 ; get access
      CMP #$4C
      BEQ $6E06
      JSR $6D54 ; unget_filename_char
      JSR $6D54 ; unget_filename_char
      CLC 
      RTS 

;
  ;.ifdef rel_flag
get_rel_length
      JSR $6E28
      BCS $6E24
      JSR $6D58
      BCS $6E22
      CPY #$2C
      BNE $6E1F
      JSR $6D58
      BCS $6E24
      STY $618D
      JMP $6E37
      JSR $6D54 ; unget_filename_char
      CLC 
      RTS 


      LDA #$1E
      SEC 
      RTS 
;  .endif

get_type
      LDY $618A
      STA $618A
      JMP $6E37
get_access
      LDY $6189
      STA $6189
get_end_mod
      TYA 
      PHA 
      JSR $6D58
      BCS $6E45
      AND #$A0
      BEQ $6E39
      JSR $6D54
      CLC 
      PLA 
      BEQ $6E4C
      LDA #$1E
      SEC 
      RTS 
;
; eat_zero_colon
;   skips over <0><:>  iff present
;
;
eat_zero_colon
      JSR $6D58
      BCS $6E66
      CPY #$3A
      BEQ $6E66
      CPY #$30
      BNE $6E63
      JSR $6D58
      BCS $6E66
      CPY #$3A
      BEQ $6E66
      JSR $6D54
      CLC 
      RTS 

;************************************************************************
;   PARSING   high level calls
;************************************************************************
;
;
;
; parse_for_open
;
parse_for_open
      JSR $6D1D
      JSR $6D58
      BCS $6EA7
      CPY #$40
      BNE $6E86
      STY $618C
      JSR $6D58
      BCS $6E93
      CPY #$40
      BEQ $6E74
      JSR $6D54
      JMP $6E93
      CPY #$24
      BNE $6E90
      STY $6189
      JMP $6E93
      JSR $6D54
      JSR $6E4D
      JSR $6D9D
      JSR $6DC6
      BCS $6EA5
      JSR $6D58
      BCS $6EA7
      LDA #$1E
      SEC 
      RTS 


      CLC 
      RTS 

;************************************************************************
;     NORMAL OPENS
;************************************************************************
;
;
;
; open 1  = parse
;   check for existence of file
;   do all checking which is independent of access
;
; open 2  = type dependent checking & actual opens
;
open_channel_given_sa
      JSR $6638
      CMP #$0F
      BNE $6EB3
      JMP $7143
      CPX #$00
      BEQ $6EBA
      JSR $70EA
      JSR $655F
      JSR $6E68
      BCS $6F14
      LDA $6189
      CMP #$24
      BNE $6ECC
      JMP $742D
      LDA #$22
      LDX $6177
      BEQ $6F14
      LDA #$00
      STA $618E
      LDA $6189
      BNE $6EE2
      LDA #$52
      STA $6189
      JSR $6C69
      BCS $6F19
      PHA 
      TXA 
      PHA 
      JSR $6638
      PLA 
      TAX 
      PLA 
      STA current_block
      STX current_block + 1
      JSR $66B5
      BCS $6F14
      LDA #$3C
      LDX $6002
      BNE $6F14
      LDX $6003
      LDA $618A
      STX $618A
      BEQ $6F16
      CMP $6003
      BEQ $6F16
      LDA #$40
      SEC 
      RTS 


      INC $618E
      LDA $618A
      BNE $6F23
      LDA #$53
      STA $618A
      CMP #$4C
      BNE $6F2A
      JMP $7091
      LDA $6189
      CMP #$52
      BEQ $6F3F
      CMP #$41
      BEQ $6FB2
      CMP #$46
      BNE $6F3C
      JMP $6FEB
      JMP $7010
 ;
; access request
;  replace_request
;   wild present
;    type request
;     found_flag
; r1--- error syntax ( replace and read access incompat )
; r0--0 error file not found
; r0-s1 open for sequential
; r0-p1 open prog for read
; r0-l1 open rel for read
; r1--- error syntax ( replace and read access incompat )
; r0--0 error file not found
; r0-s1 open for sequential
; r0-p1 open prog for read
; r0-l1 open rel for read
;
; access request
;  replace_request
;   wild present
;    type request
;     found_flag
; f-1-- error syntax ( illegal wild cards )
; f-0$- error syntax ( not on directory file , file_type_mismatch )
; f-0L- error syntax ( not on rel files, file type mismatch )
; f-0s0 open new seq file using open2_write
; f-0p0 open new prg file using open2_write
; f00s1 open existing seq file using open2_read
; f00p1 open existing prg file using open2_read
; f10s1 open existing seq file using open2_write
; f10p1 open existing prg file using open2_write
; 
;
; access request
;  replace_request
;   wild present
;    type request
;     found_flag
; w-000 open seq file for write new
; w-0s0 open seq file for write new
; w-0p0 open prg file for write new
; w-0l0 open rel file for write new
; w1001 open seq file for write ( delete old )
; w10s1 open seq file for write ( delete old )
; w10p1 open prg file for write ( delete old )
; w10l1 open rel file for write ( delete old )
; w-!-- error illegal use of wild cards
; w00-1 error file exists
;
; w-!-- error illegal use of wild cards
; w00-1 error file exists
; w-000 open seq file for write new
; w-0s0 open seq file for write new
; w-0p0 open prg file for write new
; w-0l0 open rel file for write new
; w1001 open seq file for write ( delete old )
; w10s1 open seq file for write ( delete old )
; w10p1 open prg file for write ( delete old )
; w10l1 open rel file for write ( delete old )
;
; open2_read  directory_block is current_block
;
open2_read     
      LDA #$1E
      LDX $618C
      BNE $6FB0
      LDA #$3E
      LDX $618E
      BEQ $6FB0
      JSR $66B5
      BCS $6FB0
      JSR $6638
      LDA default_block
      LDX default_block + 1
      STA directory_block
      STX directory_block + 1
      STA current_block
      STX current_block + 1
      CLC 
      ADC $6000
      PHA 
      TXA 
      ADC $6001
      TAX 
      PLA 
      STA $6112
      STX $6113
      LDA #$1A
      STA $610E
      LDA $6004
      STA $6111
      LDA $6007
      STA $611A
;
;  .ifdef rel_flag
;
      LDA $6005
      LDX $6006
      STA $6118
      STX $6119
      LDA #$00
      LDX #$00
      STA $6115
      STX $6116
      STA $6117
      STA $6114
;
;  .endif
;
;
      LDA $6189
      STA $610B
      STA $6002
      CLC 
      RTS 


      SEC 
      RTS 

open2_append
      LDA #$57
      STA $6189
      LDX $618E
      BEQ $7010
      LDA #$21
      LDX $618B
      BNE $6FE9
      JSR $6F3F
      BCS $6FE9
      LDA $6111
      STA $610E
      LDA $6112
      LDX $6113
      STA current_block
      STX current_block + 1
      INC $610E
      BNE $6FE7
      INC current_block
      BNE $6FE7
      INC current_block + 1
      CLC 
      RTS 

      SEC 
      RTS 

;  .ifdef position_flag
open2_fast
      LDA #$21
      LDX $618B
      BNE $700E
      LDA #$1E
      LDX $618A
      CPX #$53
      BEQ $7001
      CPX #$50
      BEQ $7001
      SEC 
      RTS 

      LDA $618E
      BEQ $7010
      LDA $618C
      BNE $7010
      JMP $6F3F
      SEC 
      RTS 
;
;  .endif
;

open2_write
      LDA #$21
      LDX $618B
      BEQ $701A
      JMP $708F
      LDX $618E
      BEQ $702C
      LDA #$3F
      LDX $618C
      BEQ $708F
      JSR $66B5
      JSR $6BE7
      JSR $6638
      JSR $662D
      LDA disk_end
      LDX disk_end + 1
      STA current_block
      STX current_block + 1
      STA directory_block
      STX directory_block + 1
      STA $6112
      STX $6113
      JSR $6B1A
      BCS $708F
      JSR $6638
      JSR $66B5
      LDY #$11
      LDA $6177,Y
      STA $6008,Y
      DEY 
      BPL $7057
      LDA $618A
      STA $6003
;
;  .ifdef rel_flag      
      LDA $618D
      STA $6007
      STA $611A
;  .endif
;
      LDA #$00
      LDX #$00
      STA $6000
      STX $6001
      LDA #$1A
      STA $6004
      STA $6111
      STA $610E
      LDA $6189
      STA $6002
      STA $610B
;
;       if rel file, end_record is already cleared 
;
      CLC 
      RTS 


      SEC 
      RTS 

;  .ifdef rel_flag
open2_rel
      LDA #$4C
      STA $6189
      STA $618A
      LDX $618E
      BEQ $70B9
      JSR $66B5
      LDA $6007
      LDX $618D
      STA $618D
      BEQ $70B1
      CPX $618D
      BNE $70CD
      LDX $618C
      BNE $70B9
      JMP $6F3F
      LDA $618D
      BEQ $70CD
      LDX $618E
      BNE $70CA
      LDA #$21
      LDX $618B
      BNE $70CF
      JMP $7010
      LDA #$32
      SEC 
      RTS 
;
;  .endif
;
;************************************************************************
;     CLOSE CHANNEL
;************************************************************************
;
close_all_channels
      LDX #$10
      TXA 
      PHA 
      JSR $663F
      JSR $70ED
      PLA 
      TAX 
      DEX 
      BPL $70D3
      CLC 
      RTS 

close_channel_given_sa_user   ;<4.2 fab>
      LDA $B9
      AND #$0F
      CMP #$0F
      BEQ $70D1
close_channel_given_sa
      JSR $6638
close_channel_default
      LDA $6108
      LDX $610B
;     if  not open
      BEQ $7141
      CMP #$0F    ; if  not command channel or dir file
      BEQ $713C
      CPX #$24
      BEQ $713C
      LDA directory_block
      LDX directory_block + 1
      STA current_block
      STX current_block + 1
      JSR $66B5
      BCS $7142
      LDA $6111
      STA $6004
      LDA $6112
      LDX $6113
      SEC 
      SBC directory_block
      PHA 
      TXA 
      SBC directory_block + 1
      TAX 
      PLA 
      STA $6000
      STX $6001
      LDA $6118
      LDX $6119
      STA $6005
      STX $6006
;  .endif
;
      LDA #$00
      STA $6002
      LDA #$00
      STA $610B
      CLC 
      RTS 

;************************************************************************
;   COMMAND CHANNEL OPEN AND WRITE
;************************************************************************
;
;
command_len_max = 40  ;max length of command
;  ram command_len   length of command
;  ram command,41    actual command text
;
;
command_channel_open
      LDA #$0F
      JSR $6638
      LDA #$57
      STA $610B
      JSR $6D2E
      LDY $B7
      CLC 
      BEQ $715B
      CPY #$28
      BCC $715C
      LDA #$20
      RTS 


      STY $6292
      DEY 
      LDA $6192,Y
      STA $6293,Y
      DEY 
      BPL $7160
      
command_clear_and_interpret
      JSR $71FB
      LDX #$00
      STX $6292
      RTS 

cleanup_command_write
      CLC 
      ADC $6292
      STA $6292
      BEQ $7183
      JSR $7169
      BCC $7183
      JSR $6567
      RTS 

command_channel_write
      LDY $6120
      LDA #$28
      SEC 
      SBC $6292
      BCS $719D
      CPY #$0D
      BNE $7198
      LDA #$00
      STA $6292
      LDA #$20
      JMP $7992
      CPY #$0D
      BNE $71AC
      JSR $71FB
      LDX #$00
      STX $6292
      JMP $79A3
      TAY 
      LDA #$72
      LDX #$71
      STA cleanup_vector
      STX cleanup_vector + 1
      LDA #$93
      LDX #$02
      CLC 
      ADC $6292
      BCC $71C2
      INX 
      STA $DF04
      STX $DF05
      LDA #$00
      JSR $7EB0
      TYA 
      CLC 
      JMP $7AE2
;************************************************************************
;   COMMAND DISPATCH
;************************************************************************
; commands:
;   Rename<0<:>>filename=<0<:>>filename
;   Copy<0<:>>filename=<0<:>>filename
;   Scratch<0<:>>filename
;   New<0<:>>filename,idh     <4.1 fab>
;   Initialize<0<:>>
;   Validate<0<:>>
;   P<96+channel_number><record_low><record_high><offset>
;   Uxxxx
;
      !byte $53, $72
      AND $7252,X
      CMP $7243,X
      SBC ($4E),Y
      !byte $72,$CF,$4D,$73,$B5,$49,$73,$77
      !byte $55,$73,$7D,$56,$72
      LDA $6A50,Y 
      !byte $b3, $00
      JSR $71F4
      JSR $71F4
      INC $FE
      BNE $71FA
      INC $FF
      RTS 

interpret_command
      JSR $655F
      JSR $6D1D
      JSR $6D3A
      LDA #$D2
      LDX #$71
      STA $FE
      STX $FF
      LDA $6292
      BEQ $7231
      JSR $6D58
      TYA 
      TAX 
      LDY #$FD
      INY 
      INY 
      INY 
      LDA ($FE),Y
      BNE $7223
      LDA #$1F
      SEC 
      RTS 

      TXA 
      CMP ($FE),Y
      BNE $7218
      INY 
      LDA ($FE),Y
      PHA 
      INY 
      LDA ($FE),Y
      PHA 
      NOP 
      CLC 
      RTS 

eat_until_colon
      JSR $6D58
      BCS $723C
      CPY #$3A
      BNE eat_until_colon
      CLC 
      RTS 

;************************************************************************
;   COMMANDS
;************************************************************************
;
;  ram scratch_cntr,2
;
scratch_command
      JSR $7233
      JSR $6D9D
      BCS $7271
;     no need to consider rest of filename
      LDA #$00
      LDX #$00
      STA $62BC
      STX $62BD
      JSR $6C69
      BCC $725B
      CMP #$3E
      BEQ $7273
      SEC 
      RTS 


      LDA current_block
      LDX current_block + 1
      JSR $727C
      INC $62BC
      BNE $726C
      INC $62BD
      JSR $6BE7
      BCC $7250
      SEC 
      RTS 


      LDA $62BC
      LDX $62BD
      JMP $64F0
      STA $62BE
      STX $62BF
      LDA $6108
      STA $62C0
      LDA #$10
      JSR $663F
      BEQ $72AC
      LDA $62BE
      LDX $62BF
      CPX directory_block + 1
      BNE $729D
      CMP directory_block
      BNE $72AC
      LDA $6108
      CMP $62C0
      BEQ $72AC
      LDA #$00
      STA $610B
      LDA $6108
      CLC 
      ADC #$FF
      BCS $728A
      LDA $62C0
      JMP $663F
validate_command
      JSR $70D1
      JSR $655F
      JSR $6CB0
      BCS $72CA
      JSR $6BE7
      BCC $72C0
      CMP #$3E
      BNE $72CF
      CLC 
      RTS 

new_command       ;<4.1 fab>  added routine
      LDA first_block
      LDX first_block + 1
      STA disk_end
      STX disk_end + 1
      CLC 
      RTS 

rename_command
      JSR $73E7
      BCS $72F0
      LDX #$FF
      INX 
      LDA $6123,X
      STA $6008,X
      BNE $72E5
      CLC 
      RTS 


      SEC 
      RTS 

copy_command
      JSR $73E7
      BCS $7370
      LDA $6000
      LDX $6001
      SEC 
      ADC disk_end
      PHA 
      TXA 
      ADC disk_end + 1
      TAX 
      PLA 
      CPX disk_max + 1
      BNE $7310
      CMP disk_max
      BEQ $7314
      BCS $736E
      STA $62C1
      STX $62C2
      LDA disk_end
      LDX disk_end + 1
      PHA 
      TXA 
      PHA 
      LDA disk_end
      LDX disk_end + 1
      STA default_block
      STX default_block + 1
      INC current_block
      BNE $7337
      INC current_block + 1
      INC disk_end
      BNE $733F
      INC disk_end + 1
      JSR $66B5
      LDA $6103
      CMP $62C2
      BNE $7350
      LDA disk_end
      CMP $62C1
      BNE $7323
      PLA 
      TAX 
      PLA 
      STA current_block
      STX current_block + 1
      JSR $66BB
      LDX #$FF
      INX 
      LDA $6123,X
      STA $6008,X
      BNE $7360
      STA $6002
      CLC 
      RTS 


      LDA #$48
      SEC 
      RTS 

uj_command
ui_command
ucolon_command
      JSR $70D1
      JMP $655C
      
init_command
      JSR $70D1
      JMP $655F

u_command
      JSR $6D58
      BCS $739E
      CPY #$3A
      BEQ $7372
      CPY #$4A
      BEQ $7372
      CPY #$49
      BEQ $7372
      CPY #$30
      BNE $739E
      JSR $6D58
      BCS $739E
      CPY #$3E
      BNE $739E
      CLC 
      BIT $38
set_unit_or_bitch
      BCS $73B2
      JSR $6D58
      BCS $73B2
      TYA 
      CMP #$1F
      BCS $73B2
      CMP #$04
      BCC $73B2
      JMP $7E08
      LDA #$1F
      SEC 
      RTS 

m_command
      JSR $6D58
      JSR $6D58
      BCS $73E3
      CPY #$57
      BNE $73E3
      JSR $6D58
      BCS $73E3
      CPY #$77
      BEQ $73CF
      CPY #$78
      BNE $73E3
      JSR $6D58
      BCS $73E3
      CPY #$00
      BNE $73E3
      JSR $6D58
      BCS $73E3
      CPY #$00
      BEQ $73E3
      CLC 
      BIT $38
      JMP $739F
      
;************************************************************************
;   "PARSE FOR RENAME/COPY"
;************************************************************************
;
; does parsing. copys first filename to alt_filename
;     verifys that first does not exist.
;     parse second file name
;     verifies that file does exist.
;     returns with current channel pointing to default block
;
;
;
parse_for_rename_copy
      JSR $7233
      JSR $6D9D
      BCS $742B
      LDA $618B
      BNE $7429
      JSR $6C69
      LDA #$3F
      BCC $742B
      LDX #$FF
      INX 
      LDA $6177,X
      STA $6123,X
      BNE $73FD
      JSR $6D58
      BCS $742B
      CPY #$3D
      BNE $7429
      JSR $6E4D
      JSR $6D9D
      BCS $742B
      LDA #$22
      LDX $6177
      BEQ $742B
      JSR $6C69
      BCS $7426
      JMP $66AF
      LDA #$3E
      BIT $1EA9
      SEC 
      RTS 

;************************************************************************
;   READ DIRECTORY FOR USER
;************************************************************************
;
;
;  ram dir_line,50
;
; directory open
;   entry:  parse for open called
;     filename = filename
;     filetype = filetype
;     parse_access = $
;     end byte in file not checked
;     default channel is users channel
;
;
;
directory_open
      LDA #$24
      STA $610B
      JSR $663D
      LDA #$00
      STA $610E
      STA current_block
      STA current_block + 1
      LDA $6177
      BNE $744D
      STA $6178
      LDA #$2A
      STA $6177
      JMP $74FB
directory_cleanup
      CLC 
      ADC $610E
      STA $610E
      RTS 

directory_read
      JSR $663D
      LDY $610E
      CPY $6111
      BCC $746C
      JSR $749D
      BCC $746C
      CLC 
      JMP $7989
      LDA #$50
      LDX #$74
      STA cleanup_vector
      STX cleanup_vector + 1
      LDA #$C3
      LDX #$02
      CLC 
      ADC $610E
      BCC $7481
      INX 
      STA $DF04
      STX $DF05
      LDA #$00
      JSR $7EB0
      LDA $6111
      SEC 
      SBC $610E
      LDX $62F5
      LDY $62F6
      SEC 
      JMP $7AE2
;
;
;
; directory_format_next_line
;
;   entry:  current channel is directory channel
;     filename is set up
;   exit: c=0 operation is ok
;     c=1 EOF return one null to user
;
;
directory_format_next_line
      LDA current_block
      ORA current_block + 1
      BNE $74AE
      LDA first_block
      LDX first_block + 1
      JMP $74D3
      LDA current_block
      LDX current_block + 1
      CPX disk_end + 1
      BNE $74BC
      CMP disk_end
      BCC $74BF
      RTS 


      JSR $66B5
      LDA current_block
      LDX current_block + 1
      SEC 
      ADC $6000
      PHA 
      TXA 
      ADC $6001
      TAX 
      PLA 
      STA current_block
      STX current_block + 1
      CPX disk_end + 1
      BNE $74E1
      CMP disk_end
      BCC $74E9
      JSR $754A
      JMP $74F4
      JSR $66B5
      JSR $6CF6
      BCS $749D
      JSR $7572
      LDA #$00
      STA $610E
      CLC 
      RTS 

format_first_line
      LDX #$20
      STX $6111
      DEX 
      LDA $750C,X
      STA $62C3,X
      DEX 
      BPL $7501
      CLC 
      RTS
      
first_line_text
      !byte $01, $10 ; load address
      !byte $01, $10 ; next line address
      !byte $00, $00 ; line number
      !byte $12, $22 ; rvs on, quote
      !text "RAMDISK ][  V"
version
      !text "4.3"
      !byte $22       ; terminal quote
      !byte $20, $52, $44,  $20, $30, $30, $00 ; " RD 00"  id and version and trailing null
end_first_line_text

last_line_text
      !byte $01,$10 ; next line address
      !byte $00,$00 ; line number
      !text "BLOCKS FREE             "
      !byte $00, $00
end_last_line_text

format_last_line
l754A LDX #end_last_line_text-last_line_text
      STX $6111
      DEX 
      LDA last_line_text,X
      STA $62C3,X
      DEX 
      BPL $7550
      LDA disk_max
      LDX disk_max+1
      SEC 
      SBC disk_end
      PHA 
      TXA 
      SBC disk_end + 1
      TAX 
      PLA 
      STA $62C5
      STX $62C6
      CLC 
      RTS 

format_nth_line
      LDX #$20
      STX $6111
      LDA #$20
      STA $62C3,X
      DEX 
      CPX #$03
      BNE $7579
      LDA #$22    ; opening quote
      STA $62C7
      LDX #$00    ; copy filename until 17 chars or null
      LDA $6008,X
      STA $62C8,X
      BEQ $7595
      INX 
      CPX #$11
      BNE $7588
      LDA #$22    ; close quote
      STA $62C8,X
      
      ; set up type of file....
      LDY #$53    ; S 
      LDA #$45    ; E
      LDX #$51    ; Q
      CPY $6003   ; dir_filetype
      BEQ $75CA
      LDY #$50    ; P
      LDA #$52    ; R
      LDX #$47    ; G
      CPY $6003   ; dir_filetype
      BEQ $75CA
      LDY #$55    ; U
      LDA #$53    ; S
      LDX #$52    ; R
      CPY $6003   ; dir_filetype
      BEQ $75CA
      LDY #$52    ; R
      LDA #$45    ; E
      LDX #$4C    ; L
      CPX $6003   ; dir_filetype
      BEQ $75CA
      LDA #$3F    ; ?
      TAX 
      TAY 
      STY $62DA   ; dir_line+23
      STA $62DB   ; dir_line+24
      STX $62DC   ; dir_line+25
      
      LDA $6002   ; if  file is open for write
      CMP #$57    ; W
      BNE $75DF
      LDA #$2A    ; *   - mark it as such
      STA $62D9   ; dir_line+22
      
      ;mark number of blocks
      LDA $6000
      LDX $6001
      CLC 
      ADC #$01
      PHA 
      TXA 
      ADC #$00
      TAX 
      PLA 
      STA $62C5
      STX $62C6
      CPX #$03
      BNE $75FA
      CMP #$E8
      BCS $7615
      CPX #$00
      BNE $7602
      CMP #$64
      BCS $7612
      CPX #$00
      BNE $760A
      CMP #$0A
      BCS $760F
      JSR $761C   ; insert space
      JSR $761C   ; insert space
      JSR $761C   ; insert space
      LDA #$00    ; terminating null
      STA $62E2   ; dir_line+31
      CLC 
      RTS 


      LDX #$04    ; insert a space in front of name
      LDA #$20
      LDY $62C3,X ; dir_line,x
      STA $62C3,X ; dir_line,x
      TYA 
      INX 
      CPX #$20
      BNE $7620
      RTS 

;*****************************************************************************
;     LOAD
;*****************************************************************************
;
;
;
; sa  =0  memuss = loading address
;   <>0 load at address specified by file
;
; .a  = 0 load
; .a  <> 0  vefify only
;
; ba  destination bank
; 
; file_not_found_exit
;   set b1 of status 
;   error4
;
; load of directory
; load of file...
;
disk_load
      STA $93
      LDA $B7
      BNE $7637
      LDA #$08
      BNE $766B
      JSR $7676
      BCC $765D
      CMP #$00    ; if  error code is zero
      BNE $7650
      LDA $93
      BNE $7648
      LDA #$10
      BNE $766B
      LDA #$10    ; set bits in status for verify error
      ORA $90     ; status
      STA $90
      BNE $765D   ; go return happy
      JSR $6567   ; error_channel_set_up
      LDA #$02    ; set up IEEE timeout error
      ORA $90
      STA $90
      LDA #$04    ; return file not found error in kernal
      BNE $766B
      LDA #$40    ; return EOF in error status
      ORA $90
      STA $90
      LDX $AE     ; good exit return end load address
      LDY $AF
      CLC 
      JMP $79BD   ; disk_direct_return
      
      TAY 
      LDA #$F7
      PHA 
      LDA #$14
      PHA 
      TYA 
      JMP $79BD   ; disk_direct_return
 
  
;
;
;
; disk_load_1
;   does all the major parsing and performs the load
;
;   exit:
;     eal,eah point to last byte + 1
;     c=0 ok
;     c=1 .a = 0  verck = 0 out of memory error
;     c=1 .a = 0  verck != 0  verify error
;     c=1 .a != 0     error code in .a
;   
      LDA #$00    ; clear status
      STA $90
      JSR $7A6C   ; luking
      JSR $6E68   ; parse_for_open
      BCS $76C6
      JSR $6D58   ; get_filename_char
      BCC $76C4
      LDA $618C   ; replace_flag
      BNE $76C4
      
      LDA $6189   ; parse_access  if   $
      CMP #$24    ; $
      BNE $7696 
      JMP $777A   ; directory_load
      ORA $618A
      BNE $76C4
      LDA #$22
      LDX $6177
      BEQ $76C6
      JSR $6C69
      BCS $76C6
      STA current_block
      STX current_block + 1
      JSR $66B5
      LDA #$40
      LDX $6003   ; dir_filetype
      CPX #$50    ; P
      BNE $76C6
      LDX $6002   ; dir_access    if  not open
      BEQ do_load ; do_load
      LDA #$3C    ; file_open error
      
;      !byte $2c
;      lda #file_not_found
;      !byte $2c
;      lda #syntax_error
;      sec
;      rts
      
      BIT $3EA9
      BIT $1EA9
      SEC 
      RTS 

;*****************************************************************************
;     DO_LOAD
;*****************************************************************************
;
;
; do_load
;   entry:
;     sa  =0  memuss = loading address
;       <>0 load at address specified by file
;     verck   = 0 load
;       <> 0  vefify only
;     ba  destination bank
;     load save channel selected
;     current_block is directory block & is accessed
;
;   exit: c=0 load completed
;     c=1 verck <> 0  verify error
;     c=1 verck = 0 out of mem error ( $ff00 )
;
do_load
      JSR $F5D2
      JSR $66D7
      LDA $C3
      LDX $C4
      LDY $B9
      BEQ $76DC
      LDA $601A
      LDX $601B
      STA $DF02
      STX $DF03
      LDY #$1C
      STY $DF04
      LDA current_block
      LDX current_block + 1
      STA $DF05
      JSR $7EB7
      SEC 
      LDA $6004
      SBC #$1B
      TAY 
      LDA $6000
      LDX $6001
      SBC #$00
      BCS $770E
      DEX 
      JMP $770E
      LDX #$00
      TXA 
      LDY $6111
      STY $DF07
      STA $DF08
      CPX #$00
      PHP 
      LDA #$FF
      LDX #$EF
      SEC 
      SBC $DF02
      PHA 
      TXA 
      SBC $DF03
      TAX 
      PLA 
      PLP 
      BNE $7733
      CPX $DF08
      BNE $7731
      CMP $DF07
      BCS $773F
      STA $DF07
      STX $DF08
      JSR $773F
      JMP $7774
      LDA $DF02
      LDX $DF03
      CLC 
      ADC $DF07
      PHA 
      TXA 
      ADC $DF08
      TAX 
      PLA 
      STA $AE
      STX $AF
      LDA $DF07
      ORA $DF08
      BEQ $7778
      LDY #$A1
      LDA $93
      BEQ $7764
      LDY #$A3
      JSR $7A2A
      LDA $93
      BEQ $7778
      LDA dma
      AND #$20
      STA $93
      BEQ $7778
      LDA #$00
      SEC 
      RTS 


      CLC 
      RTS 

;*****************************************************************************
;     DIRECTORY_LOAD
;*****************************************************************************
;
;
; DIRECTORY_LOAD
;   entry:
;     sa  =0  memuss = loading address
;       <>0 load at address specified by file
;     verck   = 0 load
;       <> 0  vefify only
;     ba  destination bank
;
;   exit: c=0 load completed
;     c=1 verck <> 0  verify error
;     c=1 verck = 0 out of mem error ( $ff00 )
;
directory_load
      JSR $F5D2
      JSR $742D
      LDA $C3
      LDX $C4
      LDY $B9
      BEQ $778C
      LDA #$10
      LDX #$10
      STA $AE
      STX $AF
      DEC $6111
      DEC $6111
      LDX #$FF
      INX 
      LDA $62C5,X
      STA $62C3,X
      CPX $6111
      BCC $7798
      JSR $77BD
      BCS $77BA
      JSR $749D
      BCC $77A4
      LDX #$00
      STX $62C3
      INX 
      STX $6111
      JSR $77BD
      LDA #$00
      RTS 


      LDA #$C3
      LDX #$02
      STA $DF04
      STX $DF05
      LDA #$00
      JSR $7EB0
      LDA $AE
      LDX $AF
      STA $DF02
      STX $DF03
      JMP $7708
      
;********************************************************************
;     SAVE
;********************************************************************
;
; enrty
;   (y,x) eal ending address of area to save
;   (@a)  stal  starting address of area to save
;   ba    bank source
;
;
;rsave  lda fa      ; save
; fa_cmp a
; beq 10$
; continue save
;10$  abs_ref jsr,swap_disk
; jmp disk_load
;
; 
disk_save_1
      LDA #$00
      STA $90
      JSR $7A65
      JSR $6E68
      BCS $7827
      LDA $618A
      ORA $6189
      ORA $618B
      BNE $7825
      LDA #$22
      LDX $6177
      BEQ $7827
      JSR $6C69
      BCS $781F
      STA current_block
      STX current_block + 1
      JSR $66B5
      LDA #$3F
      LDX $618C
      BEQ $7827
      LDA #$40
      LDX $6003
      CPX #$50
      BNE $7827
      LDA #$3C
      LDX $6002
      BNE $7827
      JSR $6BE7
      JMP $7829
      LDA #$3E
      BIT $1EA9
      SEC 
      RTS 


      LDA disk_end
      LDX disk_end + 1
      CPX disk_max + 1
      BNE $7837
      CMP disk_max
      BCC $783D
      LDA #$48
      SEC 
      RTS 


      JSR $66AF
      LDA $C1
      LDX $C2
      STA $601A
      STX $601B
      LDA $AE
      LDX $AF
      SEC 
      SBC $C1
      PHA 
      TXA 
      SBC $C2
      TAX 
      PLA 
      TAY 
      PHA 
      TXA 
      PHA 
      TYA 
      CLC 
      ADC #$FF
      PHA 
      TXA 
      ADC #$FF
      TAX 
      PLA 
      CLC 
      ADC #$1C
      STA $6004
      TXA 
      ADC #$00
      STA $6000
      LDA #$00
      STA $6001
      ASL $6001
      STA $6002
      LDA #$50
      STA $6003
      LDX #$FF
      INX 
      LDA $6177,X
      STA $6008,X
      BNE $7883
      JSR $66D7
      PLA 
      TAX 
      PLA 
      STA $DF07
      STX $DF08
      LDA $C1
      LDX $C2
      STA $DF02
      STX $DF03
      LDA current_block
      LDX current_block + 1
      STA $DF05
      JSR $7EB7
      LDA #$1C
      STA $DF04
      LDA $6000
      LDX $6001
      SEC 
      ADC disk_end
      PHA 
      TXA 
      ADC disk_end + 1
      TAX 
      PLA 
      CPX disk_max + 1
      BNE $78CC
      CMP disk_max
      BCC $78D1
      LDA #$48
      RTS 


      STA disk_end
      STX disk_end + 1
      LDY #$A0
      JSR $7A2A
      JSR $66D4
      CLC 
      RTS 
      
;****************************************************************************
;   FIRST_DISK_ROUTINES
;****************************************************************************
;
disk_io
      JSR $7A7F
      STX $62F5
      STY $62F6
      STA $6120
      BCC $78F9
      LDA $90
      BNE $78F6
      JMP $6704
      JMP $7995
      JMP $6788
      JSR $7A7F
      JMP $79BD
disk_close
      ;.ifdef rel_flag
      ; bcc disk_ckout
      ;.endif
      BCC $78FC
      JSR $7A7F
      TXA 
      JSR $F2F2
      JSR $70E2
      JMP $79A3
disk_open_nmi
      JSR $7A7F
      STA $6120
      BCS $791C
      JMP $79ED   ; disk_run_stop_restore
      LDA $BA
      CMP $6122
      BEQ $7931
      LDA $7D25
      PHA 
      LDA $7D24
      PHA 
      LDA $6120
      JMP $79BD
disk_open
      LDA $BA
      PHA 
      LDA #$00
      STA $BA
      JSR $F34A
      TAY 
      PLA 
      STA $BA
      TYA 
      !byte $b0, $7B
      LDA $BA
      STA fat,X
      JSR $6EA9
      JMP $79A3
disk_load_save
      PHP 
      PHA 
      JSR $7A7F
      LDA $BA
      CMP $6122
      BEQ $797C
      PLA 
      STA $6120
      PLP 
      BCC $796E
      LDA $7D2B
      PHA 
      LDA $7D2A
      PHA 
      LDA $6120
      JMP $79BD
      LDA $7D29
      PHA 
      LDA $7D28
      PHA 
      LDA $6120
      JMP $79BD
disk_load_save_2
      PLA 
      PLP 
      BCS $7983
      JMP $762D
disk_save
      JSR $77D9
      JMP $79A3
disk_system_return_eof_timeout
      LDA #$42
      STA $90
      LDA #$00
      JMP $79B6
disk_system_return_error
      SEC 
      BCS $79A3
disk_system_return_cr_eof
      LDA #$0D
      BIT $00A9
disk_system_return_eof
      STA $6120
      LDA #$FF
      STA $611F
      CLC 
disk_system_return
      BCC $79B0
      ROL $611F
      JSR $6567
      LDA #$0D
      STA $6120
      JSR $79DC
      LDA $6120
      LDX $62F5
      LDY $62F6
      CLC
disk_direct_return 
      STA $6120
      LDA $6121
      PHA 
      LDA #$E8
      PHA 
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      LDA $611D
      STA $FE
      LDA $611E
      STA $FF
      LDA $6120
      RTS 

eof_check
      LDA $611F
      BEQ $79E5
      LDA #$40
      ORA $90
      STA $90
      LDA #$00
      STA $611F
      RTS 

disk_run_stop_restore
      JSR $FF8A
      JSR $7D2E
      LDA #$FE
      PHA 
      LDA #$68
      PHA 
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      RTS 

;****************************************************************************
;   REMOTE DMA ROUTINES
;****************************************************************************
;
;  ram stack_restore_registers_dma_op
;
; read_users_filename
;   dmas system filename into ram at remote_filename_buffer
;
read_users_filename
      LDA $BB
      LDX $BC
      STA $DF02
      STX $DF03
      LDA $B7
      BNE $7A10
      RTS 
      STA $DF07
      LDA #$00
      STA $DF08
      JSR $7EB0
      LDA #$92
      LDX #$01
      STA $DF04
      STX $DF05
      LDY #$A0
      JMP $7A2A
      STY $62F7
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      JMP stack_restore_registers
;
;       call restore dma registers
;       call downloaded code
;       call swap_disk
;       return
;
;
; stack_restore_registers
;
;   call this routine.
;   when returned, the next return you perform will:
;     restore the dma registers
;     restore x,a to value at entry
;     perform an rts
;
;
;   entry:  routine is jsred too
;     .x,.a = x,a registers for return after restore reg
;     dma registers are setup for transfer
;
;   exit: x,a stacked
;     dma registers are stacked for restore registers
;     call to restore registers is stacked
;     y preserved
;
;
;
stack_restore_registers
      PHA 
      TXA 
      PHA 
      LDA $62F7
      ORA #$10
      PHA 
      JMP $7EBE
      !byte $00, $DF,$48,$E8
      CPX #$0B
      BNE $7A42
      LDA $6121
      PHA 
      LDA #$BB
      PHA 
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      LDA $611D
      STA $FE
      LDA $611E
      STA $FF
      CLC 
      RTS 

saving
      LDA #$8E
      LDX #$F6
      JMP $7A70
luking
      LDA #$AE
      LDX #$F5
remote_call
      TAY 
      LDA $6121
      PHA 
      LDA #$AC
      PHA 
      TXA 
      PHA 
      TYA 
      PHA 
      JMP $79BD
      
;****************************************************************************
;     FASTOP ROUTINES
;****************************************************************************
;
; .byte <fastop     ; fast op code start
; .byte <fastop_sa_loc    ; sa location for fastop
; .byte <fastop_dmaop_loc   ; dma_op code 
; .byte <fastop_dma_destination ; low order address of dma_cpu_addr
; .byte <fastop_cntr    ; counter for fastop cycles
; .byte <bsout_fastop_loc   ; opcode for bit or jsr routines, bsout
; .byte <basin_fastop_loc   ; opcode for bit or jsr routines, basin
;
;
;  ram fastop_max
;
;
;
cleanup_fastop_pntr
      PHP 
      PHA 
      LDA $FE
      STA $611D
      LDA $FF
      STA $611E
      LDA $62F8
      BEQ $7AC1
      TXA 
      PHA 
      TYA 
      PHA 
      LDA $6121
      STA $FF
      LDA #$00
      STA $FE
      LDA #$2C
      LDY #$14
      STA ($FE),Y
      LDY #$26
      STA ($FE),Y
      LDA #$60
      LDY #$63
      STA ($FE),Y
      LDY #$00
      SEC 
      LDA $62F8
      SBC ($FE),Y
      JSR $7AC4
      PLA 
      TAY 
      PLA 
      TAX 
      LDA #$00
      STA $62F8
      PLA 
      PLP 
      RTS 
      JMP (cleanup_vector)
      
;
;
; return_setup_fastop
;   swaps disk, and sets up fastop before returning to user
;   does a rts to user with fastop set up
; return_execute_fastop
;   swaps disk, and executes a fastop before returning to user
; 
;   entry:  dma_disk_bank,dma_disk_addr set up
;     cleanup vector pointed to correct cleanup routine.
;     a = number of bytes to fastop
;     c = 0 writeing to disk
;     c = 1 reading from disk
;     sa = set up for current channel
;   exit:
;     control returned to users routine
;
io_fastop
      STA cleanup_vector
      STX cleanup_vector + 1
      LDA current_block
      LDX current_block + 1
      STA $DF05
      JSR $7EB7
      LDA $610E
      STA $DF04
      TYA 
      BCC $7AF5
return_execute_fastop
      TAX 
      LDA $6121
      PHA 
      LDA #$EE
      PHA 
      LDA $6121
      PHA 
      LDA #$CB
      PHA 
      TXA 
      JMP $7AFE
return_setup_fastop
      TAX 
      LDA $6121
      PHA 
      LDA #$E8
      PHA 
      TXA
return_execute_fastop_entry  
      STA $62F8
      LDA #$00
      STA $FE
      LDA $6121
      STA $FF
      LDY #$E2
      BCS $7B28
      LDA #$90
      STA ($FE),Y
      LDY #$60
      LDA $610B
      EOR #$4C
      BNE $7B1D
      LDY #$EA
      TYA 
      LDY #$63
      STA ($FE),Y
      LDA #$2C
      LDX #$20
      BCC $7B30
      LDA #$91
      STA ($FE),Y
      LDA #$20
      LDX #$2C
      LDY #$14
      STA ($FE),Y
      LDY #$26
      TXA 
      STA ($FE),Y
      LDY #$D4
      LDA $B9
      AND #$0F
      STA ($FE),Y
      LDY #$00
      LDA $62F8
      STA ($FE),Y
      LDA $6121
      STA $DF03
      LDA #$E7
      STA $DF02
      LDA #$00
      STA $DF09
      LDA #$80
      STA $DF0A
      LDA #$01
      LDX #$00
      STA $DF07
      STX $DF08
      LDX $62F5
      LDY $62F6
      LDA #$00
      STA $62F7
      LDA $6120
      JMP $7A37

      !fill 138, $00 

      LDA $99
      CMP #$09
      BEQ $7C0B
      JMP $FFFC
      LDA $99
      CMP #$09
      BEQ $7C14
      JMP $FFFC
      BIT $7CC9
      SEC 
      BCS $7C2A
      PHA 
      LDA $9A
      CMP #$09
      BEQ $7C25
      PLA 
      JMP $FFFC
      PLA 
      BIT $7CC9
      CLC 
      JSR $7CAD
      JMP $78E1
      JSR $7C3C
      BCS $7C38
      JMP $FFFC
      STA $99
      CLC 
      RTS 


      LDA #$00
      STA $7C01
      JSR $F30F
      TAX 
      JSR $F314
      BNE $7C55
      JSR $F31F
      LDA $BA
      CMP #$09
      BEQ $7C57
      LDA $B8
      TAX 
      CLC 
      RTS 


      JSR $7C3C
      BCS $7C60
      JMP $FFFC
      STA $9A
      CLC 
      RTS 


      JSR $7CAD
      JMP $7902
      JSR $7C45
      BCS $7C64
      JMP $FFFC
      SEC 
      BIT $18
      JSR $7CAD
      JMP $794D
      PHA 
      TXA 
      PHA 
      TYA 
      PHA 
      CLD 
      LDA #$7F
      STA d2icr
      LDY d2icr
      BMI $7C93
      JSR $F6BC   ; set up kybd
      JSR $FFE1   ; stop key
      BEQ $7C96
      JMP $FE72   ; fake_nmi
      CLC 
      BIT $38
      JSR $7CAD
      JMP $7911   ; disk_open_nmi
;
;
;
;***********************************************************************
;     GET_DISK
;***********************************************************************
;
; 
; swap table
;   contains dma register contents for a normal swap.
;   table must be in reverse order due to perverse method
;   of saving bytes....
;
swap_table
      !byte $00,$00,$1F,$FF,$00,$00,$00
      RTS 
      !byte $00, $B2
swap_table_end
;
;
;
; swap_disk
;   swaps disk and preserves a,x,y, and carry
;
facmp_swap      ; ( kludges to save bytes ) 
      EOR #$09
      BNE $7CC8
      JSR $7CF0
swap_disk
      PHA 
      TXA 
      PHA 
      LDX #$09
      LDA $7C9F,X
      PHA 
      DEX 
      BPL $7CB5
;
;
restore_registers
      LDX #$09
      PLA 
      STA $DF01,X
      DEX 
      BPL $7CBE
      PLA 
      TAX 
      PLA
facmp_rts 
      RTS 

fastop_slow
      JSR $7CF0
      STA $7CE7
      LDA $B9
      AND #$0F
      CMP #$FF
      BNE $7CE6
      LDA $7C00
      BEQ $7CE6
      DEC $7C00
      PLA 
      PLA 
      LDA #$B1
      STA $DF01
      LDA #$00
      CLC
;
;  .ifdef c64
;
fast 
      PHA 
      INC d1ddrb
      CLI 
      PLA 
      RTS 

slow
      PHA 
      SEI 
      LDA #$00
      STA vicspeed
      DEC d1ddrb
      PLA 
      RTS
;  .else
;
;fast  inc d1ddrb    enable stop routine
;  pha     carry must be preserved
;
;vicspeed_restore = *+1
;  lda #0      speed variable name
;  cli     enable irqs
;speed_return
;  sta vicspeed    restore vic speed
;  pla     
;fastop_fake_rts
;  rts     return
;
;slow  pha     save .a
;  sei     kill interupts
;  lda vicspeed    save current speed
;  abs_ref sta,vicspeed_restore
;  dec d1ddrb    disable the stop routine
;  lda #0      go slow vic, and return
;  beq speed_return
;
;  .endif     

;
; for all indirects:
;   this macro calls is arguement as a macro.
;   the first arg in all these calls is the indirect symbol
;
;
      ROL A
      BIT $26
      ASL $1A20,X
      !byte $1C,$30,$32
      CLC 
      ORA #$12
      !byte $23,$36,$5E,$00,$70,$00,$00,$00,$02,$0B,$1A
      !byte $30,$58,$98,$6A,$74,$72,$7B,$3D,$F1,$56,$F1
      !byte $c9,$f1,$0d,$f2,$4f,$f2,$49,$f3,$90,$f2,$FC
      !byte $DE,$F0
      DEC $DEF3,X
      
;***************************************************************************
;     INSTALL VECTORS
;***************************************************************************
;
;
; the following loop actually installs the driver vectors
; if it was hard to write, it should be hard to understand
;
install_vectors
      LDA #$FF
      STA d1prb
      LDA $6121
      STA $FF
      LDA #$00
      STA $FE
      LDX #$09
      LDY $7CFC,X
      LDA $0301,Y
      PHA 
      LDA $0300,Y
      PHA 
      TXA 
      ASL A
      TAY 
      PLA 
      CLC 
      ADC #$FF
      STA $7D1A,Y
      PLA 
      ADC #$FF
      STA $7D1B,Y
      LDY $7CFC,X
      LDA $0300,Y
      LDY $7D06,X
      BEQ $7D72
      STA ($FE),Y
      LDY $7CFC,X
      LDA $0301,Y
      LDY $7D06,X
      INY 
      STA ($FE),Y
      LDY $7CFC,X
      LDA $7D10,X
      STA $0300,Y
      LDA $FF
      STA $0301,Y
      DEX 
      BPL $7D3E
      RTS 


      ASL $28,X
      BIT $4032
      !byte $5A
      ROR $6C
      !byte $77, $9B, $AF, $B7, $CB
      DEC $DED9
      ORA $0E
      ASL $AA50,X
      
;***********************************************************************
;   INSTALL ( not swapped )
;***********************************************************************
;
; install_on_page
;
; installs the disk interface control block on any page in
; the system.
;   entry:  .a = page
;
;     
;      
l7d99 LDA #default_unit_number
      LDX #default_interface_page
l7d9d CLD 
      PHA 
      TXA 
      PHA 
      JSR $7CF0
      LDX #$00
      LDA #$00
      STA $6000,X
      STA first_block,X
      STA $6200,X
      INX 
      BNE $7DA8
      JSR $7E3D
      PLA 
      TAX 
      PLA 
      PHA 
      TXA 
      STA $6121
      JSR $7E22
      PLA 
      JSR $7E08
      JSR $7D2E
      JSR $655C
      JSR $661D
      LDA $6121
      PHA 
      LDA #$E8
      PHA 
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      RTS 

;
; reinstall
;   assumes disk is not destroyed and not installed
;   reinstalls disk at default location
;
; reinstall on page
;   assumes disk is not destroyed and not installed
;   reinstalls disk at location specified
;
;      

l7dde LDA #default_unit_number
      LDX #default_interface_page
l7de2 CLD 
      PHA 
      TXA 
      PHA 
      JSR $7CF0
      LDX #$08
      LDA $7DFF,X
      STA $DF02,X
      DEX 
      BPL $7DEB
      LDA #$B2
      STA $DF01
      PLA 
      TAX 
      PLA 
      JMP $7DBA
      BRK 
      RTS 


      !byte $00,$00,$00,$00, $03, $00,$00
      AND #$1F
      STA $6122
      LDX $6121
      STX $FF
      LDX #$00
      STX $FE
      LDX #$04
      LDY $7D94,X
      STA ($FE),Y
      DEX 
      BPL $7E18
      CLC 
      RTS 


      STA $FF
      LDY #$00
      STY $FE
      LDA $7C00,Y
      STA ($FE),Y
      INY 
      BNE $7E28
      LDX #$0F
      LDA $FF
      LDY $7D84,X
      STA ($FE),Y
      DEX 
      BPL $7E34
      RTS 

;***********************************************************************
;   sniff_disk_size
;***********************************************************************
;
; sniff_disk_size
;   assumes that the disk is present and working, and the 
;   ram is present in an integral number of BANKS.
;
;   sets up major disk pointers:
;     first_block
;     disk_max
;     channel_blocks
;     default_block
;
      LDA #$00
      LDX #$00
      STA default_block
      STX default_block + 1
      LDX #$00
l7E49 TXA 
      EOR #$5A
      STA data_block,X
      DEX 
      BNE l7E49
l7E52 JSR $66D7             ; flush data page to 256 possible banks
      INC default_block + 1
      BNE l7E52
;
l7E5A LDX #$00              ; do
l7E5C TXA                   ; fill data block with different stuff
      EOR #$2C
      STA data_block,X
      DEX 
      BNE l7E5C
      JSR $66D7             ; flush_block
      INC default_block + 1 ; point to next bank
      ;BMI l7E80             ; exit if > 128 banks
      BEQ l7E80              ; exit if > 255 banks (16MB) <-----------------------------------
      ;
      JSR $66D4             ; unflush_block
      LDX #$00              ; check for original stuff
l40   TXA 
      EOR #$5A
      CMP data_block,X      ; if  different
      BNE l7E80             ; break
      DEX 
      BNE l40
      JMP l7E5A             ; loop
;
l7E80 LDA default_block
      LDX default_block + 1
;
;    set up major disk pointers based on size
;
      STA disk_max            ; mark end of disk
      STX disk_max+1
      LDX #$00                ; set up the major disk pointers
      ;LDA #$20
      LDA #>swapped_code_size+1
      STA channel_blocks
      STX channel_blocks + 1
      ;LDA #$22
      LDA #>swapped_code_size+3
      STA first_block
      STX first_block + 1
      STA disk_end
      STX disk_end + 1
      ;LDA #$29
      lda #>swapped_code_size+10
      STA default_block
      STX default_block + 1
      RTS 


      LSR $41
      !byte $42
      STA $7F91
      STA $DF06
      RTS 
      STX $7F91
      STX $DF06
      RTS 
      STA $7F8B
      LDA $7F91
      AND #$07
      CMP #$07
      BEQ $7EE7
      LDX #$02
      LDA dma,X
      PHA 
      INX 
      CPX #$06
      BNE $7ECC
      LDA $7F91
      PHA 
      LDX #$07
      LDA dma,X
      PHA 
      INX 
      CPX #$0B
      BNE $7EDB
      JMP $7A4B
      LDA $DF07
      SBC #$01
      STA $7F8C
      LDA $DF08
      SBC #$00
      STA $7F8D
      CLC 
      LDA $7F8C
      ADC $DF04
      STA $7F8E
      LDA $7F8D
      ADC $DF05
      STA $7F8F
      LDA $7F91
      ADC #$00
      STA $7F90
      CMP $7F91
      BEQ $7ECA
      SEC 
      LDA #$00
      SBC $DF04
      STA $DF07
      LDA #$00
      SBC $DF05
      STA $DF08
      INC $7F8E
      BNE $7F30
      INC $7F8F
      CLC 
      LDA $DF02
      ADC $DF07
      STA $7F8C
      LDA $DF03
      ADC $DF08
      STA $7F8D
      LDA #$7F
      PHA 
      LDA #$58
      PHA 
      LDA $6121
      PHA 
      LDA #$AF
      PHA 
      PHA 
      PHA 
      LDA $7F8B
      PHA 
      JMP $7ECA
      LDA #$00
      STA $DF04
      STA $DF05
      LDA $7F8E
      STA $DF07
      LDA $7F8F
      STA $DF08
      LDA $7F8C
      STA $DF02
      LDA $7F8D
      STA $DF03
      LDX #$02
      LDA dma,X
      PHA 
      INX 
      CPX #$06
      BNE $7F7B
      LDA $7F90
      PHA 
      JMP $7ED9
      !byte $00,$00,$00,$00,$00,$00,$00
      DEC d1ddrb
      LDA $02A1
      AND #$01
      BNE $7F95
      STA vicspeed
      PLA 
      RTS 
