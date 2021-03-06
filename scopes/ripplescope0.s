����  Et  �                                *******************************************************************************
*                       External quadrascope for HippoPlayer
*				By K-P Koljonen
*******************************************************************************

MC68000 =	0


*** Includes:

 	incdir	include:
	include	exec/exec_lib.i
	include	exec/ports.i
	include	exec/types.i
	include	graphics/graphics_lib.i
	include	graphics/rastport.i
	include	intuition/intuition_lib.i
	include	intuition/intuition.i
	include	dos/dosextens.i
	incdir

*** Some useful macros

lob	macro
	jsr	_LVO\1(a6)
	endm

lore	macro
	ifc	"\1","Exec"
	ifd	_ExecBase
	ifeq	_ExecBase
	move.l	(a5),a6
	else
	move.l	_ExecBase(a5),a6
	endc
	else
	move.l	4.w,a6
	endc
	else
	move.l	_\1Base(a5),a6
	endc
	jsr	_LVO\2(a6)
	endm

pushm	macro
	ifc	"\1","all"
	movem.l	d0-a6,-(sp)
	else
	movem.l	\1,-(sp)
	endc
	endm

popm	macro
	ifc	"\1","all"
	movem.l	(sp)+,d0-a6
	else
	movem.l	(sp)+,\1
	endc
	endm

push	macro
	move.l	\1,-(sp)
	endm

pop	macro
	move.l	(sp)+,\1
	endm



*** HippoPlayer's port:

	STRUCTURE	HippoPort,MP_SIZE
	LONG		hip_private1	* Private..
	APTR		hip_kplbase	* kplbase address
	WORD		hip_reserved0	* Private..
	BYTE		hip_quit
	BYTE		hip_opencount	* Open count
	BYTE		hip_mainvolume	* Main volume, 0-64
	BYTE		hip_play	* If non-zero, HiP is playing
	BYTE		hip_playertype 	* 33 = Protracker, 49 = PS3M. 
	*** Protracker ***
	BYTE		hip_reserved2
	APTR		hip_PTch1	* Protracker channel data for ch1
	APTR		hip_PTch2	* ch2
	APTR		hip_PTch3	* ch3
	APTR		hip_PTch4	* ch4
	*** PS3M ***
	APTR		hip_ps3mleft	* Buffer for the left side
	APTR		hip_ps3mright	* Buffer for the right side
	LONG		hip_ps3moffs	* Playing position
	LONG		hip_ps3mmaxoffs	* Max value for hip_ps3moffs

	BYTE		hip_PTtrigger1
	BYTE		hip_PTtrigger2
	BYTE		hip_PTtrigger3
	BYTE		hip_PTtrigger4

	LABEL		HippoPort_SIZEOF 

	*** PT channel data block
	STRUCTURE	PTch,0
	LONG		PTch_start	* Start address of sample
	WORD		PTch_length	* Length of sample in words
	LONG		PTch_loopstart	* Start address of loop
	WORD		PTch_replen	* Loop length in words
	WORD		PTch_volume	* Channel volume
	WORD		PTch_period	* Channel period
	WORD		PTch_private1	* Private...

*** Dimensions:

WIDTH	=	320	
HEIGHT	=	256
RHEIGHT	=	HEIGHT+4
PLANE	=	RHEIGHT*WIDTH/8

*** Variables:

	rsreset
_ExecBase	rs.l	1
_GFXBase	rs.l	1
_IntuiBase	rs.l	1
port		rs.l	1
owntask		rs.l	1
screenlock	rs.l	1
oldpri		rs.l	1
windowbase	rs.l	1
rastport	rs.l	1
userport	rs.l	1
windowtop	rs	1
windowtopb	rs	1
windowright	rs	1
windowleft	rs	1
windowbottom	rs	1
draw1		rs.l	1
draw2		rs.l	1
icounter	rs	1
icounter2	rs	1

wbmessage	rs.l	1
omabitmap	rs.b	bm_SIZEOF

tr1		rs.b	1
tr2		rs.b	1
tr3		rs.b	1
tr4		rs.b	1

vol1		rs	1
vol2		rs	1
vol3		rs	1
vol4		rs	1


SINPOS	=	0
AMP	=	2
SIZ2	=	4

 ifne MC68000
PIST		=	30
 else
PIST		=	50
 endc

X		=	0
Y		=	2
Z		=	4
DIST		=	6
SIZ		=	8

divtab		rs	16384


size_var	rs.b	0

*** Program

main	lea	var_b,a5		* Store execbase
	move.l	4.w,a6
	move.l	a6,(a5)

	bsr.w	getwbmessage

	lea	intuiname(pc),a1	* Open libs
	lore	Exec,OldOpenLibrary
	move.l	d0,_IntuiBase(a5)

	lea 	gfxname(pc),a1		
	lob	OldOpenLibrary
	move.l	d0,_GFXBase(a5)

*** Try to find HippoPlayer's port. If succesfull, add 1 to hip_opencount
*** indicating we are using the information in the port.
*** Protect this phase with Forbid()-Permit()!

	lob	Forbid
	lea	portname(pc),a1
	lob	FindPort
	move.l	d0,port(a5)
	beq.w	exit
	move.l	d0,a0
	addq.b	#1,hip_opencount(a0)	* We are using the port now!
	lob	Permit

*** Get some info about the screen we're running on

	bsr.w	getscreendata

*** Open our window

	lea	winstruc,a0
	lore	Intui,OpenWindow
	move.l	d0,windowbase(a5)
	beq.w	exit
	move.l	d0,a0
	move.l	wd_RPort(a0),rastport(a5)	* Store rastport and userport
	move.l	wd_UserPort(a0),userport(a5)

*** Draw some gfx

plx1	equr	d4
plx2	equr	d5
ply1	equr	d6
ply2	equr	d7
 
	moveq   #7,plx1
	move    #332,plx2
	moveq   #13,ply1
	move   #80+128-86,ply2
	add	windowleft(a5),plx1
	add	windowleft(a5),plx2
	add	windowtop(a5),ply1
	add	windowtop(a5),ply2
	move.l	rastport(a5),a1
	bsr.w	piirra_loota2a

*** Initialize the bitmap structure

	lea	omabitmap(a5),a0
	moveq	#2,d0			* depth
	move	#WIDTH,d1		* width
	move	#HEIGHT,d2		* height 
	lore	GFX,InitBitMap
	move.l	#buffer1,omabitmap+bm_Planes(a5) * Plane pointer
	move.l	#buffer1+PLANE,omabitmap+bm_Planes(a5) * Plane pointer

	move.l	#buffer1+2*WIDTH/8,draw1(a5)	* Buffer pointers for drawing
	move.l	#buffer2+2*WIDTH/8,draw2(a5)



***** Ripple alustus

	bsr	srand
***** perspektiivitaulukko

	lea	divtab(a5),a0
	move.l	#100,d1
.dlop	
;	move.l	#$80000,d0
	move.l	#$100000,d0
	divu.l	d1,d0
	move	d0,(a0)+
	addq	#1,d1
	cmp	#16384,d1
	blo.b	.dlop


	lea	pisteet1,a0
	bsr	setamp
	lea	pisteet2,a0
	bsr	setamp
	lea	pisteet3,a0
	bsr	setamp
	lea	pisteet4,a0
	bsr	setamp

	bsr	reset
	bsr	korjaus

	move	#PIST^2-1,d7
	lea	yhteispisteet,a3
	lea	divtab(a5),a2
	lea	xtaulu,a1
.d
	movem	(a3),d0/d1/d2	* x,y,z
	lsl	#4,d0
	add	#900,d2

	move	(a2,d2*2),d2
	muls	d2,d0
	swap	d0
	move	d0,(a1)+

	lea	SIZ(a3),a3
	dbf	d7,.d


******** et�isyys keskipisteeseen

	lea	keskipisteet(pc),a4

	lea	yhteispisteet1,a1
	movem	(a4)+,d3/d4
	bsr	etaisyys

	lea	yhteispisteet2,a1
	movem	(a4)+,d3/d4
	bsr	etaisyys

	lea	yhteispisteet3,a1
	movem	(a4)+,d3/d4
	bsr	etaisyys

	lea	yhteispisteet4,a1
	movem	(a4)+,d3/d4
	bsr	etaisyys


*******************************	



*** Set task priority to -30 to prevent messing up with other programs

	move.l	owntask(a5),a1		
	moveq	#-30,d0
	lore	Exec,SetTaskPri
	move.l	d0,oldpri(a5)		* Store the old priority

*** Main loop begins here

loop	move.l	_GFXBase(a5),a6		* Wait a while..
	lob	WaitTOF

	move.l	port(a5),a0		* Check if HiP is playing
	tst.b	hip_quit(a0)
	bne.b	exi
	tst.b	hip_play(a0)
	beq.b	.oh

*** See if we should actually update the window.
	move.l	_IntuiBase(a5),a1
	move.l	ib_FirstScreen(a1),a1
	move.l	windowbase(a5),a0	
	cmp.l	wd_WScreen(a0),a1	* Is our screen on top?
	beq.b	.yes
	tst	sc_TopEdge(a1)	 	* Some other screen is partially on top 
	beq.b	.oh		 	* of our screen?
.yes

	bsr.w	dung			* Do the scope
.oh
	move.l	userport(a5),a0		* Get messages from IDCMP
	lore	Exec,GetMsg
	tst.l	d0
	beq.b	loop
	move.l	d0,a1

	move.l	im_Class(a1),d2		
	move	im_Code(a1),d3
	lob	ReplyMsg
	cmp.l	#IDCMP_MOUSEBUTTONS,d2	* Right mousebutton pressed?
	bne.b	.xy
	cmp	#MENUDOWN,d3
	beq.b	.x
.xy	cmp.l	#IDCMP_CLOSEWINDOW,d2	* Should we exit?
	bne.b	loop			* No. Keep loopin'
.x
	
exi	move.l	owntask(a5),a1		* Restore the old priority
	move.l	oldpri(a5),d0
	lore	Exec,SetTaskPri

exit

*** Exit program
	
	move.l	port(a5),d0		* IMPORTANT! Subtract 1 from
	beq.b	.uh0			* hip_opencount when the port is not
	move.l	d0,a0			* needed anymore
	subq.b	#1,hip_opencount(a0)
.uh0
	move.l	windowbase(a5),d0	* Close the window
	beq.b	.uh1
	move.l	d0,a0
	lore	Intui,CloseWindow
.uh1
	move.l	_IntuiBase(a5),d0	* And the libs
	bsr.b	closel
	move.l	_GFXBase(a5),d0
	bsr.b	closel

	bsr.w	replywbmessage

	moveq	#0,d0			* No error
	rts
	
closel  beq.b   .huh
        move.l  d0,a1
        lore    Exec,CloseLibrary
.huh    rts


***** Get some info about screen we're running on

getscreendata
	move.l	(a5),a0			* Running kick2.0 or newer?
	cmp	#37,LIB_VERSION(a0)
	bhs.b	.new		
	rts				
.new					* Yes.
	
	sub.l	a0,a0			* Default public screen
	lore	Intui,LockPubScreen  	* The only kick2.0+ function
	move.l	d0,d7
	beq.b	exit

	move.l	d0,a0
	move.b	sc_BarHeight(a0),windowtop+1(a5) * Palkin korkeus
	move.b	sc_WBorBottom(a0),windowbottom+1(a5)
	move.b	sc_WBorTop(a0),windowtopb+1(a5)
	move.b	sc_WBorLeft(a0),windowleft+1(a5)
	move.b	sc_WBorRight(a0),windowright+1(a5)

	move	windowtopb(a5),d0
	add	d0,windowtop(a5)

	subq	#4,windowleft(a5)		* saattaa menn� negatiiviseksi
	subq	#4,windowright(a5)
	subq	#2,windowtop(a5)
	subq	#2,windowbottom(a5)

	sub	#10,windowtop(a5)
	bpl.b	.o
	clr	windowtop(a5)
.o

	move	windowtop(a5),d0	* Adjust the window size
	add	d0,winstruc+6		
	move	windowleft(a5),d1
	add	d1,winstruc+4		
	add	d1,winsiz
	move	windowbottom(a5),d3
	add	d3,winsiz+2

	move.l	d7,a1			* Unlock it. Let's hope it doesn't
	sub.l	a0,a0			* go anywhere before we open our
	lob	UnlockPubScreen		* window.
	rts


*** Draw a bevel box

piirra_loota2a

** bevelboksit, reunat kaks pixeli�

laatikko1
	moveq	#1,d3
	moveq	#2,d2

	move.l	a1,a3
	move	d2,a4
	move	d3,a2

** valkoset reunat

	move	a2,d0
	move.l	a3,a1
	lore	GFX,SetAPen

	move	plx2,d0		* x1
	subq	#1,d0		
	move	ply1,d1		* y1
	move	plx1,d2		* x2
	move	ply1,d3		* y2
	bsr.w	drawli

	move	plx1,d0		* x1
	move	ply1,d1		* y1
	move	plx1,d2
	addq	#1,d2
	move	ply2,d3
	bsr.w	drawli
	
** mustat reunat

	move	a4,d0
	move.l	a3,a1
	lob	SetAPen

	move	plx1,d0
	addq	#1,d0
	move	ply2,d1
	move	plx2,d2
	move	ply2,d3
	bsr.b	drawli

	move	plx2,d0
	move	ply2,d1
	move	plx2,d2
	move	ply1,d3
	bsr.b	drawli

	move	plx2,d0
	subq	#1,d0
	move	ply1,d1
	addq	#1,d1
	move	plx2,d2
	subq	#1,d2
	move	ply2,d3
	bsr.b	drawli

looex	moveq	#1,d0
	move.l	a3,a1
	jmp	_LVOSetAPen(a6)



drawli	cmp	d0,d2
	bhi.b	.e
	exg	d0,d2
.e	cmp	d1,d3
	bhi.b	.x
	exg	d1,d3
.x	move.l	a3,a1
	move.l	_GFXBase(a5),a6
	jmp	_LVORectFill(a6)





*** Draw the scope

dung
	move.l	_GFXBase(a5),a6		* Grab the blitter
	lob	OwnBlitter
	lob	WaitBlit

	move.l	draw2(a5),$dff054	* Clear the drawing area
	move	#0,$dff066
	move.l	#$01000000,$dff040
	move	#2*(RHEIGHT-2)*64+WIDTH/16,$dff058

	lob	DisownBlitter		* Free the blitter

	pushm	all
	bsr.b	scope
	popm	all


*** Doublebuffering. 
* Bad: needs mem for two buffers (not that much though)
* Good: fast (blitter and cpu working simultaneously)

	move.l	draw1(a5),a0
;	move.l	#-1,255*40(a0)


	movem.l	draw1(a5),d0/d1		* Switch the buffers
	exg	d0,d1
	movem.l	d0/d1,draw1(a5)

	lea	omabitmap(a5),a0	* Set the bitplane pointer
	move.l	d1,bm_Planes(a0)
	add.l	#PLANE,d1
	move.l	d1,bm_Planes+4(a0)

;	lea	omabitmap(a5),a0	* Copy from bitmap to rastport
	move.l	rastport(a5),a1
	moveq	#0,d0		* source x,y
	move	#150,d1
	moveq	#10,d2		* dest x,y
	moveq	#15,d3
	add	windowleft(a5),d2
	add	windowtop(a5),d3
	move	#$c0,d6		* minterm a->d
	move	#WIDTH,d4	* x-size
	moveq	#HEIGHT-150,d5	* y-size

	lore	GFX,BltBitMapRastPort
	rts

*** The scope routine

scope

	move.l	port(a5),a2
	move.b	hip_PTtrigger1(a2),d0
	move.b	hip_PTtrigger2(a2),d1
	move.b	hip_PTtrigger3(a2),d2
	move.b	hip_PTtrigger4(a2),d3

	cmp.b	tr1(a5),d0
	beq.b	.q1
	move.l	hip_PTch1(a2),a0
	move	PTch_volume(a0),vol1(a5)
;	lsl	vol1(a5)
	lsl	vol1(a5)
	move	vol1(a5),pisteet1+AMP
	clr	pisteet1+SINPOS
.q1	cmp.b	tr2(a5),d1
	beq.b	.q2
	move.l	hip_PTch2(a2),a0
	move	PTch_volume(a0),vol2(a5)
;	lsl	vol2(a5)
	lsl	vol2(a5)
	move	vol2(a5),pisteet2+AMP
	clr	pisteet2+SINPOS
.q2	cmp.b	tr3(a5),d2
	beq.b	.q3
	move.l	hip_PTch3(a2),a0
	move	PTch_volume(a0),vol3(a5)
;	lsl	vol3(a5)
	lsl	vol3(a5)
	move	vol3(a5),pisteet3+AMP
	clr	pisteet3+SINPOS
.q3	cmp.b	tr4(a5),d3
	beq.b	.q4
	move.l	hip_PTch4(a2),a0
	move	PTch_volume(a0),vol4(a5)
;	lsl	vol4(a5)
	lsl	vol4(a5)
	move	vol4(a5),pisteet4+AMP
	clr	pisteet4+SINPOS
.q4

	move.b	d0,tr1(a5)
	move.b	d1,tr2(a5)
	move.b	d2,tr3(a5)
	move.b	d3,tr4(a5)


	pushm	all

	bsr	reset
	bsr	pallo
	bsr	korjaus


	popm	all

	push	a6
	lea	xtaulu,a6



	move	#PIST^2-1,d7
;	move	#500-1,d7
	lea	multab(pc),a4
	lea	yhteispisteet,a3
	lea	divtab(a5),a2
	lea	900*2(a2),a2
	move.l	draw1(a5),a0

	moveq	#0,d6

	move	#160,d3
	move	#128,d4
	move	#320,d5
	move	#256,d6
	move	#300,a1

	bra	.d
	cnop	0,4
.d
	move	(a3)+,d0	* x 
	move	(a3)+,d1	* y
	move	(a3)+,d2	* z
	addq.l	#2,a3

	move.l	draw1(a5),a0
	cmp	#201,d1
	blo.b	.da
	lea	PLANE(a0),a0
.da


;	add	#300,d1
	add	a1,d1
	lsl	#4,d0
	lsl	#4,d1
;	add	#900,d2

 ifne MC68000
	add	d2,d2
	move	(a2,d2),d2
 else
 	move	(a2,d2*2),d2
 endc

;	muls	d2,d0
;	swap	d0

	move	(a6)+,d0

	add	d3,d0
	cmp	d5,d0
	bhs.b	.o

	muls	d2,d1
	swap	d1
	add	d4,d1
	cmp	d6,d1
	bhs.b	.o

 ifne MC68000
	add	d1,d1
	move	(a4,d1),d1
 else
	move	(a4,d1*2),d1
 endc
	move	d0,d2
	lsr	#3,d0
	sub	d0,d1
	bset	d2,39(a0,d1)

.o
;	lea	SIZ(a3),a3
;	addq.l	#SIZ,a3
	dbf	d7,.d


	pop	a6




	lea	vol1(a5),a0
	bsr.b	.orl
	lea	vol2(a5),a0
	bsr.b	.orl
	lea	vol3(a5),a0
	bsr.b	.orl
	lea	vol4(a5),a0
	bsr.b	.orl
	rts



.orl	tst	(a0)
	beq.b	.urh
	subq	#1,(a0)
.urh	rts


root
	push	d1
        subq.l  #1,d0
        moveq   #-2,d1
.loop   addq.l  #2,d1
        sub.l   d1,d0
        bhi.s   .loop
        lsr.l   #1,d1
	move.l	d1,d0
	pop	d1
	rts


srand:  move.l  $dff004,d0      ; Initialize random generator.. Call once
        add.l   $dff002,d0
        add.l   $dc0000,d0
        add.l   $dc0004,d0
        add.l   $dc0008,d0
        add.l   $dc000c,d0
        move.l  d0,seed
        rts

rand:   move.l  seed(pc),d0     ; Returns random number (result: d0 = 0-32767)
        mulu.l	#$41c64e6d,d0
        add.l   #$3039,d0
        move.l  d0,seed
        moveq   #$10,d1
        lsr.l   d1,d0
        and.l   #$7fff,d0
        rts


seed:   dc.l    0       ; random seed storage (long)



reset
	lea	yhteispisteet,a0
	bsr	.re
	lea	yhteispisteet1,a0
	bsr	.re
	lea	yhteispisteet2,a0
	bsr	.re
	rts
.re	

	moveq	#40,d2 		* x step
	moveq	#40,d3		* y step
	moveq	#SIZ,d4

	moveq	#PIST-1,d0
;	move	#(-PIST/2)*(40),d6
	move	#(PIST/16)*40,d6	* start y
.y
	moveq	#PIST-1,d1
	move.l	#(-PIST/2)*40-30,d7	* start x


	bra.w	.x
	cnop	0,4
.x
	add	d2,d7		* X step
;	move	d7,X(a0)	* x
	move	d7,(a0)		* x
	clr	Y(a0)		* y
	move	d6,Z(a0)	* z
	add.l	d4,a0
	dbf	d1,.x
	add	d3,d6		* Y step
	dbf	d0,.y

	rts



korjaus
;	addq	#2,sinpo
;	and	#511,sinpo
;	move	sinpo(pc),d6
;	lea	sin(pc),a0
;	move	(a0,d6*2),d1
;	sub	#300,d1
;	asl	#1,d1

	lea	yhteispisteet+Y,a0
	move	#PIST*PIST/10-1,d0

	move	#200,d1
;	move	#-600,d1
	moveq	#SIZ,d7
	bra	.x
	cnop	0,4
.x
 rept 10
	add	d1,(a0)
	add.l	d7,a0
 endr
	dbf	d0,.x
 
	rts


sinpo	dc	0



etaisyys
	move.l	a1,a2	

	move	#PIST^2-1,d5

.dojh
	move.l	a1,d7
	sub.l	a2,d7
	divu	#SIZ,d7
	ext.l	d7
	divu	#PIST,d7
	move.l	d7,d6
	swap	d6

	sub	d3,d6		* X
	sub	d4,d7		* Z
	muls	d6,d6
	muls	d7,d7
	add.l	d7,d6
	move.l	d6,d0
	bsr	root
	move	d0,DIST(a1)
	addq.l	#SIZ,a1
	dbf	d5,.dojh
	rts
	
pallo
	lea	keskipisteet(pc),a4

	lea	yhteispisteet1,a0
	lea	pisteet1,a6
	lea	taulu1,a3
	movem	(a4)+,d0/a1	* keskipiste x,z
	bsr	rip

	lea	yhteispisteet2,a0
	lea	pisteet2,a6
	lea	taulu2,a3
	movem	(a4)+,d0/a1	* keskipiste x,z
	bsr	rip

	lea	yhteispisteet3,a0
	lea	pisteet3,a6
	lea	taulu3,a3
	movem	(a4)+,d0/a1	* keskipiste x,z
	bsr	rip

	lea	yhteispisteet4,a0
	lea	pisteet4,a6
	lea	taulu4,a3
	movem	(a4)+,d0/a1	* keskipiste x,z
	bsr	rip

	rts


rip
	pushm	all
	move.l	a3,a2
	move.l	a6,a3
	bsr	ripple
	popm	all

* a3 = s�detaulu
* a0 = pisteet

	move	#PIST^2/10-1,d0

	addq	#DIST,a0
	lea	yhteispisteet+Y,a1
	moveq	#0,d7

	bra	.lw
	cnop	0,4
.lw
 rept 10
	move	(a0),d7
 ifne MC68000
	add	d7,d7
	move	(a3,d7),d7
 else
	move	(a3,d7*2),d7
 endc
	add	d7,(a1)
	addq.l	#SIZ,a0
	addq.l	#SIZ,a1
 endr
	dbf	d0,.lw

	rts


*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************



MAXRAD	=	100

ripple
	move.l	a3,a6

	lea	sin(pc),a4
	move	#MAXRAD-1,d7
	move	#256,d6		* vaimennuskerroin, pienenee
	move	#256,d2
	bra	.l

	cnop	0,4

.l
	move	SINPOS(a3),d1	* sinpos
 ifne MC68000
	add	d1,d1
	move	(a4,d1),d1	* amplitude, 0 - 512
 else
	move	(a4,d1*2),d1	* amplitude, 0 - 512
 endc
;	sub	#256,d1
	sub	d2,d1		* -256 - +256

	moveq	#0,d5
	move	AMP(a3),d5
	mulu	d6,d5		* skaalataan amplitudi vaimennuskertoimella
	lsr.l	#8,d5	

	muls	d5,d1		* skaalataan siniarvo amplitudilla
	asr.l	#8,d1
	neg.l	d1
	move	d1,(a2)+	* z-arvo taulukkoon

** kaikkien vaimennus
 ifne MC68000
	sub	#15,d6
 else
 	sub	#10,d6
 endc
	bpl.b	.rr
	clr	d6
.rr
	addq.l	#SIZ2,a3
	dbf	d7,.l

	add	#32,SINPOS(a6)		* sinin nopeus
	and	#511,SINPOS(a6)

	lea	SIZ2*MAXRAD(a6),a0
	lea	-SIZ2(a0),a1
	move	#MAXRAD-1-1,d0
	bra.w	.lc
	cnop	0,4

.lc	subq.l	#SIZ2,a1
	subq.l	#SIZ2,a0
;	move	SINPOS(a1),SINPOS(a0)
	move	(a1),(a0)
	move	AMP(a1),AMP(a0)
	dbf	d0,.lc

** keskiaallon vaimennus


	lea	(a6),a0
	tst	AMP(a0)
	beq.b	.d
	sub	#4,AMP(a0)
;	cmp	#8,AMP(a0)
;	bgt.b	.d
;	move	#16,AMP(a0)
	bpl.b	.d
	clr	AMP(a0)
.d	rts



setamp	
	move	#200,AMP(a0)
	rts


*
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************
*************************************************************


**** aaltojen keskipisteet

keskipisteet
 ifne MC68000
	dc	15,25
	dc	5,15
	dc	25,15
	dc	15,5
 else
	dc	25,40
	dc	10,25
	dc	40,25
 	dc	25,10
 endc

;	dc	12,12
;	dc	37,12
;	dc	12,37
;	dc	37,37

sin
	DC.W	$0100,$0103,$0106,$0109,$010C,$010F,$0112,$0115
	DC.W	$0119,$011C,$011F,$0122,$0125,$0128,$012B,$012E
	DC.W	$0131,$0135,$0138,$013B,$013E,$0141,$0144,$0147
	DC.W	$014A,$014D,$0150,$0153,$0156,$0159,$015C,$015F
	DC.W	$0161,$0164,$0167,$016A,$016D,$0170,$0173,$0175
	DC.W	$0178,$017B,$017E,$0180,$0183,$0186,$0188,$018B
	DC.W	$018E,$0190,$0193,$0195,$0198,$019B,$019D,$019F
	DC.W	$01A2,$01A4,$01A7,$01A9,$01AB,$01AE,$01B0,$01B2
	DC.W	$01B5,$01B7,$01B9,$01BB,$01BD,$01BF,$01C1,$01C3
	DC.W	$01C5,$01C7,$01C9,$01CB,$01CD,$01CF,$01D1,$01D3
	DC.W	$01D4,$01D6,$01D8,$01D9,$01DB,$01DD,$01DE,$01E0
	DC.W	$01E1,$01E3,$01E4,$01E6,$01E7,$01E8,$01EA,$01EB
	DC.W	$01EC,$01ED,$01EE,$01EF,$01F1,$01F2,$01F3,$01F4
	DC.W	$01F4,$01F5,$01F6,$01F7,$01F8,$01F9,$01F9,$01FA
	DC.W	$01FB,$01FB,$01FC,$01FC,$01FD,$01FD,$01FE,$01FE
	DC.W	$01FE,$01FF,$01FF,$01FF,$01FF,$01FF,$01FF,$01FF
	DC.W	$0200,$01FF,$01FF,$01FF,$01FF,$01FF,$01FF,$01FF
	DC.W	$01FE,$01FE,$01FE,$01FD,$01FD,$01FC,$01FC,$01FB
	DC.W	$01FB,$01FA,$01F9,$01F9,$01F8,$01F7,$01F6,$01F5
	DC.W	$01F4,$01F4,$01F3,$01F2,$01F1,$01EF,$01EE,$01ED
	DC.W	$01EC,$01EB,$01EA,$01E8,$01E7,$01E6,$01E4,$01E3
	DC.W	$01E1,$01E0,$01DE,$01DD,$01DB,$01D9,$01D8,$01D6
	DC.W	$01D4,$01D3,$01D1,$01CF,$01CD,$01CB,$01C9,$01C7
	DC.W	$01C5,$01C3,$01C1,$01BF,$01BD,$01BB,$01B9,$01B7
	DC.W	$01B5,$01B2,$01B0,$01AE,$01AB,$01A9,$01A7,$01A4
	DC.W	$01A2,$019F,$019D,$019B,$0198,$0195,$0193,$0190
	DC.W	$018E,$018B,$0188,$0186,$0183,$0180,$017E,$017B
	DC.W	$0178,$0175,$0173,$0170,$016D,$016A,$0167,$0164
	DC.W	$0161,$015F,$015C,$0159,$0156,$0153,$0150,$014D
	DC.W	$014A,$0147,$0144,$0141,$013E,$013B,$0138,$0135
	DC.W	$0131,$012E,$012B,$0128,$0125,$0122,$011F,$011C
	DC.W	$0119,$0115,$0112,$010F,$010C,$0109,$0106,$0103
	DC.W	$0100,$00FC,$00F9,$00F6,$00F3,$00F0,$00ED,$00EA
	DC.W	$00E6,$00E3,$00E0,$00DD,$00DA,$00D7,$00D4,$00D1
	DC.W	$00CE,$00CA,$00C7,$00C4,$00C1,$00BE,$00BB,$00B8
	DC.W	$00B5,$00B2,$00AF,$00AC,$00A9,$00A6,$00A3,$00A0
	DC.W	$009E,$009B,$0098,$0095,$0092,$008F,$008C,$008A
	DC.W	$0087,$0084,$0081,$007F,$007C,$0079,$0077,$0074
	DC.W	$0071,$006F,$006C,$006A,$0067,$0064,$0062,$0060
	DC.W	$005D,$005B,$0058,$0056,$0054,$0051,$004F,$004D
	DC.W	$004A,$0048,$0046,$0044,$0042,$0040,$003E,$003C
	DC.W	$003A,$0038,$0036,$0034,$0032,$0030,$002E,$002C
	DC.W	$002B,$0029,$0027,$0026,$0024,$0022,$0021,$001F
	DC.W	$001E,$001C,$001B,$0019,$0018,$0017,$0015,$0014
	DC.W	$0013,$0012,$0011,$0010,$000E,$000D,$000C,$000B
	DC.W	$000B,$000A,$0009,$0008,$0007,$0006,$0006,$0005
	DC.W	$0004,$0004,$0003,$0003,$0002,$0002,$0001,$0001
	DC.W	$0001,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	DC.W	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	DC.W	$0001,$0001,$0001,$0002,$0002,$0003,$0003,$0004
	DC.W	$0004,$0005,$0006,$0006,$0007,$0008,$0009,$000A
	DC.W	$000B,$000B,$000C,$000D,$000E,$0010,$0011,$0012
	DC.W	$0013,$0014,$0015,$0017,$0018,$0019,$001B,$001C
	DC.W	$001E,$001F,$0021,$0022,$0024,$0026,$0027,$0029
	DC.W	$002B,$002C,$002E,$0030,$0032,$0034,$0036,$0038
	DC.W	$003A,$003C,$003E,$0040,$0042,$0044,$0046,$0048
	DC.W	$004A,$004D,$004F,$0051,$0054,$0056,$0058,$005B
	DC.W	$005D,$0060,$0062,$0064,$0067,$006A,$006C,$006F
	DC.W	$0071,$0074,$0077,$0079,$007C,$007F,$0081,$0084
	DC.W	$0087,$008A,$008C,$008F,$0092,$0095,$0098,$009B
	DC.W	$009E,$00A0,$00A3,$00A6,$00A9,$00AC,$00AF,$00B2
	DC.W	$00B5,$00B8,$00BB,$00BE,$00C1,$00C4,$00C7,$00CA
	DC.W	$00CE,$00D1,$00D4,$00D7,$00DA,$00DD,$00E0,$00E3
	DC.W	$00E6,$00EA,$00ED,$00F0,$00F3,$00F6,$00F9,$00FC





*** Multiplication table for Y

multab
aa set 0
	rept	HEIGHT
	dc	aa
aa set aa+WIDTH/8
	endr





**
* Workbench viestit
**
getwbmessage
	sub.l	a1,a1
	lore	Exec,FindTask
	move.l	d0,owntask(a5)

	move.l	d0,a4			* Vastataan WB:n viestiin, jos on.
	tst.l	pr_CLI(a4)
	bne.b	.nowb
	lea	pr_MsgPort(a4),a0
	lob	WaitPort
	lea	pr_MsgPort(a4),a0
	lob	GetMsg
	move.l	d0,wbmessage(a5)	
.nowb	rts

replywbmessage
	move.l	wbmessage(a5),d3
	beq.b	.nomsg
	lore	Exec,Forbid
	move.l	d3,a1
	lob	ReplyMsg
.nomsg	rts


*******************************************************************************
* Window

wflags set WFLG_SMART_REFRESH!WFLG_DRAGBAR!WFLG_CLOSEGADGET!WFLG_DEPTHGADGET
wflags set wflags!WFLG_RMBTRAP
idcmpflags = IDCMP_CLOSEWINDOW!IDCMP_MOUSEBUTTONS


winstruc
	dc	110,85	* x,y position
winsiz	dc	340,85+128-86	* x,y size
	dc.b	2,1	
	dc.l	idcmpflags
	dc.l	wflags
	dc.l	0
	dc.l	0	
	dc.l	.t	* title
	dc.l	0
	dc.l	0	
	dc	0,640	* min/max x
	dc	0,256	* min/max y
	dc	WBENCHSCREEN
	dc.l	0

.t	dc.b	"WaterScope",0

intuiname	dc.b	"intuition.library",0
gfxname		dc.b	"graphics.library",0
dosname		dc.b	"dos.library",0
portname	dc.b	"HiP-Port",0
 even


 	section	udnm,bss_p

var_b		ds.b	size_var


taulu1		ds	MAXRAD		* s�teit� vastaavat z-arvot
taulu2		ds	MAXRAD
taulu3		ds	MAXRAD
taulu4		ds	MAXRAD
pisteet1	ds.l	SIZ2*MAXRAD+SIZ2 * .w = sinpos, .w = amplitude
pisteet2	ds.l	SIZ2*MAXRAD+SIZ2 * 
pisteet3	ds.l	SIZ2*MAXRAD+SIZ2 * 
pisteet4	ds.l	SIZ2*MAXRAD+SIZ2 * 
yhteispisteet1	ds.b	SIZ*(PIST^2)	* x,y,z
yhteispisteet2	ds.b	SIZ*(PIST^2)	* x,y,z
yhteispisteet3	ds.b	SIZ*(PIST^2)	* x,y,z
yhteispisteet4	ds.b	SIZ*(PIST^2)	* x,y,z

yhteispisteet	ds.b	SIZ*(PIST^2)	* x,y,z

xtaulu		ds	PIST^2

	section	hihi,bss_c

buffer1	ds.b	WIDTH/8*RHEIGHT*2
buffer2	ds.b	WIDTH/8*RHEIGHT*2

 end
