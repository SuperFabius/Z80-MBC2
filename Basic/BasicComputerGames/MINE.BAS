!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                                                                              !
! MINE                                                                         !
!                                                                              !
! Mine is the classic game where a field of hidden mines is presented, and the !
! user tries to find the mines based on mine counts in adjacent squares.       !
!                                                                              !
! Derived from the Pascal version.                                             !
!                                                                              !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! helper defines

false% = 0
true% = -1

! colors

black%   = 0
white%   = 1
red%     = 2
green%   = 3
blue%    = 4
cyan%    = 5
yellow%  = 6
magenta% = 7

! events

etchar%    = 0  ! ANSI character returned
etup%      = 1  ! cursor up one line
etdown%    = 2  ! down one line
etleft%    = 3  ! left one character
etright%   = 4  ! right one character
etleftw%   = 5  ! left one word
etrightw%  = 6  ! right one word
ethome%    = 7  ! home of document
ethomes%   = 8  ! home of screen
ethomel%   = 9  ! home of line
etend%     = 10 ! end of document
etends%    = 11 ! end of screen
etendl%    = 12 ! end of line
etscrl%    = 13 ! scroll left one character
etscrr%    = 14 ! scroll right one character
etscru%    = 15 ! scroll up one line
etscrd%    = 16 ! scroll down one line
etpagd%    = 17 ! page down
etpagu%    = 18 ! page up
ettab%     = 19 ! tab
etenter%   = 20 ! enter line
etinsert%  = 21 ! insert block
etinsertl% = 22 ! insert line
etinsertt% = 23 ! insert toggle
etdel%     = 24 ! delete block
etdell%    = 25 ! delete line
etdelcf%   = 26 ! delete character forward
etdelcb%   = 27 ! delete character backward
etcopy%    = 28 ! copy block
etcopyl%   = 29 ! copy line
etcan%     = 30 ! cancel current operation
etstop%    = 31 ! stop current operation
etcont%    = 32 ! continue current operation
etprint%   = 33 ! print document
etprintb%  = 34 ! print block
etprints%  = 35 ! print screen
etfun%     = 36 ! function key
etmenu%    = 46 ! display menu
etmouba%   = 47 ! mouse button assertion
etmoubd%   = 51 ! mouse button deassertion
etmoumov%  = 55 ! mouse move
ettim%     = 56 ! timer matures
etjoyba%   = 57 ! joystick button assertion
etjoybd%   = 58 ! joystick button deassertion
etjoymov%  = 59 ! joystick move
etterm%    = 60 ! terminate program

! program defines

maxxs%   = 8 ! size of grid
maxys%   = 8
maxmine% = 10 ! number of mines to place

dim mine%(maxxs%, maxys%) ! mine exists map
dim vis%(maxxs%, maxys%)  ! square is uncovered map
dim flag%(maxxs%, maxys%) ! square is flagged map

! Contruct table to calculate adjacent squares

dim xoff%(8) ! x offset table
dim yoff%(8) ! y offset table

xoff%(1) =  0: yoff%(1) = -1 ! up
xoff%(2) = +1: yoff%(2) = -1 ! upper right
xoff%(3) = +1: yoff%(3) =  0 ! right
xoff%(4) = +1: yoff%(4) = +1 ! lower right
xoff%(5) =  0: yoff%(5) = +1 ! down
xoff%(6) = -1: yoff%(6) = +1 ! lower left
xoff%(7) = -1: yoff%(7) =  0 ! left
xoff%(8) = -1: yoff%(8) = -1 ! upper left

! declares, not required but nice

dim x%, y%    ! user move coordinates
dim done%     ! game over
dim centerx%  ! center of screen position x
dim centery%  ! center of screen position y
dim cursorx%  ! cursor location x
dim cursory%  ! cursor location y
dim badguess% ! bad guess display flag
dim mousex%   ! mouse position x
dim mousey%   ! mouse position y

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! 
! Find adjacent mines
!
! Finds the number of mines adjacent to a given square.
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function adjacent%(x%, y%)

dim mines%   ! number of mines
dim xn%, yn% ! neighbor coordinates }
dim i%       ! index for move array }
 
mines% = 0 ! clear mine count
for i% = 1 to 8 ! process points of the compass

   xn% = x%+xoff%(i%) ! find neighbor locations
   yn% = y%+yoff%(i%)
   if xn% >= 1 and xn% <= maxxs% and yn% >= 1 and yn% <= maxys% then

      ! valid location
      if mine%(xn%, yn%) then mines% = mines%+1 ! count mines

   endif

next i%

endfunc mines% ! return the number of mines

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! 
! Set adjacent squares visable
!
! Sets all of the valid adjacent squares visable. If any of those squares are
! not adjacent to a mine, then the neighbors of that square are set visable, etc.
! (recursively).
! This is done to "rip" grids of obviously empty neighbors off the board.
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure visadj(x%, y%)

dim xn%, yn% ! neighbor coordinates
dim i%       ! index for move array
 
for i% = 1 to 8 ! process points of the compass

   xn% = x%+xoff%(i%) ! find neighbor locations
   yn% = y%+yoff%(i%)
   if xn% >= 1 and xn% <= maxxs% and yn% >= 1 and yn% <= maxys% then

      if not vis%(xn%, yn%) then ! not already visable

         ! valid location
         vis%(xn%, yn%) = true% ! set visable
         if adjacent%(xn%, yn%) = 0 then visadj(xn%, yn%) ! perform recursively

      endif

   endif

next i%

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! 
! Display board
! 
! Displays the playing board.
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
procedure display

dim x%
dim y%
dim cnt% ! count of adjacent mines
 
! scan screen
bcolor(yellow%) ! set background color
for y% = 1 to maxys%

   for x% = 1 to maxxs%
   
      cursor(centerx%+x%-1, centery%+y%-1) ! set start of next line
      if vis%(x%, y%) then

         if mine%(x%, y%) then print "*"; else

            cnt% = adjacent%(x%, y%) ! find adjacent mine count
            if cnt% = 0 then
               print "." ! no adjacent
            else
               print chr$(cnt%+asc("0")); ! place the number
            endif

         endif

      else if flag%(x%, y%) then ! display flagged location

         if badguess% then print "X"; else print "M";

      else print "=";
      endif

   next x%

next y%
print

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! 
! Initalize board
!
! Clears all board squares to no mines, invisible and not flagged.
! Then, the specified number of mines are layed on the board at random.
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
procedure clrbrd
 
dim x%
dim y%
dim n%
 
for x% = 1 to maxxs% ! clear minefield

   for y% = 1 to maxys%

      mine%(x%, y%) = false ! set no mine
      vis%(x%, y%) = false ! set not visible
      flag%(x%, y%) = false ! set not flagged

   next y%

next x%
for n% = 1 to maxmine ! place mine

   repeat

      x% = rnd(0)*maxxs%
      y% = rnd(0)*maxys%

   until not mine%(x%, y%) ! no mine exists at square
   mine%(x%, y%) = true ! place mine

next n%

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Clear line
!
! Clears the specified line to spaces in the specified color.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure clrlin(y%, clr%)

dim i%

cursor(1, y%) ! position to specified line
bcolor(clr%) ! set color
for i% = 1 to maxx% do print " "; ! clear line

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Print centered string
!
! Prints the given string centered on the given line.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure prtmid(y%, s$)

cursor(maxx% div 2-len(s$) div 2, y%) ! position to start
print s$; ! output the string

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Draw character box
!
! Draws a box of the given color and character to the location.
! The colors are not saved or restored.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure tbox(sx%, sy%, ex%, ey%, c$, bclr%, fclr%)

dim x%, y% ! coordinates

bcolor(bclr%)
fcolor(fclr%)
cursor(sx%, sy%) ! position at box top left
for x% = sx% to ex%: print c$;: next x% ! draw box top
cursor(sx%, ey%) ! position at box lower left
for x% = sx% to ex%: print c$;: next x% ! draw box bottom
for y% = sy%+1 to ey%-1 ! draw box left side

   cursor(sx%, y%) ! place cursor
   print c$; ! place character

next y%
for y% = sy%+1 to ey%-1 ! draw box left side

   cursor(ex%, y%) ! place cursor
   print c$; ! place character

next y%

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Check coordinates on board
!
! Checks if the given x, y coordinates are in the valid playing area..
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function insquare%(x%, y%)

dim inx% ! inside x
dim iny% ! inside y

inx% = mousex% >= centerx% and mousex% <= centerx%+maxxs%-1 ! find x
iny% = mousey% >= centery% and mousey% <= centery%+maxys%-1 ! find y

endfunc inx% and iny%

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Check replay
!
! Asks the user if a replay is desired, then either cancels the game, or
! sets up a new game as requested.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure replay

! ask user for replay
bcolor(cyan%)
prtmid(maxy%, "PLAY AGAIN (Y/N) ?")
repeat ! wait for response

   ! wait till a character is pressed
   repeat

      event(nextevent)

   until nextevent.etype = etchar% or nextevent.etype = etterm%
   if nextevent.etype = etterm% then done% = true% ! force a quit

until lcase(nextevent.char$) = "y" or lcase(nextevent.char) = "n" or done%
if lcase(nextevent.char$) = "n" or done% then done% = true% else

   ! clear old messages
   clrlin(maxy%-2, cyan%)
   clrlin(maxy%, cyan%)
   ! start new game
   clrbrd ! set up board
   cursorx% = centerx% ! set inital cursor position
   cursory% = centery%
   badguess% = false% ! set bad guesses invisible

endif

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Process square "hit"
!
! Processes a "hit" on a square, which means revealing that square, and possibly
! triggering a mine.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

procedure hit(x%, y%)

dim xi%, yi% ! indexes for board
dim viscnt% ! visable squares count

vis%(x%, y%) = true% ! set that location visable
if mine%(x%, y%) then ! mine found

   ! make all mines visable, and bad guesses too.
   for yi% = 1 to maxys%

      for xi = 1 to maxxs%

         if mine%(xi%, yi%) then vis%(xi%, yi%) = true%

      next xi%

   next yi%
   badguess% = true% ! set bad guesses visable
   display ! redisplay board
   ! announce that to the player
   bcolor(red%)
   prtmid(maxy%-2, "*** YOU HIT A MINE ! ***")
   replay ! process replay

else ! valid hit

   if adjacent%(x%, y%) = 0 then visadj(x%, y%) ! clean up adjacent spaces
   ! now, the player may have won. we find this out by counting all of the
   ! visable squares, and seeing if the number of squares left is equal
   ! to the number of mines
   viscnt% = 0
   for yi% = 1 to maxys%

      for xi% = 1 to maxxs%

         if vis%(xi%, yi%) then viscnt% = viscnt%+1 ! count visible

      next xi%

   next yi%
   if maxxs%*maxys%-viscnt% = maxmine% then ! player wins

      display ! redisplay board
      ! announce that to the player
      bcolor(red%)
      prtmid(maxy%-2, "*** YOU WIN ! ***")
      replay ! process replay

   endif

endif
display ! redisplay board

endproc

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Main process
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

auto(false%) ! turn off scrolling
bcolor(cyan%) ! color the background
clear ! clear to that
bcolor(magenta%)
prtmid(1, "******* Mine game 1.0 ********") ! output title
! find center board position
centerx% = maxx% div 2-maxxs% div 2
centery% = maxy% div 2-maxys% div 2
! draw a border around that
tbox(centerx%-1, centery%-1, centerx%+maxxs%, centery%+maxys%, " ", blue%, black%)
bcolor(white%) ! restore the background
clrbrd ! set up board
display !  display board }
done% = false% ! set game in progress
cursorx% = centerx% ! set inital cursor position
cursory% = centery%
badguess% = false% ! set bad guesses invisible
repeat ! enter user moves

   cursor(cursorx%, cursory%) ! place cursor
   x% = cursorx%-centerx%+1 ! set location on board
   y% = cursory-centery+1
   event(nextevent) ! get the next event
   select nextevent.etype% ! event

      case ettab% ! process flag

         ! reverse flagging on location
         flag(x%, y%) = not flag(x%, y%)
         display ! redisplay board

      case etenter%: hit(x%, y%) ! process hit

      ! move up
      case etup%: if cursory% > centery% then cursory% = cursory%-1

      ! move left
      case etleft%: if cursorx% > centerx% then cursorx% = cursorx%-1

      ! move down
      case etdown%: if cursory% < centery%+maxys%-1 then cursory% = cursory%+1

      ! move right
      case etright%: if cursorx% < centerx%+maxxs%-1 then cursorx% = cursorx%+1

      case etmoumov% ! mouse movement

         mousex% = nextevent.moupx% ! set new mouse position
         mousey% = nextevent.moupy%

      case etmouba ! mouse button 1, hit

         if nextevent.amoubn% = 1 and onboard%(mousex%, mousey%) then

            ! mouse postion inside valid square
            cursorx% = mousex% ! set current position to that
            cursory% = mousey%
            x% = cursorx%-centerx%+1 ! set location on board
            y% = cursory%-centery%+1
            hit(x%, y%) ! process hit

         else if nextevent.amoubn% = 2 and onboard%(mousex%, mousey%) then

            ! mouse postion inside valid square
            cursorx% = mousex% ! set current position to that
            cursory% = mousey%
            x% = cursorx%-centerx%+1 ! set location on board
            y% = cursory%-centery%+1
            ! reverse flagging on location
            flag(x%, y%) = flag(x%, y%)
            display ! redisplay board

         endif

   endsel

until done% or nextevent.etype% = etterm% ! game complete
auto(true%) ! turn off scrolling
bcolor(white%) ! restore colors
fcolor(black%)
clear ! clear screen

end