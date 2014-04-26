( Copyright 1990, 1994 Martin Anton Ertl )
( This program is distributed WITHOUT ANY WARRANTY. )
( See gray.doc or gray.f83 for the license. )
s" gray.fs" included
cr .( eps )
1 max-member
eps parser x
cr
.( else )
s" else.fs" included
cr
.( oberon )
s" oberon.fs" included
cr
\ s" graylist.fs" included
\ s" oberon.fs " included
.( calc ) cr
s" calc.fs" included
cr
? 2*3-5/4=
cr
.( mini ) cr
s" mini.fs" included
s" test.min" mini
cr
5 test cr
bye
