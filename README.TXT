This is a public-domain release of FORTH32 by Rick VanNorman.
(C) 1993,1994 Rick VanNorman, All Rights Reserved

These files may be distributed freely and used for any purpose
whatsoever, as long as this copyright notice remains intact.  The user
bears all responsibility for damages, real or consequential, caused by
using this software.  Support might be available if the price is right.

FORTH32 is a flat 32-bit subroutine threaded Forth for DOS-DPMI and as a
native text-mode application for OS/2.  It is ANS-Compliant (as best I
can tell) and contains the full ANS wordset implementation, including
all the extension wordsets except LOCALS.  The DOS version has a
built-in editor for code VIEWing, and the OS/2 version has hooks
precompiled in it to link to GNU-EMACS for VIEWing.  The OS/2 version is
also fully multi- threaded and supports all the DOS, VIO, and MOUSE
system calls from high-level code.

To install, type PKUNZIP -d A:FORTH32.ZIP (or some variation thereof).  The
zip file contains the root directory, which needs to live at the root of
your drive.

There are two executable files included in the package --

        FORTH.COM       DOS-DPMI Forth
        FORTH.EXE       OS/2 Native Forth

Delete which-ever one you don't want.  The batch (and CMD) files are:

        MAKE            Recompile the forth kernel
        BUILD           Build the full-blown forth system


Address all questions via email only to

        rick@thunder-ink.com

Rick VanNorman

