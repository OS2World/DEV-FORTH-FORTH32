comment |

***************************************************************************

             EXEC32: A very simple DPMI application loader

                   (C) Copyright 1993 Rick VanNorman

The author (Rick VanNorman) assumes no responsibility for the use or the
misuse of this program.  All standard disclaimers apply.


***************************************************************************|

        Page 92,124
        %NOSYMS

; compile an error handler based on the specified test.  handler will
; print the specified message and exit the program

qerr    macro   tst,num                 ;
        local   x,y                     ;
        &tst    x                       ;
        jmp     y
x:      mov     si,offset emsg&num
        call    msg
        jmp     bye
y:
        endm

;\ -----

        .MODEL  small
        .STACK  2048
        .386                            ; Instructions require 80386

        .DATA

; to make the loader simple, there are a few things that
; it must know about the application which is to be loaded.

app_maxsize equ     08000h              ; max bytes from source file
app_entry   equ     0100h               ; entry point, zero based
app_start   equ     0000h               ; first byte in file, zero based

newtail     db      128 dup (0)

exename     db      256 dup (0)
            db      0

; internally used data structure holding a 386 memory descriptor

desc        equ     $                   ; a data structure for holding
            dw      0000                ; a memory descriptor
            dw      0000
            db      00
acc1        db      00                  ; the access rights byte(s)
acc2        db      00                  ; which we need
            db      00

inprot      dw      0000                ; flag, true if in protected mode
                                        ; used for EMIT

realds      dw      0000                ; the real mode DS we are running in
                                        ; which we need for DOS access
saves       dw      0000                ; ES needed for clean exit by DPMI

handle      dw      0000                ; handle for file io
jmpoff      dw      0000                ; address for the long jump
            dw      0000                ; to the application
jmpcs       dw      0000                ; as a 48-bit pointer

nextaddr    dd      0000
realseg     dw      0000                ; segment of the real-mode 64k pad
realsel     dw      0000                ; selector of the real-mode 64k pad

codselector dw      0000                ; application code page selector
BufSelector DW      0000                ; application data page selector
BufLAddrH   DW      0000                ; linear address of the application
BufLAddrL   DW      0000

DPMIent     DD      00000000            ; address of the DPMI entry routine

himsg       db      'DPMI Protected Mode Loader for DOS '
            db      '(C) 1993 Rick VanNorman',13,10,0

yesexe      db      'found name',13,10,0
noexe       db      'no name',13,10,0
toolong     db      'name is too long',13,10,0
EMsg1       DB      'No DPMI host detected',13,10,0
EMsg4       DB      'Could not allocate LDT',13,10,0
EMsg5       DB      'Could not set up DPMI buffer',13,10,0
EMsg6       DB      'Could not set descriptor base address',13,10,0
EMsg7       DB      'Could not set descriptor limit',13,10,0
emsg9       db      'Could not set descriptor to 32 bits',13,10,0
emsg10      db      'Could not clone descriptor',13,10,0
emsg11      db      'Could not make selector executable',13,10,0
emsg13      db      'Could not allocate real memory buffer',13,10,0
emsg14      db      'Error opening the file',13,10,0
emsg15      db      'Error reading the file',13,10,0
emsg16      db      'Error closing the file',13,10,0
emsg17      db      '.BIN file too small',13,10,0
emsg19      db      'Could not get descriptor',13,10,0
emsg20      db      'LSEEK error in GETSIZE',13,10,0
emsg21      db      'bad read in GETSIZE',13,10,0
emsg22      db      'bad signature',13,10,0

pad         equ     this word
            dd      0,0,0,0
imsizelo    dw      0
imsizehi    dw      0

sizptr      equ     this dword
sizptrlo    dw      0
sizptrhi    dw      0

istart      equ     this dword
istartlo    dw      0
istarthi    dw      0

psig        equ     this dword
psiglo      dw      0
psighi      dw      0
plen        dd      0
            db      0

isig        label
isiglo      dw      'cr'
isighi      dw      'nv'
            db      0

;\ -----
;
; a data structure for calling real-mode interrupts from protected-mode
; via DPMI's INT 31H service 300H

RegSet      EQU     THIS BYTE
SaveDI      EQU     THIS WORD
SaveEDI     DD      00000000
SaveSI      EQU     THIS WORD
SaveESI     DD      00000000
SaveBP      EQU     THIS WORD
SaveEBP     DD      00000000
            DD      00000000            ;Reserved area--set to 0
SaveBX      EQU     THIS WORD
SaveEBX     DD      00000000
SaveDX      EQU     THIS WORD
SaveEDX     DD      00000000
SaveCX      EQU     THIS WORD
SaveECX     DD      00000000
SaveAX      EQU     THIS WORD
SaveEAX     DD      00000000
SaveFlags   DW      0000
SaveES      DW      0000
SaveDS      DW      0000
SaveFS      DW      0000
SaveGS      DW      0000
SaveIP      DW      0000
SaveCS      DW      0000
SaveSP      DW      0000
SaveSS      DW      0000

;\ -----

        .CODE
        .STARTUP

entry:

; The following memory allocation code works because it is known that MASM
; sets DS and SS to the same segment address in the startup code.  Also, ES
; is set to the PSP for the program upon entry.

        MOV     BX,DS           ; Point to start of data segment
        MOV     AX,ES           ; Point to start of PSP
        SUB     BX,AX           ; Number of segments for code & data
        MOV     AX,SP           ; SP is pointing to top of stack area
        MOV     CL,4            ; Dividing by 16
        SHR     AX,CL
        ADD     BX,AX           ; BX=paragraphs needed
        MOV     AH,4Ah          ; Modify memory allocation
        INT     21h

        mov     realds,ds       ; save ds
        mov     saves,es        ; save ES for exit

        mov     si,offset himsg ; say hello to the world
        call    msg
        call    copyt1
        call    chase

        call    getsize         ; figure out how much memory to allocate

        call    go_dpmi         ; see if host is present
        qerr    jc,1            ; carry set if not; else running protected now
        call    init_dpmi       ; setup dpmi memory spaces

        call    openapp         ; read the application image
        call    skipldr
        mov     edi,100h        ; initial address for write into memory
        mov     nextaddr,edi
x001:   call    readapp         ; from the specified file
        or      ax,ax           ; check ax for no bytes
        jz      x002            ; and continue
        call    copyapp         ; and write it into the extended buffer
        jmp     x001            ; repeat until all bytes read
x002:   call    closeapp        ; close the file
        call    copyt2

goto_app:                       ; here, we jump into the application
                                ; pretty much leaving this code forever...

        mov     ax,codselector          ; setup the jmp with
        mov     jmpcs,ax                ; the far cs
        mov     ax,app_entry            ; to location
        mov     jmpoff,ax               ;
        push    ds                      ; copy ds
        pop     fs                      ; into fs, for the far jmp
        mov     ax,realsel              ; realsel for access to other page
        mov     bx,realseg              ; also realseg
        mov     cx,saves                ; pass the real ES for clean exit
        mov     dx,ds                   ; give data segment to application
        mov     ds,bufselector          ; get the far ds
        jmp     fword ptr fs:jmpoff     ; go to the 32-bit program
                                        ; realsel in ax
                                        ; realseg in bx
                                        ; saves   in cx (needed for exit)

;\ -----
; The following routine checks to see if a DPMI master program is installed
; and enters protected mode if one is.  carry is clear if successful,
; set if an error occured

go_dpmi PROC    NEAR
        MOV     AX,1687h        ; Get DPMI host address
        INT     2Fh             ; Multiplex interrupt
        CMP     AX,0            ; Was it there?
        JNE     Nodpmi          ; Nope, so exit

        MOV     WORD PTR DPMIent,DI
        MOV     WORD PTR DPMIent+2,ES
        MOV     BX,SI           ; MEMORY REQUIRED

        MOV     AX,0            ; In case no memory needed
        CMP     BX,0            ; Any allocation needed?
        JE      PM1             ; No, so continue
        MOV     AH,48h          ; Allocate memory
        INT     21h
        jc      nodpmi

PM1:    MOV     ES,AX           ; Segment of allocated memory
        MOV     AX,1            ; Indicate 32-bit application
        CALL    DPMIent         ; Switch to protected mode
        jc      nodpmi

        mov     ax,es           ;  get es
        mov     saves,es        ;  and save it
        mov     ax,1
        CLC                     ; Set for no error
        JNC     Done

nodpmi: STC
        mov     ax,0
Done:
        mov     inprot,ax
        ret

go_dpmi ENDP

;\ -----
; Initialize the dpmi memory spaces.
; 1. Allocate a descriptor for the application as data.
; 2. Allocate memory for the application (1meg, hardcoded for now)
; 3. Bind the descriptor to the allocated memory.
; 4. Set the limits of the allocated memory
; 5. Clone the descriptor, and make the clone executable and 32-bits
; 6. Allocate a real-mode 64K pad for communications with DOS

init_dpmi   proc    near

        PUSH    DS
        POP     GS              ; Save the data selector in secure place

        MOV     CX,1            ; allocate one descriptor
        call    ldtalloc
        MOV     BufSelector,AX

        MOV     BX,imsizehi     ; BX:CX = bytes wanted
        MOV     CX,imsizelo
        call    dpmi_alloc      ; allocate the memory
        MOV     BufLAddrH,BX    ; and the linear address
        MOV     BufLAddrL,CX

        MOV     BX,BufSelector  ; Move selector to proper place
        MOV     CX,BufLAddrH    ; Get linear address in CX:DX
        MOV     DX,BufLAddrL
        call    set_base        ; set the base address of the descriptor

        MOV     BX,BufSelector
        MOV     CX,imsizehi     ; Buffer size - 1 in CX:DX
        MOV     DX,imsizelo
        SUB     DX,1
        SBB     CX,0
        call    set_lim         ; set the buffer limit

        mov     bx,bufselector  ; clone the dpmi data segment
        call    clone           ; so it is executable
        mov     codselector,ax  ; and save it

        mov     bx,codselector  ; make the code selector
        call    make32          ; 32 bits
        mov     bx,codselector  ; and
        call    makeexe         ; executable

        mov     bx,bufselector  ; make the data selector
        call    make32          ; 32 bits also

        mov     ax,0100h        ; allocate 64 KB buffer in
        mov     bx,1000h        ; conventional memory for
        int     31h             ; communication with DOS
        qerr    jc,13           ; jump, allocation failed
        mov     realseg,ax      ; save segment of block
        mov     realsel,dx      ; save selector for block

        ret

init_dpmi   endp

;\ -----
; A bunch of small dpmi access words to make programming simpler.

dpmi_access proc

dpmi_alloc:
        MOV     AX,0501h        ; Allocate memory block
        INT     31h
        qerr    JC,5
        ret

ldtalloc:
        MOV     AX,0000h        ; Allocate LDT descriptor
        INT     31h
        qerr    JC,4            ; Could not allocate descriptor
        ret

set_base:
        MOV     AX,0007h        ; Set base address to address
        INT     31h
        qerr    JC,6            ; Could not set base address
        ret

set_lim:
        MOV     AX,0008h        ; Set limit
        INT     31h
        qerr    JC,7            ; Could not set limit
        ret

getdesc:
        mov     ax,0bh
        push    ds
        pop     es
        mov     edi,offset desc
        int     31h
        qerr    jc,19
        ret

make32:
        push    bx
        call    getdesc         ; get the descriptor
        mov     cl,acc1         ; get the access rights byte #1
        mov     ch,acc2         ; get #2
        or      ch,40h          ; set the bit bit
        pop     bx
        mov     ax,9            ; function code
        int     31h
        qerr    jc,9
        ret

clone:
        mov     ax,0ah          ; function
        int     31h             ;
        qerr    jc,10
        ret

makeexe:
        push    bx
        call    getdesc
        mov     cl,acc1         ; get the access rights byte #1
        mov     ch,acc2         ; get #2
        or      cl,08h          ; readable conforming code segment
        pop     bx
        mov     ax,9            ; function code
        int     31h
        qerr    jc,11
        ret

dpmi_access endp

;\ -----
; save the processor registers in the data structure as required by
; the dpmi service to call real-mode interrupts, such as INT 21H

SaveRegs    PROC    NEAR
            PUSH    EAX
            PUSH    DS
            PUSH    GS
            POP     DS                  ;Default data selector
            MOV     SaveEAX,EAX
            MOV     SaveEBX,EBX
            MOV     SaveECX,ECX
            MOV     SaveEDX,EDX
            MOV     SaveESI,ESI
            MOV     SaveEDI,EDI
            MOV     SaveEBP,EBP
            PUSHF
            POP     AX
            MOV     SaveFlags,AX
            POP     DS
            POP     EAX
            RET
SaveRegs    ENDP

;\ -----
; restore the registers from the data stucture

GetRegs     PROC    NEAR
            PUSH    DS
            PUSH    GS
            POP     DS                  ;Default data selector
            MOV     AX,SaveFlags
            PUSH    AX
            POPF
            MOV     EAX,SaveEAX
            MOV     EBX,SaveEBX
            MOV     ECX,SaveECX
            MOV     EDX,SaveEDX
            MOV     ESI,SaveESI
            MOV     EDI,SaveEDI
            MOV     EBP,SaveEBP
            POP     DS
            RET
GetRegs     ENDP


;\ -----
; execute a dos function (int21h) based on the data structure
; built by SAVEREGS.  this is a prototype that could be used
; to call any real-mode interrupt service.

DOSfunc     PROC    NEAR
            PUSH    AX
            PUSH    BX
            PUSH    CX
            PUSH    ES
            push    edi
            MOV     AX,0300h            ;Simulate real-mode interrupt
            MOV     BL,21h              ;Want the DOS interrupt
            MOV     BH,0                ;Should be 0
            MOV     CX,0                ;Copy nothing from stack
            PUSH    DS
            POP     ES                  ;ES:DI must point to data structure
            MOV     EDI,OFFSET RegSet
            INT     31h
            pop     edi
            POP     ES
            POP     CX
            POP     BX
            POP     AX
            RET
DOSfunc     ENDP

; -----
; chase the name of the command executed. it is in the env following
; a 01 00 pattern, and is asciiz

chase:
        push    es
        push    ds
        mov     ax,es:[44]              ; get env segment from psp
        mov     ds,ax                   ; set in ds
        mov     si,0                    ; initial offset is zero
        mov     cx,4096                 ; don't search more than 4k
c001:   mov     ax,[si]                 ; get 2 bytes
        cmp     ax,0001                 ; check for marker
        je      c002                    ; found, exit
        inc     si                      ; increment pointer by 1 char
        loop    c001                    ; repeat until end of string

        pop     ds                      ; restore ds
        pop     es
        mov     si,offset noexe         ; tell "can't find name
        call    msg
        jmp     bye
                        
c002:   pop     es                      ; this was ds, but use es for now
        inc     si                      ; skip past marker
        inc     si                      ; 
        mov     di,offset exename
        mov     cx,256                  ; max 256 chars in name
c003:   mov     dl,[si]                 ; read one char
        mov     es:[di],dl              ; save it in data seg (es)
        cmp     dl,0                    ; check for end
        je      c004                    ; exit if end
        inc     di                      ; bump both pointers
        inc     si                      ;
        loop    c003                    ; and loop
        push    es
        pop     ds
        pop     es
        mov     si,offset toolong
        call    msg
        jmp     bye

c004:
        push    es
        pop     ds                      ; restore ds
        pop     es
        ret



;\ -----
; getsize, read the image and determine how big the flat arena is to be

getsize:
        call    openexe                 ; open the exe file
        call    gotosig                 ; seek end of file - 8
        call    readsig                 ; read the last 8 bytes
        call    cheksig                 ; check the signature
        call    gotosiz                 ; goto the size indicator (image+10)
        call    readsiz                 ; read the size indicator
        call    clozexe                 ; close the exe file
        ret

openexe:
        mov     dx,offset exename       ; using the appname
        mov     ax,03d00h               ; open the file for read
        int     21h                     ;
        qerr    jc,14                   ; abort if error
        mov     handle,ax               ; save handle otherwise
        ret

gotosig:
        mov     ah,42h                  ; lseek command
        mov     bx,handle               ; handle in bx for seek
        mov     cx,-1                   ; 8 bytes before end
        mov     dx,-8                   ; as a double number
        mov     al,2                    ; "end of file" mode
        int     21h                     ; dos
        qerr    jc,20                   ; error
        ret

readsig:
        mov     bx,handle
        mov     dx,offset psig          ; a place to put the info
        mov     cx,8                    ; 8 bytes
        mov     ax,03f00h               ; read file
        int     21h
        qerr    jc,21                   ; bad read
        ret

cheksig:
        mov     ax,isiglo               ; check the signature
        cmp     ax,psiglo               ; against what was read
        qerr    jne,22
        mov     ax,isighi               ; check the signature
        cmp     ax,psighi               ; against what was read
        qerr    jne,22
        ret

gotosiz:
        mov     eax,plen                ; get the size info from data
        add     eax,8                   ; 8 bytes extra
        neg     eax                     ; negative offset
        mov     istart,eax              ; save where image starts in exe
        
        mov     ah,42h                  ; lseek command
        mov     bx,handle               ; handle in bx for seek
        mov     dx,istartlo             ; position file at size info
        mov     cx,istarthi             ; 
        mov     al,2                    ; "end of file" mode
        int     21h                     ; dos
        qerr    jc,20                   ; error
        mov     istarthi,dx             ; the actual absolute start offset 
        mov     istartlo,ax             ; of the image
        ret

readsiz:
        mov     bx,handle               ; handle in bx for read
        mov     dx,offset pad           ; address to read to
        mov     cx,14h                  ; bytes to read
        mov     ax,03f00h               ; read a file
        int     21h                     ;
        qerr    jc,15                   ; abort if error
        ret

clozexe:
        mov     bx,handle               ; get handle again
        mov     ax,03e00h               ; close the file
        int     21h                     ;
        qerr    jc,16                   ; abort if error closing
        ret                             ; and return

;\ -----
; open the application. name is fixed at APPNAME, the handle of the
; well opened file is kept in HANDLE

openapp:
        mov     edx,offset exename
        mov     al,0
        mov     ah,03dh
        push    ds
        call    saveregs
        mov     ax,realds
        mov     saveds,ax
        call    DOSfunc
        call    getregs
        pop     ds
        qerr    jc,14
        mov     handle,ax
        ret

; read the application into the DOS buffer. uses a fixed size read
; which makes life simple

readapp:
        mov     ah,03fh
        mov     dx,0
        MOV     CX,app_maxsize
        mov     bx,handle
        call    saveregs
        mov     ax,realseg
        mov     saveds,ax
        call    DOSfunc
        call    getregs
        qerr    jc,15
        ret

skipldr:
        mov     ah,03fh
        mov     dx,0
        MOV     CX,istartlo
        mov     bx,handle
        call    saveregs
        mov     ax,realseg
        mov     saveds,ax
        call    DOSfunc
        call    getregs
        qerr    jc,15
        ret

; copy the application from the real-mode DOS buffer into the DPMI buffer

copyapp:
        mov     edi,nextaddr
        mov     ax,realsel      ; the selector for the buffer where data is
        mov     es,bufselector  ; the selector of where the data goes
        mov     esi,0           ; offset souce = 0
        mov     ecx,app_maxsize ; number of bytes
        push    ds
        mov     ds,ax           ; set source selector
        db      67h             ; addresses are 32bits
        rep     movsb           ; do copy
        pop     ds
        mov     nextaddr,edi
        ret

copyt1:
        push    ds
        push    es
        pop     ds
        pop     es
        mov     di,offset newtail
        mov     si,80h
        mov     cx,80h
        rep     movsb
        push    ds
        push    es
        pop     ds
        pop     es
        ret

copyt2:
        mov     es,bufselector
        mov     di,80h
        mov     si,offset newtail
        mov     cx,80h
        rep     movsb
        ret


; close the application file.

closeapp:
        mov     ah,03eh
        mov     bx,handle
        call    saveregs
        call    DOSfunc
        call    getregs
        qerr    jc,16
        ret

;\ -----
; Print a single character, either directly thru DOS or indirectly thru
; DPMI (depending on the state of INPROT).  This allows the use of a
; single string printing routine.

emit    proc    near            ; print the char in dl

        mov     ah,02
        cmp     inprot,0        ; check for inprot
        je      DOSemit

dpmiemit:
        call    saveregs
        call    DOSfunc
        call    getregs
        ret

DOSemit:
        INT     21h
        ret

emit    endp

;\ -----
; Print an ASCIIZ string, pointed to by DS:(E)SI.  Uses EMIT.

msg     proc    near            ; output the asciiz message at DS:(E)SI

msg1:   mov     dl,[si]         ; read next char
        inc     si              ; increment pointer
        cmp     dl,0            ; check char
        je      msg2            ; bailout if null
        call    emit            ; otherwise print the char
        jmp     msg1            ; and do another
msg2:   ret

msg     endp


;\ -----
; exit in case of errors

bye:                                    ; bail out of the loader
        mov     al,1                    ; flag, cause this exit is for errors!
        mov     ah,4ch
        mov     es,saves                ; restore es just in case dpmi needs it
        int     21h


        END
