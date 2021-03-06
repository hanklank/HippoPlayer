����  ?/                                     	incdir	include:
	include	"exec/exec_lib.i"
	include	"intuition/intuition.i"
	include	"graphics/graphics_lib.i"
	include	"intuition/intuition_lib.i"
	include	graphics/displayinfo.i
	include	libraries/reqtools_lib.i
	include	libraries/reqtools.i
	include	libraries/dos_lib.i
	include	mucro.i
	include	asm:pt/kpl_offsets.s
	incdir

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

	APTR		hip_listheader	* pointer to the listheader of modules
	LONG		hip_playtime	* time played in secs

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


	


	rsreset
_ExecBase	rs.l	1
_GFXBase	rs.l	1
_IntuiBase	rs.l	1
_DosBase	rs.l	1
owntask		rs.l	1
wbmessage	rs.l	1
screenbase	rs.l	1
windowbase	rs.l	1
fontbase	rs.l	1
userport	rs.l	1
windowtop	rs	1
mousex		rs	1
mousey		rs	1
port		rs.l	1

screenbuffer1	rs.l	1
screenbuffer2	rs.l	1
screenbuffer3	rs.l	1
draw		rs.l	1

icounter	rs	1
icounter2	rs	1

tr1		rs.b	1
tr2		rs.b	1
tr3		rs.b	1
tr4		rs.b	1

vol1		rs	1
vol2		rs	1
vol3		rs	1
vol4		rs	1

size_var	rs.b	0


wflags set WFLG_NOCAREREFRESH!WFLG_CLOSEGADGET!WFLG_SIMPLE_REFRESH!WFLG_RMBTRAP
idcmpflags set IDCMP_CLOSEWINDOW


	section	refridgerator,code

	lea	var_b,a5
	move.l	4.w,a6
	move.l	a6,(a5)

	cmp	#39,LIB_VERSION(a6)
	blo.w	exit

	bsr.w	getwbmessage

	lea	intuiname(pc),a1	* Open libs
	lore	Exec,OldOpenLibrary
	move.l	d0,_IntuiBase(a5)
	lea 	gfxname(pc),a1		
	lob	OldOpenLibrary
	move.l	d0,_GFXBase(a5)
	lea 	dosname(pc),a1		
	lob	OldOpenLibrary
	move.l	d0,_DosBase(a5)


*** Try to find HippoPlayer's port, add 1 to hip_opencount
*** Protect this phase with Forbid()-Permit()!

	lob	Forbid
	lea	portname(pc),a1
	lob	FindPort
	move.l	d0,port(a5)
	beq.w	exit
	move.l	d0,a0
	addq.b	#1,hip_opencount(a0)	* We are using the port now!
	lob	Permit

	lea	text_attr,a0
	lore	GFX,OpenFont
	move.l	d0,fontbase(a5)
	beq.w	exit

	lea	winstruc_t,a0
	lore	Intui,OpenWindow
	tst.l	d0
	beq.w	exit
	move.l	d0,a0
	move.b	wd_BorderTop(a0),windowtop+1(a5)
	lob	CloseWindow
	sub	#11,windowtop(a5)

	move	windowtop(a5),d0
	add	d0,winstruc+nw_Height

	bsr.w	avaa_naytto
	bne.w	exit

** 1. screenbufferi (alkup. n�ytt�)
	move.l	screenbase(a5),a0
	sub.l	a1,a1
	moveq	#SB_SCREEN_BITMAP!SB_COPY_BITMAP,d0
	lore	Intui,AllocScreenBuffer
	move.l	d0,screenbuffer1(a5)
	beq.w	exit

** 2. screenbufferi 
	move.l	screenbase(a5),a0
	sub.l	a1,a1
	moveq	#SB_COPY_BITMAP,d0
	lob	AllocScreenBuffer
	move.l	d0,screenbuffer2(a5)
	beq.w	exit

** 3. screenbufferi 
	move.l	screenbase(a5),a0
	sub.l	a1,a1
	moveq	#SB_COPY_BITMAP,d0
	lob	AllocScreenBuffer
	move.l	d0,screenbuffer3(a5)
	beq.w	exit

	bsr.w	voltab





************************ P��silmukka ******************************************
	

msgloop
	lore	GFX,WaitTOF

	move.l	port(a5),a0		* Check if HiP is playing
	tst.b	hip_quit(a0)
	bne.w	exit
	tst.b	hip_play(a0)
	beq.b	.oh
	cmp.b	#33,hip_playertype(a0)	* Playing a Protracker module?
	bne.b	.oh

	move.l	screenbuffer2(a5),a3
	move.l	sb_BitMap(a3),a3
	move.l	bm_Planes(a3),a3

	move.l	_GFXBase(a5),a6		* Grab the blitter
	lob	OwnBlitter
	lob	WaitBlit

	move.l	a3,$dff054		* Clear the drawing area
	move	#0,$dff066
	move.l	#$01000000,$dff040
	move	#256*64+320/16,$dff058

	lob	DisownBlitter		* Free the blitter


	move.l	screenbuffer3(a5),a0
	move.l	sb_BitMap(a0),a0
	move.l	bm_Planes(a0),draw(a5)

	bsr.w	notescroller
	bsr.w	quadrascope
	bsr.w	printinfo


* screenbuffer1 = n�ytt�
* screenbuffer2 = tyhjennys
* screenbuffer3 = piirto


* voidaanko vaihtaa n�ytt��? r�pelt��k� k�ytt�j� ikkunassa?

;	move.l	screenbuffer1(a5),a0
;	move.l	sb_DBufInfo(a0),a0
;	lea	dbi_SafeMessage(a0),a0
;	lore	Exec,GetMsg
;	tst.l	d0
;	bne.b	.oh


	movem.l	screenbuffer1(a5),a0/a1/a2
	move.l	a0,screenbuffer2(a5)
	move.l	a1,screenbuffer3(a5)
	move.l	a2,screenbuffer1(a5)

	move.l	a2,a1
	move.l	screenbase(a5),a0
	lore	Intui,ChangeScreenBuffer


.oh

** poistutaan escist�. tutkitaan vain jos oma ruutu ekana

	move.l	_IntuiBase(a5),a0
	move.l	ib_FirstScreen(a0),a0
	cmp.l	screenbase(a5),a0
	bne.w	msgloop

	move.b	$bfec01,d0
	moveq	#$45,d1
	rol.b	#1,d1
	not.b	d1
	cmp.b	d1,d0
	bne.w	msgloop


;	move.l	userport(a5),a0
;	lore	Exec,GetMsg
;	tst.l	d0
;	beq.w	msgloop
;	move.l	d0,a1
;	move.l	im_Class(a1),d2		* luokka	
;	move	im_Code(a1),d3		* koodi
;;;	move.l	im_IAddress(a1),a2 	* gadgetin tai olion osoite
;;	move	im_MouseX(a1),mousex(a5)
;;	move	im_MouseY(a1),mousey(a5)
;	lob	ReplyMsg
;	cmp.l	#IDCMP_CLOSEWINDOW,d2
;	bne.w	msgloop



exit
	lea	var_b,a5
	bsr.w	flush_messages


	move.l	port(a5),d0		* IMPORTANT! Subtract 1 from
	beq.b	.uh0			* hip_opencount when exiting
	move.l	d0,a0
	subq.b	#1,hip_opencount(a0)
.uh0

	tst.l	screenbase(a5)
	beq.b	.h3

	lore	GFX,WaitBlit

	move.l	screenbuffer1(a5),d0
	beq.b	.h1
	move.l	d0,a1
	move.l	screenbase(a5),a0
	lore	Intui,FreeScreenBuffer
.h1
	move.l	screenbuffer2(a5),d0
	beq.b	.h2
	move.l	d0,a1
	move.l	screenbase(a5),a0
	lore	Intui,FreeScreenBuffer
.h2
	move.l	screenbuffer3(a5),d0
	beq.b	.h3
	move.l	d0,a1
	move.l	screenbase(a5),a0
	lore	Intui,FreeScreenBuffer
.h3

	bsr.w	sulje_naytto

	move.l	fontbase(a5),d0
	beq.b	.xx
	move.l	d0,a1
	move.l	_GFXBase(a5),a6
	lob	CloseFont
.xx

	move.l	_IntuiBase(a5),d0
	bsr.b	closel
	move.l	_GFXBase(a5),d0
	bsr.b	closel
	move.l	_DosBase(a5),d0
	bsr.b	closel

	bsr.w	replywbmessage

	moveq	#0,d0
	rts


closel	beq.b	.huh
	move.l	(a5),a6
	move.l	d0,a1
	lob	CloseLibrary
.huh	rts


flush_messages
	tst.l	windowbase(a5)
	bne.b	.fmsgoop
	rts
.fmsgoop	
	move.l	(a5),a6
	move.l	userport(a5),a0	* flushataan pois kaikki messaget
	lob	GetMsg
	tst.l	d0
	beq.b	.ex
	move.l	d0,a1
	lob	ReplyMsg
	bra.b	.fmsgoop
.ex	rts



portname	dc.b	"HiP-Port",0
dosname		dc.b	"dos.library",0
gfxname		dc.b	"graphics.library",0
intuiname	dc.b	"intuition.library",0
fontname	dc.b	"topaz.font",0
screentitle	
windowname1	dc.b	"Bigscope v1.0 by K-P",0
 even


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
******************************************************** Avaa n�yt�n ja ikkunan
avaa_naytto
	push	a6

	move.l	_IntuiBase(a5),a6
	lea	screenstruc,a1
	sub.l	a0,a0
	lob	OpenScreenTagList
	move.l	d0,screenbase(a5)
	beq.b	.x
	move.l	d0,wscreen

	move.l	screenbase(a5),a0
	lea	sc_ViewPort(a0),a0
	lea	paletti,a1
	lore	GFX,LoadRGB32
	
;	lea	winstruc,a0
;	lore	Intui,OpenWindow
;	move.l	d0,windowbase(a5)
;	beq.b	.x
;	move.l	d0,a0
;	move.l	wd_UserPort(a0),userport(a5)

	pop	a6
	moveq	#0,d0
	rts
.x	pop	a6
	moveq	#1,d0
	rts

paletti
	dc	2	* number of colors
	dc	0	* first color to be loaded

tri	macro
	dc.l	\1<<24,\2<<24,\3<<24
	endm

	tri	0,0,0
	tri	255,255,255,255

	dc.l	0,0,0	* terminate


*******************************************************************************
***************************************************************** Sulkee n�yt�n
sulje_naytto
	push	a6
	bsr.w	flush_messages
	move.l	_IntuiBase(a5),a6		
	move.l	windowbase(a5),d3
	beq.b	.uh1
	move.l	d3,a0
	lob	CloseWindow
	clr.l	windowbase(a5)
.uh1
	move.l	screenbase(a5),d4
	beq.b	.uh2
	move.l	d4,a0
	lore	Intui,CloseScreen
	clr.l	screenbase(a5)
.uh2	pop	a6
	rts



 


*******************************
* NoteScroller (ProTracker)
*

notescroller
	
	bsr.w	.notescr

*** viiva
	move.l	draw(a5),a0
	lea	11*8*40-1*40(a0),a0
	moveq	#19-1,d0
.raita	or	#$aaaa,(a0)+
	or	#$aaaa,8*40-2(a0)
	dbf	d0,.raita



	move.l	port(a5),a2
	move.b	hip_PTtrigger1(a2),d0
	move.b	hip_PTtrigger2(a2),d1
	move.b	hip_PTtrigger3(a2),d2
	move.b	hip_PTtrigger4(a2),d3

	cmp.b	tr1(a5),d0
	beq.b	.q1
	move.l	hip_PTch1(a2),a0
	move	PTch_volume(a0),vol1(a5)
.q1	cmp.b	tr2(a5),d1
	beq.b	.q2
	move.l	hip_PTch2(a2),a0
	move	PTch_volume(a0),vol2(a5)
.q2	cmp.b	tr3(a5),d2
	beq.b	.q3
	move.l	hip_PTch3(a2),a0
	move	PTch_volume(a0),vol3(a5)
.q3	cmp.b	tr4(a5),d3
	beq.b	.q4
	move.l	hip_PTch4(a2),a0
	move	PTch_volume(a0),vol4(a5)
.q4

	move.b	d0,tr1(a5)
	move.b	d1,tr2(a5)
	move.b	d2,tr3(a5)
	move.b	d3,tr4(a5)


	move.l	port(a5),a0
	move.l	hip_PTch1(a0),a0
	move	vol1(a5),d0
	moveq	#2,d1
	bsr.w	.palkki

	move.l	port(a5),a0
	move.l	hip_PTch2(a0),a0
	move	vol2(a5),d0
	moveq	#11,d1
	bsr.b	.palkki

	move.l	port(a5),a0
	move.l	hip_PTch3(a0),a0
	move	vol3(a5),d0
	moveq	#20,d1
	bsr.b	.palkki

	move.l	port(a5),a0
	move.l	hip_PTch1(a0),a0
	move	vol4(a5),d0
	moveq	#29,d1
	bsr.b	.palkki

	move.l	port(a5),a0
	move.l	hip_PTch1(a0),a3
	move.b	#%11100000,d2
	moveq	#38,d1
	bsr.b	.palkki2

	move.l	port(a5),a0
	move.l	hip_PTch2(a0),a3
	moveq	#%1110,d2
	moveq	#38,d1
	bsr.b	.palkki2

	move.l	port(a5),a0
	move.l	hip_PTch3(a0),a3
	moveq	#39,d1
	move.b	#%11100000,d2
	bsr.b	.palkki2

	move.l	port(a5),a0
	move.l	hip_PTch4(a0),a3
	moveq	#%1110,d2
	moveq	#39,d1
	bsr.b	.palkki2

.ohi

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



***** Volumepalkgi

.palkki

	move.l	port(a5),a0
	moveq	#0,d2
	move.b	hip_mainvolume(a0),d2
	mulu	d2,d0
;	lsr	#6,d0

	ext.l	d0
	divu	#48,d0

	move.l	draw(a5),a0
	lea	86*40(a0),a0
	add	d1,a0
;	lea	.paldata(pC),a1

	subq	#1,d0
	bmi.b	.yg
	move.b	#%01111100,d1
.purl	or.b	d1,(a0)
	lea	-40(a0),a0
	dbf	d0,.purl	
.yg	rts



**** Periodpalkki
	
.palkki2
	cmp	#2,PTch_length(a3)
	bls.b	.h
	moveq	#0,d0
	move	PTch_period(a3),d0
	beq.b	.h
	sub	#108,d0
	mulu	#9,d0
	divu	#40,d0		* 0-179

* 108-905 -> 0-180

	move.l	draw(a5),a0
	lea	multab(pc),a1
	add	d0,d0
	move	(a1,d0),d0
	add	d0,a0
	add	d1,a0

	or.b	d2,(a0)
	or.b	d2,40(a0)
	or.b	d2,80(a0)
	or.b	d2,120(a0)

.h	rts



;* 8x58
;	DC.l	$FCFCDCFC,$FCFCDCFC,$74FCDCFC,$54FC5CFC,$54BC54FC,$54B854E8
;	DC.l	$54B854A8,$54B854A8,$548854A0,$54885420,$54885400,$54005000
;	DC.l	$54001000,$04001000
;	dc	$0000
;.paldata

* 8x64
	DC.B	$FC,$FC,$FC,$FC
	DC.B	$FC,$DC,$FC,$7C
	DC.B	$FC,$DC,$FC,$54
	DC.B	$FC,$5C,$FC,$54
	DC.B	$FC,$54,$FC,$54
	DC.B	$B8,$54,$FC,$54
	DC.B	$B8,$54,$AC,$54
	DC.B	$B8,$54,$A8,$54
	DC.B	$A8,$54,$A8,$54
	DC.B	$88,$54,$28,$54
	DC.B	$88,$54,$00,$54
	DC.B	$88,$54,$00,$54
	DC.B	$00,$54,$00,$54
	DC.B	$00,$10,$00,$54
	DC.B	$00,$10,$00,$00
	DC.B	$00,$10,$00,$00
.paldata



**************** Piirret��n patterndata

.notescr
	move.l	port(a5),a0
	move.l	hip_kplbase(a0),a0

	move.l	k_songdataptr(a0),a3
	moveq	#0,d0
	move	k_songpos(a0),d0
	move.b	(a3,d0),d0
	lsl	#6,d0
	add	k_patternpos(a0),d0
	lsl.l	#4,d0
	add.l	d0,a3
	lea	1084-952(a3),a3

	move.l	draw(a5),a4
	addq	#3,a4

	moveq	#23-1,d7
	move	k_patternpos(a0),d6	* eka rivi?

	move	d6,d0
	sub	#12,d0
	bpl.b	.ok
	neg	d0
	sub	d0,d7

	moveq	#12,d1
	sub	d0,d1
	sub	d1,d6
	lsl	#4,d1
	sub	d1,a3

	mulu	#8*40,d0
	add.l	d0,a4

	bra.b	.ok2
.ok
	lea	-12*16(a3),a3
	sub	#12,d6
.ok2



.plorl
	lea	.pos(pc),a0		* rivinumero
	move	d6,d0
	divu	#10,d0
	or.b	#'0',d0
	move.b	d0,(a0)
	swap	d0
	or.b	#'0',d0
	move.b	d0,1(a0)

	move.l	a4,a1
	subq	#3,a1
	moveq	#2-1,d1
	bsr.w	.print

	moveq	#4-1,d5
.plorl2

	lea	.note(pc),a2

	moveq	#0,d0
	move.b	2(a3),d0
	bne.b	.jee
	move.b	#' ',(a2)+
	move.b	#' ',(a2)+
	move.b	#' ',(a2)+
	bra.b	.nonote
.jee
	subq	#1,d0
	divu	#12*2,d0
	addq	#1,d0
	or.b	#'0',d0
	move.b	d0,2(a2)
	swap	d0
	lea	.notes(pc),a1
	lea	(a1,d0),a0
	move.b	(a0)+,(a2)+		* Nuotti
	move.b	(a0)+,(a2)+
	addq	#1,a2
.nonote

	moveq	#0,d0			* samplenumero
	move.b	3(a3),d0
	bne.b	.onh
	move.b	#' ',(a2)+
	move.b	#' ',(a2)+
	bra.b	.eihn
.onh

	lsr	#2,d0
	divu	#$10,d0
	bne.b	.onh2
	move.b	#' ',(a2)+
	bra.b	.eihn2
.onh2	or.b	#'0',d0
	move.b	d0,(a2)+
.eihn2	swap	d0
	bsr.b	.hegs
.eihn

	move.b	(a3),d0			* komento
	lsr.b	#2,d0
	bsr.b	.hegs
	moveq	#0,d0
	move.b	1(a3),d0
	divu	#$10,d0
	bsr.b	.hegs
	swap	d0
	bsr.b	.hegs


	move.l	a4,a1
	lea	.note(pc),a0
	moveq	#8-1,d1
	bsr.b	.print


	addq	#4,a3
	add	#9,a4
	dbf	d5,.plorl2

	add	#8*40-4*9,a4
	addq	#1,d6
	cmp	#64,d6
	beq.b	.lorl
	dbf	d7,.plorl
.lorl
	rts


.hegs	cmp.b	#9,d0
	bhi.b	.high1
	or.b	#'0',d0
	bra.b	.hge
.high1	sub.b	#10,d0
	add.b	#'A',d0
.hge	move.b	d0,(a2)+
	rts

.notes	dc.b	"C-"
	dc.b	"C#"
	dc.b	"D-"
	dc.b	"D#"
	dc.b	"E-"
	dc.b	"F-"
	dc.b	"F#"
	dc.b	"G-"
	dc.b	"G#"
	dc.b	"A-"
	dc.b	"A#"
	dc.b	"B-"

.note	dc.b	"00000000"
.pos	dc.b	"00"
 even

.print
	pushm	a3-a4
	lea	font(pc),a2
	move	#192,d2

	moveq	#40,d4
	
.ooe	moveq	#0,d0
	move.b	(a0)+,d0
	cmp.b	#$20,d0
	beq.b	.space
	lea	-$20(a2,d0),a3
	move.l	a1,a4

	moveq	#8-1,d3
.lin	move.b	(a3),(a4)	
	add	d2,a3
	add	d4,a4
	dbf	d3,.lin

.space	addq	#1,a1
	dbf	d1,.ooe
	popm	a3-a4
	rts




*** The scope routine

quadrascope
	move.l	port(a5),a3
	move.l	hip_PTch1(a3),a3	* Channel 1 data
	move.l	draw(a5),a0		
	lea	192*40-30(a0),a0		* Position to draw to
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch2(a3),a3
	move.l	draw(a5),a0
	lea	192*40-20(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch3(a3),a3
	move.l	draw(a5),a0
	lea	192*40-10(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch4(a3),a3
	move.l	draw(a5),a0
	lea	192*40(a0),a0

;	bsr.b	.scope
;	rts

.scope
	move.l	PTch_loopstart(a3),d0	* Always check these to avoid
	beq.b	.halt			* enforcer hits!
	move.l	PTch_start(a3),d1
	bne.b	.jolt
.halt	rts

.jolt	
	move.l	d0,a4				* Loop start
	move.l	d1,a1				* Sample start

	move	PTch_length(a3),d5		* Get sample length and 
	move	PTch_replen(a3),d4		* loop length

	move.l	port(a5),a2
	moveq	#0,d1
	move.b	hip_mainvolume(a2),d1	* (Main volume * sample volume)/64
	mulu	PTch_volume(a3),d1	
	lsr	#6,d1

	tst	d1			* Get the correct position in the
	bne.b	.heee			* table... 
	moveq	#1,d1
.heee	subq	#1,d1
	add	d1,d1
	lsl.l	#8,d1
	lea	mtab,a2
	add.l	d1,a2

	lea	-40(a0),a3		* Position 2 one pixel above position 1

	moveq	#80/8-1,d7		* Draw 80 pixels
	moveq	#1,d0			* Pixel register
	moveq	#0,d6

drlo	

*** Inner loop macro

sco	macro
	move	d6,d2		* Clear word
	move.b	(a1)+,d2	* Get one byte sample data
	add	d2,d2		* Multiply by two 
	move	(a2,d2),d3	* Get a scaled value from the volume table
	or.b	d0,(a3,d3)	* Plot pixel	
	or.b	d0,(a0,d3)	* Plot another pixel

	ifne	\2	
	add.b	d0,d0		* Roll left the pixel register
	endc
	
	ifne	\1
	subq	#2,d5		* End of the sample?
	bpl.b	hm\2
	move	d4,d5		* Then loop. 
	move.l	a4,a1
hm\2
	endc
	endm


	sco	0,1	* 0 = Don't check if the sample ended, 1 = temp label
	sco	1,2		
	sco	0,3
	sco	1,4
	sco	0,5
	sco	1,6
	sco	0,7
	sco	1,0	* 0 = ..., 0 = roll the pixel register

	moveq	#1,d0		* Reset the pixel register
	sub	d0,a0		* Move 8 pixels left in the bitplane
	sub	d0,a3		* ...
	dbf	d7,drlo		* Loop..
	rts



*** Calculate volumetable for quadrascope

voltab
	lea	mtab,a0
	moveq	#$40-1,d3
	moveq	#0,d2

.olp2	moveq	#0,d0
	move	#256-1,d4
.olp1	move	d0,d1
	ext	d1
	muls	d2,d1
	asr	#8,d1
	add	#32,d1
	mulu	#40,d1
	add	#39,d1
	move	d1,(a0)+
	addq	#1,d0
	dbf	d4,.olp1
	addq	#1,d2
	dbf	d3,.olp2
	rts
	

multab
aa set 0
	rept	256
	dc	aa
aa set aa+40
	endr



*************** infoa


printinfo

	move.l	port(a5),a4
	move.l	hip_kplbase(a4),a2

	move.l	k_songdataptr(a2),a3
	moveq	#0,d0
	move	k_songpos(a2),d0

	lea	.t(pc),a0

	bsr.w	putnumber

	move.b	#'/',(a0)+	

	moveq	#0,d0
	move.b	-2(a3),d0
	bsr.w	putnumber

	lea	.t2(pc),a0


	move.l	hip_playtime(a4),d0

	divu	#50,d0
	ext.l	d0
	divu	#60,d0
	swap	d0
	moveq	#0,d1
	move	d0,d1
	clr	d0
	swap	d0

	divu	#10,d0
	add.b	#'0',d0
	move.b	d0,(a0)+
	swap	d0
	add.b	#'0',d0
	move.b	d0,(a0)+
	move.b	#':',(a0)+

	divu	#10,d1
	add.b	#'0',d1
	move.b	d1,(a0)+
	swap	d1
	add.b	#'0',d1
	move.b	d1,(a0)+

	clr.b	(a0)

	lea	.tt(pc),a0
	move.l	draw(a5),a1
	lea	185*40(a1),a1
	bsr.b	print
	rts

.tt	dc.b	"Position/length: "
.t	dc.b	"000/000   Time: "
.t2	dc.b	"00:00",0,0,0
 even


* a0 = mihink� laitetaan
* d0 = luku joka k��nnet��n ASCIIksi
putnumber
	divu	#100,d0
	or.b	#'0',d0
	move.b	d0,(a0)+

	clr	d0
	swap	d0
	divu	#10,d0
	or.b	#'0',d0
	move.b	d0,(a0)+

	swap	d0
	or.b	#'0',d0
	move.b	d0,(a0)+
	rts




****************************************************************************** 
*                                Print (nopee)
****************************************************************************** 
* a1 = screen
* a0 = text


print

.plev	=	40		* kohderuudun leveys
.lines	=	8		* montako linjaa / rivi
.flev	=	192		* fontin modulo

	movem.l	d0-a6,-(sp)

	lea	topazfont(pc),a3

	move.l	#.flev,d3		
	move.l	#.lines*.plev,d5
	moveq	#.plev,d4

	move	#10,a5
	moveq	#$20,d6
	moveq	#127,d7

	move.l	a1,a2

.loop0
	moveq	#0,d0
	move.b	(a0)+,d0
	beq.b	.end

;	cmp.b	#10,d0			; a return char
	cmp	a5,d0
	bne.s	.cont
	move.l	d5,a2
	move.l	a2,a1
	bra.s	.loop0	
.cont	
	cmp.b	#1,d0			; space mark
	bne.b	.cont2
	move.b	(a0)+,d0		; get spaces
	add	d0,a1
	bra.s	.loop0
.cont2	
	cmp.b	#2,d0
	bne.b	.cont3

	move.l	d4,d2
	subq	#1,d2
	lea	1(a0),a6
.findend
	subq	#1,d2
	cmp.b	#10,(a6)+
	bne.b	.findend
	lsr	#1,d2
	add	d2,a1
	bra.b	.loop0

.cont3
	cmp	d7,d0
	blo.b	.loasc
	sub	d6,d0
.loasc	lea	-$20(a3,d0),a4

	move.b	(a4),(a1)	
	move.b	.flev(a4),.plev(a1)
	move.b	.flev*2(a4),.plev*2(a1)	
	move.b	.flev*3(a4),.plev*3(a1)	
	move.b	.flev*4(a4),.plev*4(a1)	
	move.b	.flev*5(a4),.plev*5(a1)	
	move.b	.flev*6(a4),.plev*6(a1)	
	move.b	.flev*7(a4),.plev*7(a1)	

	addq.l	#1,a1

	bra.b	.loop0
.end
	movem.l	(sp)+,d0-a6
	rts

topazfont

font
	DC.B	$00,$18,$6C,$6C,$18,$00,$38,$18
	DC.B	$0C,$30,$00,$00,$00,$00,$00,$03
	DC.B	$3C,$18,$3C,$3C,$1C,$7E,$1C,$7E
	DC.B	$3C,$3C,$00,$00,$0C,$00,$30,$3C
	DC.B	$7C,$18,$FC,$3C,$F8,$FE,$FE,$3C
	DC.B	$66,$7E,$0E,$E6,$F0,$82,$C6,$38
	DC.B	$FC,$38,$FC,$3C,$7E,$66,$C3,$C6
	DC.B	$C3,$C3,$FE,$3C,$C0,$3C,$10,$00
	DC.B	$18,$00,$E0,$00,$0E,$00,$1C,$00
	DC.B	$E0,$18,$06,$E0,$38,$00,$00,$00
	DC.B	$00,$00,$00,$00,$08,$00,$00,$00
	DC.B	$00,$00,$00,$0E,$18,$70,$72,$CC
	DC.B	$7E,$18,$0C,$1C,$42,$C3,$18,$3C
	DC.B	$66,$7E,$30,$00,$3E,$00,$7E,$7E
	DC.B	$3C,$18,$F0,$F0,$18,$00,$7E,$00
	DC.B	$00,$30,$70,$00,$20,$20,$C0,$18
	DC.B	$30,$0C,$18,$71,$C3,$3C,$1F,$3C
	DC.B	$60,$18,$30,$66,$30,$0C,$18,$66
	DC.B	$F8,$71,$30,$0C,$18,$71,$C3,$00
	DC.B	$3D,$30,$0C,$18,$66,$06,$F0,$7C
	DC.B	$30,$0C,$18,$71,$33,$3C,$00,$00
	DC.B	$30,$0C,$18,$66,$30,$0C,$18,$66
	DC.B	$60,$71,$30,$0C,$18,$71,$66,$00
	DC.B	$00,$30,$0C,$18,$66,$0C,$F0,$66
	DC.B	$00,$3C,$6C,$6C,$3E,$C6,$6C,$18
	DC.B	$18,$18,$66,$18,$00,$00,$00,$06
	DC.B	$66,$38,$66,$66,$3C,$60,$30,$66
	DC.B	$66,$66,$18,$18,$18,$00,$18,$66
	DC.B	$C6,$3C,$66,$66,$6C,$66,$66,$66
	DC.B	$66,$18,$06,$66,$60,$C6,$E6,$6C
	DC.B	$66,$6C,$66,$66,$5A,$66,$C3,$C6
	DC.B	$66,$C3,$C6,$30,$60,$0C,$38,$00
	DC.B	$18,$00,$60,$00,$06,$00,$36,$00
	DC.B	$60,$00,$00,$60,$18,$00,$00,$00
	DC.B	$00,$00,$00,$00,$18,$00,$00,$00
	DC.B	$00,$00,$00,$18,$18,$18,$9C,$33
	DC.B	$66,$00,$3E,$36,$3C,$66,$18,$40
	DC.B	$00,$81,$48,$33,$06,$00,$81,$00
	DC.B	$66,$18,$18,$18,$30,$00,$F4,$00
	DC.B	$00,$70,$88,$CC,$63,$63,$23,$00
	DC.B	$08,$10,$24,$8E,$18,$66,$3C,$66
	DC.B	$10,$20,$48,$00,$08,$10,$24,$00
	DC.B	$6C,$8E,$08,$10,$24,$8E,$3C,$63
	DC.B	$66,$08,$10,$24,$00,$08,$60,$66
	DC.B	$08,$10,$24,$8E,$00,$66,$00,$00
	DC.B	$08,$10,$24,$00,$08,$10,$24,$00
	DC.B	$FC,$8E,$08,$10,$24,$8E,$00,$18
	DC.B	$01,$08,$10,$24,$00,$10,$60,$00
	DC.B	$00,$3C,$00,$FE,$60,$CC,$68,$30
	DC.B	$30,$0C,$3C,$18,$00,$00,$00,$0C
	DC.B	$6E,$18,$06,$06,$6C,$7C,$60,$06
	DC.B	$66,$66,$18,$18,$30,$7E,$0C,$06
	DC.B	$DE,$3C,$66,$C0,$66,$60,$60,$C0
	DC.B	$66,$18,$06,$6C,$60,$EE,$F6,$C6
	DC.B	$66,$C6,$66,$70,$18,$66,$66,$C6
	DC.B	$3C,$66,$8C,$30,$30,$0C,$6C,$00
	DC.B	$0C,$3C,$6C,$3C,$36,$3C,$30,$3B
	DC.B	$6C,$38,$06,$66,$18,$66,$7C,$3C
	DC.B	$DC,$3D,$EC,$3E,$3E,$66,$66,$63
	DC.B	$63,$66,$7E,$18,$18,$18,$00,$CC
	DC.B	$66,$18,$6C,$30,$66,$3C,$18,$3C
	DC.B	$00,$9D,$88,$66,$00,$7E,$B9,$00
	DC.B	$3C,$7E,$30,$30,$00,$C6,$F4,$18
	DC.B	$00,$30,$88,$66,$26,$26,$66,$18
	DC.B	$3C,$3C,$3C,$3C,$3C,$3C,$3C,$C0
	DC.B	$FE,$FE,$FE,$FE,$7E,$7E,$7E,$7E
	DC.B	$66,$C6,$3C,$3C,$3C,$3C,$66,$36
	DC.B	$CF,$66,$66,$66,$66,$C3,$7E,$66
	DC.B	$3C,$3C,$3C,$3C,$3C,$3C,$7E,$3C
	DC.B	$3C,$3C,$3C,$3C,$38,$38,$38,$38
	DC.B	$18,$7C,$3C,$3C,$3C,$3C,$3C,$00
	DC.B	$3E,$66,$66,$66,$66,$66,$7C,$66
	DC.B	$00,$18,$00,$6C,$3C,$18,$76,$00
	DC.B	$30,$0C,$FF,$7E,$00,$7E,$00,$18
	DC.B	$7E,$18,$1C,$1C,$CC,$06,$7C,$0C
	DC.B	$3C,$3E,$00,$00,$60,$00,$06,$0C
	DC.B	$DE,$66,$7C,$C0,$66,$78,$78,$CE
	DC.B	$7E,$18,$06,$78,$60,$FE,$DE,$C6
	DC.B	$7C,$C6,$7C,$38,$18,$66,$66,$D6
	DC.B	$18,$3C,$18,$30,$18,$0C,$C6,$00
	DC.B	$00,$06,$76,$66,$6E,$66,$78,$66
	DC.B	$76,$18,$06,$6C,$18,$77,$66,$66
	DC.B	$66,$66,$76,$60,$18,$66,$66,$6B
	DC.B	$36,$66,$4C,$70,$18,$0E,$00,$33
	DC.B	$66,$18,$6C,$78,$3C,$18,$00,$66
	DC.B	$00,$B1,$F8,$CC,$00,$7E,$B9,$00
	DC.B	$00,$18,$60,$18,$00,$C6,$74,$18
	DC.B	$00,$30,$70,$33,$2C,$2C,$2C,$30
	DC.B	$66,$66,$66,$66,$66,$66,$6F,$C0
	DC.B	$60,$60,$60,$60,$18,$18,$18,$18
	DC.B	$F6,$E6,$66,$66,$66,$66,$C3,$1C
	DC.B	$DB,$66,$66,$66,$66,$66,$63,$6C
	DC.B	$06,$06,$06,$06,$06,$06,$1B,$66
	DC.B	$66,$66,$66,$66,$18,$18,$18,$18
	DC.B	$7C,$66,$66,$66,$66,$66,$66,$7E
	DC.B	$67,$66,$66,$66,$66,$66,$66,$66
	DC.B	$00,$18,$00,$FE,$06,$30,$DC,$00
	DC.B	$30,$0C,$3C,$18,$00,$00,$00,$30
	DC.B	$76,$18,$30,$06,$FE,$06,$66,$18
	DC.B	$66,$06,$00,$00,$30,$00,$0C,$18
	DC.B	$DE,$7E,$66,$C0,$66,$60,$60,$C6
	DC.B	$66,$18,$66,$6C,$62,$D6,$CE,$C6
	DC.B	$60,$C6,$6C,$0E,$18,$66,$3C,$FE
	DC.B	$3C,$18,$32,$30,$0C,$0C,$00,$00
	DC.B	$00,$1E,$66,$60,$66,$7E,$30,$66
	DC.B	$66,$18,$06,$78,$18,$6B,$66,$66
	DC.B	$66,$66,$66,$3C,$18,$66,$66,$6B
	DC.B	$1C,$66,$18,$18,$18,$18,$00,$CC
	DC.B	$66,$3C,$3E,$30,$42,$3C,$18,$3C
	DC.B	$00,$B1,$00,$66,$00,$00,$B1,$00
	DC.B	$00,$18,$F8,$F0,$00,$C6,$14,$00
	DC.B	$00,$30,$00,$66,$19,$1B,$D9,$60
	DC.B	$7E,$7E,$7E,$7E,$7E,$7E,$7C,$66
	DC.B	$78,$78,$78,$78,$18,$18,$18,$18
	DC.B	$66,$D6,$C3,$C3,$C3,$C3,$C3,$36
	DC.B	$F3,$66,$66,$66,$66,$3C,$63,$66
	DC.B	$1E,$1E,$1E,$1E,$1E,$1E,$7F,$60
	DC.B	$7E,$7E,$7E,$7E,$18,$18,$18,$18
	DC.B	$C6,$66,$66,$66,$66,$66,$66,$00
	DC.B	$6B,$66,$66,$66,$66,$66,$66,$66
	DC.B	$00,$00,$00,$6C,$7C,$66,$CC,$00
	DC.B	$18,$18,$66,$18,$18,$00,$18,$60
	DC.B	$66,$18,$66,$66,$0C,$66,$66,$18
	DC.B	$66,$0C,$18,$18,$18,$7E,$18,$00
	DC.B	$C0,$C3,$66,$66,$6C,$66,$60,$66
	DC.B	$66,$18,$66,$66,$66,$C6,$C6,$6C
	DC.B	$60,$6C,$66,$66,$18,$66,$3C,$EE
	DC.B	$66,$18,$66,$30,$06,$0C,$00,$00
	DC.B	$00,$66,$66,$66,$66,$60,$30,$3C
	DC.B	$66,$18,$06,$6C,$18,$63,$66,$66
	DC.B	$7C,$3E,$60,$06,$1A,$66,$3C,$36
	DC.B	$36,$3C,$32,$18,$18,$18,$00,$33
	DC.B	$66,$3C,$0C,$30,$00,$18,$18,$02
	DC.B	$00,$9D,$FC,$33,$00,$00,$A9,$00
	DC.B	$00,$00,$00,$00,$00,$EE,$14,$00
	DC.B	$00,$00,$F8,$CC,$33,$31,$33,$66
	DC.B	$C3,$C3,$C3,$C3,$C3,$C3,$CC,$3C
	DC.B	$60,$60,$60,$60,$18,$18,$18,$18
	DC.B	$6C,$CE,$66,$66,$66,$66,$66,$63
	DC.B	$66,$66,$66,$66,$66,$18,$7E,$66
	DC.B	$66,$66,$66,$66,$66,$66,$D8,$66
	DC.B	$60,$60,$60,$60,$18,$18,$18,$18
	DC.B	$C6,$66,$66,$66,$66,$66,$66,$18
	DC.B	$73,$66,$66,$66,$66,$3C,$7C,$3C
	DC.B	$00,$18,$00,$6C,$18,$C6,$76,$00
	DC.B	$0C,$30,$00,$00,$18,$00,$18,$C0
	DC.B	$3C,$7E,$7E,$3C,$1E,$3C,$3C,$18
	DC.B	$3C,$38,$18,$18,$0C,$00,$30,$18
	DC.B	$78,$C3,$FC,$3C,$F8,$FE,$F0,$3E
	DC.B	$66,$7E,$3C,$E6,$FE,$C6,$C6,$38
	DC.B	$F0,$3C,$E3,$3C,$3C,$3E,$18,$C6
	DC.B	$C3,$3C,$FE,$3C,$03,$3C,$00,$00
	DC.B	$00,$3B,$3C,$3C,$3B,$3C,$78,$C6
	DC.B	$E6,$3C,$66,$E6,$3C,$63,$66,$3C
	DC.B	$60,$06,$F0,$7C,$0C,$3B,$18,$36
	DC.B	$63,$18,$7E,$0E,$18,$70,$00,$CC
	DC.B	$7E,$18,$00,$7E,$00,$3C,$18,$3C
	DC.B	$00,$81,$00,$00,$00,$00,$81,$00
	DC.B	$00,$7E,$00,$00,$00,$FA,$14,$00
	DC.B	$18,$00,$00,$00,$67,$62,$67,$3C
	DC.B	$C3,$C3,$C3,$C3,$C3,$C3,$CF,$08
	DC.B	$FE,$FE,$FE,$FE,$7E,$7E,$7E,$7E
	DC.B	$F8,$C6,$3C,$3C,$3C,$3C,$3C,$00
	DC.B	$BC,$3E,$3E,$3E,$3E,$3C,$60,$6C
	DC.B	$3B,$3B,$3B,$3B,$3B,$3B,$77,$3C
	DC.B	$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C
	DC.B	$7C,$66,$3C,$3C,$3C,$3C,$3C,$00
	DC.B	$3E,$3B,$3B,$3B,$3B,$18,$60,$18
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$30,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$30,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$06,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$FE
	DC.B	$00,$00,$00,$00,$00,$00,$00,$7C
	DC.B	$00,$00,$3C,$00,$00,$00,$00,$00
	DC.B	$F0,$07,$00,$00,$00,$00,$00,$00
	DC.B	$00,$70,$00,$00,$00,$00,$00,$33
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$7E,$00,$00,$00,$00,$7E,$00
	DC.B	$00,$00,$00,$00,$00,$C0,$00,$00
	DC.B	$30,$00,$00,$00,$01,$07,$01,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$30
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$F0,$60
	DC.B	$00,$00,$00,$00,$00,$00,$00,$10
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$00,$00,$00,$00,$00,$00,$00,$00
	DC.B	$40,$00,$00,$00,$00,$70,$F0,$70
	DC.B	$00,$00,$00,$08,$00,$08,$00,$08
	DC.B	$00,$10,$00,$08,$00,$18,$00,$08
	DC.B	$00,$20,$00,$08,$00,$28,$00,$08
	DC.B	$00,$30,$00,$08,$00,$38,$00,$08
	DC.B	$00,$40,$00,$08,$00,$48,$00,$08
	DC.B	$00,$50,$00,$08,$00,$58,$00,$08
	DC.B	$00,$60,$00,$08,$00,$68,$00,$08
	DC.B	$00,$70,$00,$08,$00,$78,$00,$08
	DC.B	$00,$80,$00,$08,$00,$88,$00,$08
	DC.B	$00,$90,$00,$08,$00,$98,$00,$08
	DC.B	$00,$A0,$00,$08,$00,$A8,$00,$08
	DC.B	$00,$B0,$00,$08,$00,$B8,$00,$08
	DC.B	$00,$C0,$00,$08,$00,$C8,$00,$08
	DC.B	$00,$D0,$00,$08,$00,$D8,$00,$08
	DC.B	$00,$E0,$00,$08,$00,$E8,$00,$08
	DC.B	$00,$F0,$00,$08,$00,$F8,$00,$08
	DC.B	$01,$00,$00,$08,$01,$08,$00,$08
	DC.B	$01,$10,$00,$08,$01,$18,$00,$08
	DC.B	$01,$20,$00,$08,$01,$28,$00,$08
	DC.B	$01,$30,$00,$08,$01,$38,$00,$08
	DC.B	$01,$40,$00,$08,$01,$48,$00,$08
	DC.B	$01,$50,$00,$08,$01,$58,$00,$08
	DC.B	$01,$60,$00,$08,$01,$68,$00,$08
	DC.B	$01,$70,$00,$08,$01,$78,$00,$08
	DC.B	$01,$80,$00,$08,$01,$88,$00,$08
	DC.B	$01,$90,$00,$08,$01,$98,$00,$08
	DC.B	$01,$A0,$00,$08,$01,$A8,$00,$08
	DC.B	$01,$B0,$00,$08,$01,$B8,$00,$08
	DC.B	$01,$C0,$00,$08,$01,$C8,$00,$08
	DC.B	$01,$D0,$00,$08,$01,$D8,$00,$08
	DC.B	$01,$E0,$00,$08,$01,$E8,$00,$08
	DC.B	$01,$F0,$00,$08,$01,$F8,$00,$08
	DC.B	$02,$00,$00,$08,$02,$08,$00,$08
	DC.B	$02,$10,$00,$08,$02,$18,$00,$08
	DC.B	$02,$20,$00,$08,$02,$28,$00,$08
	DC.B	$02,$30,$00,$08,$02,$38,$00,$08
	DC.B	$02,$40,$00,$08,$02,$48,$00,$08
	DC.B	$02,$50,$00,$08,$02,$58,$00,$08
	DC.B	$02,$60,$00,$08,$02,$68,$00,$08
	DC.B	$02,$70,$00,$08,$02,$78,$00,$08
	DC.B	$02,$80,$00,$08,$02,$88,$00,$08
	DC.B	$02,$90,$00,$08,$02,$98,$00,$08
	DC.B	$02,$A0,$00,$08,$02,$A8,$00,$08
	DC.B	$02,$B0,$00,$08,$02,$B8,$00,$08
	DC.B	$02,$C0,$00,$08,$02,$C8,$00,$08
	DC.B	$02,$D0,$00,$08,$02,$D8,$00,$08
	DC.B	$02,$E0,$00,$08,$02,$E8,$00,$08
	DC.B	$02,$F0,$00,$08,$02,$F8,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08
	DC.B	$03,$00,$00,$08,$03,$00,$00,$08






*************************** Windows * text_attr *******************************
	section	dada,data
text_attr
	dc.l	fontname
	dc	8
	dc.b	0,0

screenstruc
	dc.l	SA_Left,0
	dc.l	SA_Top,0
	dc.l	SA_Width,320
	dc.l	SA_Height,256
	dc.l	SA_Depth,1
	dc.l	SA_DetailPen,1
	dc.l	SA_BlockPen,2
	dc.l	SA_Title,screentitle
	dc.l	SA_Font,text_attr
	dc.l	SA_ShowTitle,TRUE
	dc.l	SA_Type,CUSTOMSCREEN
	dc.l	SA_DisplayID,LORES_KEY
	dc.l	SA_Overscan,OSCAN_STANDARD
	dc.l	SA_AutoScroll,FALSE
	dc.l	TAG_END



winstruc 
	dc	0,0		* x,y
	dc	20,12		* koko

	dc.b	1,2
	dc.l	idcmpflags
	dc.l	wflags
	dc.l	0	;1. gadgetti
	dc.l	0	
	dc.l	windowname1
wscreen	dc.l	0	* screen struc
	dc.l	0	* bitmap
	dc	0,0,-1,-1,CUSTOMSCREEN


* testi-ikkuna otsikkopalkin koon selvitt�miseksi
winstruc_t
	dc	1,1,1,1
	dc.b	1,1
	dc.l	0,WINDOWDEPTH
	dc.l	0,0,0,0,0
	dc	0,0,0,0,WBENCHSCREEN


	section	udnm,bss

mtab		ds.b	64*256*2
var_b		ds.b	size_var

  

