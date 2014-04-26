	.386
	.model	FLAT
        .stack 4000H

	assume	cs: FLAT, ds: FLAT, ss: FLAT, es: FLAT

forthsize= 100000H 
target   = 28000H

_TEXT   segment dword public use32 'CODE'

start:
        ADD     ESP,4                   ; DISCARD RETURN ADDRESS
        POP     EAX                     ; GET MODULE HANDLE
        MOV     MODHAND,EAX             ; AND SAVE
        ADD     ESP,4                   ; DISCARD RESERVED
        POP     EAX                     ; GET ENV ADDRESS
        MOV     ENVADDR,EAX             ; AND SAVE
        POP     EAX                     ; GET COMMAND LINE ADDRES
        MOV     CMDADDR,EAX

        mov     savesp,esp
        mov     eax,ss
        mov     savess,eax
                                        ; say hello
        push    offset action           ; bytes read
        push    hi_end - hi             ; bytes to write
        push    offset hi               ; where
        push    1                       ; the file
        call    doswrite                ;
        add     esp,16                  ;

        mov     eax,offset image        ; check image origin
        cmp     eax,target              ;
        je      load_01                 ; continue if ok

        push    offset action           ; say "image in wrong place"
        push    bad_end - bad           ; bytes to write
        push    offset bad              ; where
        push    1                       ; the file
        call    doswrite                ;
        add     esp,16                  ;

        mov     eax,offset image        ; show where image is
        call    hexdot
        jmp     done                    ; and quit right now

; a generic program loader for flat images
; -----

load_01:

; get the name of the executed file
        mov     eax,modhand             ; get the module handle
        push    offset nbuf             ; the buffer for the name
        push    128                     ; 128 bytes long
        push    eax                     ; and the handle
        call    dosquerymodulename      ; and read the name
        add     esp,12                  ; discard

; open it
        push    0                       ; peaop2
        push    40H                     ; read only
        push    11H                     ; fail if new, open if exists
        push    0                       ; attribute
        push    0                       ; size
        push    offset action           ; where to store action taken
        push    offset handle           ; where to store the handle
        push    offset nbuf             ; the name
        call    dosopen                 ; open the file
        add     esp,32                  ; clean stack

; position the file at 8 bytes before end
        push    offset action           ; seek position returned
        push    2                       ; from end of file
        push    -8                      ; 8 bytes       
        push    handle                  ; the default file
        call    dossetfileptr           ; move file pointer
        add     esp,16                  ; discard

; read the last 8 bytes of the executed file
        push    offset action           ; bytes read
        push    8                       ; 8 bytes to read
        push    offset psig             ; where
        push    handle                  ; the file
        call    dosread                 ;
        add     esp,16                  ;

; check for a signature
        mov     eax,isig                ; get my signature
        cmp     eax,psig                ; check against the program sig
        jne     noexe                   ; not equal, no exe present

; position to start of image
        push    offset action           ; seek position returned
        push    2                       ; from end of file
        mov     eax,plen                ; get length to read
        add     eax,8
        neg     eax                     ; negate for seek
        push    eax                     ; 
        push    handle                  ; the default file
        call    dossetfileptr           ; move file pointer
        add     esp,16                  ; discard

; read the image
        push    offset action           ; bytes read
        push    plen                    ; length of image
        push    offset image+100H       ; where
        push    handle                  ; the file
        call    dosread                 ; read it
        add     esp,16                  ; clean up

; close the file
        push    handle
        call    dosclose
        add     esp,4

; and start the image
        jmp     goforth                 ; and start forth
        

; error if no executable image present
; -----

noexe:
        push    offset action           ; bytes read
        push    no_end - nopgm          ; bytes to write
        push    offset nopgm            ; where
        push    1                       ; the file
        call    doswrite                ;
        add     esp,16                  ;

; an easy end
; -----

done:
        push    1
        push    1
        call    dosexit

; an easy entry to forth; tell where stuff is...
; -----

goforth:
        push    offset image + 100H
        mov     ebx,offset dosvect
        mov     ecx,isize
        mov     edx,cmdaddr
        mov     eax,envaddr
        mov     esi,modhand
        ret

; hexdot, number to print in eax
; -----

hexdot:
        mov     ecx,8                   ; 8 digits to print
h_001:  push    ecx                     ; save count
        rol     eax,4                   ; rotate 32 bits around 4
        push    eax                     ; save
        and     eax,15                  ; one digit only
        mov     ebx,offset hexdig       ; point to hex digits
        add     ebx,eax                 ; index into the string
        push    offset action           ; bytes written
        push    1                       ; one byte to write
        push    ebx                     ; from the string
        push    1                       ; write to standard output
        call    doswrite                ; do it
        add     esp,16        
        pop     eax                     ; restore
        pop     ecx                     ; restore
        loop    h_001                   ; and repeat

        mov     ebx,offset hexdig       ; write a space
        add     ebx,16
        push    offset action           ; 
        push    1                       ; one byte to write
        push    ebx                     ; from the string
        push    1                       ; write to standard output
        call    doswrite                ; do it
        add     esp,16        

        ret                             ;

_TEXT   ends

; the data segment
; -----

_DATA   segment dword public use32 'DATA'

dummy   dd      0
savesp  dd      0
savess  dd      0
modhand dd      0
envaddr dd      0
cmdaddr dd      0

; the io vector table
; -----

hexdig  db      '0123456789ABCDEF '

hi      db      'OS/2 Forth Loader, Rick VanNorman 1994',13,10
hi_end  db      0

bad     db      'IMAGE was not allocated at the correct target address.',13,10
        db      'Contact Rick VanNorman immediately!',13,10
        db      'Image was located at '

bad_end db      0

nopgm   db      13,10
        db      'No image present.  An image file must be bound to',13,10
        db      'the executable.  One may be created (for example) by:',13,10
        db      'COPY/B RUN.EXE+FORTH.OS2 FORTH.EXE',13,10,0
no_end  db      0

action  dd      0
handle  dd      0

psig    dd      0
plen    dd      0
        dd      0
        dd      0

isig    label
sig     db      'rcvn'
isize   dd      forthsize

nbuf    db      128 dup (0)

iovect:  

  
include dosvect.asm
include dos16.asm


_DATA   ends

; the definition of IMAGE must be the last in the data segment
; -----

_FDATA   segment dword public use32 'FDATA'

junk            db      39e0H dup (?)          ; a pad, determined by trial
image           db      forthsize dup (?)      ; enough for forth

forth   equ     image+100H

_FDATA ENDS


; external references to the dll
; -----

include dosvect.h
include dos16.h

end start

