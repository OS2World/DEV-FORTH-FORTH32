@echo off
REM this is an OS/2 .CMD file to recompile Forth

IF (%1)==(DOS) GOTO DOS
IF (%1)==(DOs) GOTO DOS
IF (%1)==(DoS) GOTO DOS
IF (%1)==(Dos) GOTO DOS
IF (%1)==(dOS) GOTO DOS
IF (%1)==(dOs) GOTO DOS
IF (%1)==(doS) GOTO DOS
IF (%1)==(dos) GOTO DOS


IF NOT EXIST RUN.EXE GOTO NEEDS

DEL NEW.X >&NUL

FORTH.exe 1 CONSTANT #OS2 INCLUDE APPS\META32 BYE
IF not EXIST NEW.X  goto err
COPY NEW.X NEW.OS2 >NUL
DEL NEW.X >&NUL
COPY/B RUN.EXE+NEW.OS2 NEW.EXE >NUL

echo:
echo The new kernel is bound as NEW.EXE
echo Type BUILD to extend it into a full system.
goto done

:err
Echo Error in compilation.
goto done

:NEEDS
ECHO RUN.EXE needs to be in this directory to compile 32/FORTH for OS/2.
goto done

:DOS
DEL NEW.X32
FORTH.exe 1 CONSTANT #DOS INCLUDE APPS\META32 BYE
IF not EXIST NEW.X  goto err
COPY NEW.X NEW.X32
DEL NEW.X

echo:
echo The new kernel is saved as NEW.X32
echo Type BUILD to extend it into a full system.

:DONE

