REM @echo off

IF NOT EXIST x32.EXE GOTO NEEDS

del forth.x   >&nul
NEW include build.4 bye
if not exist forth.x goto err

copy/B X32.EXE+forth.x forth.COM
del forth.x >&nul

echo:
echo The new executable is saved as FORTH.COM
echo:

GOTO DONE

:err
ECHO Error in compilation.
goto done

:NEEDS
ECHO X32.EXE needs to be in this directory.

:DONE


