tasm /oi run.asm
link386 run,,,d:\emx\lib\os2 thunker,run.def
del/q *.obj *.map >&nul

