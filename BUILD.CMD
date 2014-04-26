@echo off

IF NOT EXIST RUN.EXE GOTO NEEDS

del forth.x   >&nul
new.exe include \forth\build.4
if not exist forth.x goto err

copy forth.x forth.os2
del forth.x >&nul
copy/b run.exe+forth.os2 forth.exe >&nul

echo:
echo The new executable is saved as FORTH.EXE
echo:

GOTO DONE

:err
ECHO Error in compilation.
goto done

:NEEDS
ECHO RUN.EXE needs to be in this directory.

:DONE


