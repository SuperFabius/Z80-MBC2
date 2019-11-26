if 1 then print "hi": print "lo"
if 1 then print "this": print "that" else print "what ?"
if 0 then print "help": print "yours" else print "mine"
if 1 then print "blue" else print "yellow": print "orange"
if 0 then print "brown" else print "fucia": print "azure"
if 1 then print "bark": print "mark" else print "zark": print "flark" endif
if 0 then print "whoops": print "whapps" else print "paps": print "maps" endif
if 1 then

   print "this is 1"
   print "this is 2"

endif 

if 1 then

   print "this is 3"
   print "this is 4"

else

   print "this is 5"
   print "this is 6"

endif   

if 0 then

   print "this is 7"
   print "this is 8"

else

   print "this is 9"
   print "this is 10"

endif

if 1 then

   print "yes"
   if 3 then
      print "no"
   else
      print "why"
   endif

else

   print "no no"
   if 0 then
      print "who"
   else
      print "what"
   endif

endif

if 1 then print "wild" else if 2 then print "bite" else print "camping"

if 1 then print "carp": if 1 then print "bat": if 1 then

   print "steelhead"

endif 

if 1 then print "adder" else

   print "whatchacallit"
   print "smack"

endif

if 0 then print "last" else

   print "yep"
   print "howsit"

endif

select 1

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"
   other:  print "something"

endsel

select 2

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"
   other:  print "something"

endsel

select 3

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"
   other:  print "something"

endsel

select 4

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"
   other:  print "something"

endsel

select 234

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"
   other:  print "something"

endsel

select 10

   case 1: print "one"
   case 2: print "two"
   case 3: print "three"

endsel
print "and after"

select "fork"

   case "knife": print "its a knife"
   case "spoon": print "its a spoon"
   case "fork":  print "its a fork"
   other:        print "don't know what it is"

endsel

select 1.2

   case 1.1: print "point 1"
   case 1.2: print "point 2"
   case 1.3: print "point 3"

endsel

select 1: case 1: print "one": case 2: print "two": case 3: print "three" endsel

