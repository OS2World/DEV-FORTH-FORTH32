( Copyright 1990,1994 Martin Anton Ertl )
( This program is distributed WITHOUT ANY WARRANTY. )
( See the file COPYING for the license. )

( list construct for parsing )
( a b && is the same as < a < b a > * > )

( simple solution )
( : && \ syntax-expr1 syntax-expr2 -- syntax-expr3 )
( over concat ** concat ; )

binary-syntax-expr
 cell context-var test-set
constant list-syntax-expr

: compute-list ( -- first follow )
 operand1 compute dup if
  swap operand2 get-first union swap
 endif ;

: propagate-list ( follow -- )
 operand2 compute if
  operand1 get-first union
 endif
 union
 dup operand1 propagate ( follow1 )
 operand1 compute if
  union
 else
  swap drop
 endif
 operand2 propagate ;

: generate-list ( -- )
 [compile] begin
 operand1 generate
 test-set @ compile-test
 [compile] while
 operand2 generate
 [compile] repeat ;

: pass2-list ( -- )
 operand2 compute if
  operand1 get-first union
 endif
 dup test-set !
 follow-set @ check-conflict
 pass2-binary ;

create list-map
', compute-list
', propagate-list
', generate-list
', pass2-list

: && ( syntax-expr1 syntax-expr2 -- syntax-expr3 )
 list-map make-binary 0 , ;

