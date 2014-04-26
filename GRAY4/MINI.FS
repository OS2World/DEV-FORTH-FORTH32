( Copyright 1990,1994 Martin Anton Ertl )
( This program is distributed WITHOUT ANY WARRANTY. )
( See the file COPYING for the license. )

( a compiler for a tiny Pascal-like language )
( to compile a program type `s" file" mini'; the program should be in file )
( This creates a new word [its name is the name given after the program
( keyword], that you must call to execute the program )
( mini programs take their input from the stack and write their )
( output with . )

s" graylist.fs" included

.( Loading mini ... ) cr

( scanner )
( it is implemented using gray to give an example )
( that's probably not the best way )
s" max-char" environment? ?not? [IF]
255
[THEN]
1+ constant eof-char
eof-char max-member ( the whole character set )

variable mini-file

variable tokenval 0 tokenval !
: token ( -- ) ( use: token name ) ( name: -- n )
 ( defines a token that returns a unique value )
 tokenval @ constant
 1 tokenval +! ;

token ";"
token ","
token ":="
token "="
token "#"
token ">"
token "+"
token "-"
token "*"
token "("
token ")"
token Ident
token Number-token
token eof-token

wordlist constant keyword-wordlist
get-current keyword-wordlist set-current
token PROGRAM
token VAR
token BEGIN
token END
token Read
token Write
token IF
token THEN
token WHILE
token DO
set-current

variable numval
variable identp
variable identlen

: ident-string ( -- addr u )
 identp @ identlen @ ;

: adds ( addr1 c -- addr1+1 )
 ( accumulates char to string )
 over c! 1+ ;

: key/ident ( addr u -- n )
 ( checks string at addr for keyword and returns token value )
 keyword-wordlist search-wordlist if
  execute
 else
  Ident
 endif ;

variable ch

: testchar? ( set -- f )
 ch @ member? ;
' testchar? test-vector !

create c1 1 chars allot

: ?nextchar ( f -- )
 \ this will not earn a speed record
 ?not? abort" non-mini character or '=' missing after ':'"
 c1 1 mini-file @ read-file abort" read-file error"
 if \ read <>0 chars
  c1 c@ dup emit ch !
 else
  eof-char ch !
 endif ;

: .. ( c1 c2 -- set )
 ( creates a set that includes the characters c, c1<=c<=c2 )
 empty copy-set
 swap 1+ rot do
  i over add-member
 loop ;

: ` ( -- terminal ) ( use: ` c )
 ( creates anonymous terminal for the character c )
 char singleton ['] ?nextchar make-terminal ;

char a char z ..  char A char Z ..  union  ' ?nextchar  terminal letter
char 0 char 9 ..  ' ?nextchar  terminal digit
0 32 ..  ' ?nextchar  terminal blank
eof-char singleton ' ?nextchar terminal eof-scanner

(( blank **
   (( ` ;      {{ ";"  }}
   || ` ,      {{ ","  }}
   || ` : ` =  {{ ":=" }}
   || ` =      {{ "="  }}
   || ` #      {{ "#"  }}
   || ` >      {{ ">"  }}
   || ` +      {{ "+"  }}
   || ` -      {{ "-"  }}
   || ` *      {{ "*"  }}
   || ` (      {{ "("  }}
   || ` )      {{ ")"  }}
   || eof-scanner {{ eof-token }}
   || {{ 0 }}
      (( {{ 10 * ch @ + [char] 0 - }} cr digit )) ++
      {{ numval !  Number-token }}
   || {{ here identp ! here ch @ adds }} letter
      (( {{ ch @ adds }} (( letter || digit )) )) **
      {{ here - dup identlen !  here swap key/ident }}
   ))
)) <- symbol

symbol parser scan


( parser )
tokenval @ 1- max-member

wordlist constant variable-wordlist ( for mini variables )

variable sym

: testsym? ( set -- f )
 sym @ member? ;
' testsym? test-vector !

: ?nextsym ( f -- )
 ?not? abort" syntax error"
 scan sym ! ;

: t ( n -- ) ( use: token t name )
 singleton ['] ?nextsym terminal ;

get-order keyword-wordlist swap 1+ set-order
";" t ";"
"," t ","
":=" t ":="
"=" t "="
"#" t "#"
">" t ">"
"+" t "+"
"-" t "-"
"*" t "*"
"(" t "("
")" t ")"
Ident t Ident
Number-token t number-parser
PROGRAM t "PROGRAM"
VAR t "VAR"
BEGIN t "BEGIN"
END t "END"
Read t "Read"
Write t "Write"
IF t "IF"
THEN t "THEN"
WHILE t "WHILE"
DO t "DO"
eof-token t eof-parser
previous

: append-string ( addr1 u1 addr2 u2 -- addr1 u3 )
 3 roll >r ( u1 a2 u2 )
 rot 2dup + ( a2 u2 u1 u1+u2 )
 r> swap >r ( a2 u2 u1 a1 )
 dup >r
 + swap move
 r> r> ;

: :name ( addr u -- colon-sys )
 ( defines colon-def whose name is give by addr u )
 pad 0 s" : " append-string 2swap append-string evaluate ;

: variable-name ( addr u -- )
 ( defines variable whose name is given by addr u )
 2dup variable-wordlist search-wordlist abort" variable already defined"
 get-current >r variable-wordlist set-current
 pad 0 s" variable " append-string 2swap append-string evaluate
 r> set-current ;

: getvar ( addr u -- xt )
 ( get the execution token of the var whose name is given by addr u )
 variable-wordlist search-wordlist ?not? abort" variable undefined" ;

: <> ( n1 n2 -- f )
 = ?not? ;

nonterminal Stat
nonterminal Expr

(( {{ numval @ }} number-parser )) <- Number

\ (( {{ identp @ }} ident )) <- Ident

(( Number {{ POSTPONE literal }}
|| {{ ident-string getvar compile, POSTPONE @ }} Ident
|| "(" Expr ")"
)) <- Factor

(( Factor (( "*" Factor {{ POSTPONE * }} )) ** )) <- Term

(( Term  (( (( "+" {{ ['] + }} || "-" {{ ['] - }} )) Term {{ compile, }} )) **
)) Expr rule

(( Expr
   (( "=" {{ ['] = }} || "#" {{ ['] <> }} || ">" {{ ['] > }} ))
   Expr {{ compile, }}
)) <- Cond

Stat ";" && ?? <- StatSeq

(( "Read" {{ ident-string getvar compile, POSTPONE ! }} Ident )) <- ReadStat

(( "Write" Expr {{ POSTPONE . }} )) <- WriteStat

(( {{ ident-string getvar }} Ident ":=" Expr {{ compile, POSTPONE ! }}
)) <- AssStat

(( "IF" Cond {{ POSTPONE if }} "THEN" StatSeq "END" {{ POSTPONE endif }}
)) <- IfStat

(( {{ POSTPONE begin }} "WHILE" Cond {{ POSTPONE while }} "DO"
   StatSeq "END" {{ POSTPONE repeat }}
)) <- WhileStat

(( ReadStat || WriteStat || AssStat || IfStat || WhileStat )) Stat rule

(( "VAR" {{ get-current variable-wordlist set-current }}
   (( {{ ident-string variable-name }} Ident )) "," &&
   {{ set-current }}
)) <- Decl

(( "PROGRAM" {{ identlen @ aligned allot ident-string }} Ident  Decl ??
   {{ :name }} "BEGIN" StatSeq {{ POSTPONE ; }} "END" eof-parser
)) <- Program

Program parser parsemini

: mini ( addr u -- )
 \ process the mini file whose name is given by addr u
 r/o open-file abort" file opening error" mini-file !
 true ?nextchar true ?nextsym parsemini
 mini-file @ close-file abort" file closing error" ;

