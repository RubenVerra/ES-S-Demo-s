; Made by Claude
; ============================================================================
;  MENU + SNAKE + TETRIS voor de Flex6502
;
;  Bij het opstarten verschijnt een keuzescherm. Met W en S kies je een spel,
;  met D start je het. Reset (knop CPU_RESET of de toets 'r') brengt je altijd
;  terug naar het menu.
;
;  BEELD
;    Het scherm is 32 bij 32 tegels op $0200..$05FF, een byte per tegel.
;    De FPGA maakt daar blokken van 20 bij 15 pixels van.
;
;      $00        leeg / zwart
;      $01        muur of speelveldrand
;      $02..$08   tetrisblokken, zeven kleuren
;      $11        slang (wit)
;      $EE        appel (rood)
;      $40..$49   cijfer 0 t/m 9
;      $4A..$63   letter A t/m Z
;
;  GEHEUGEN
;    $00,$01   appelpositie (snake)
;    $02       richting (snake)      $03  slanglengte in bytes
;    $10...    slanglichaam (snake, groeit omhoog)
;    $40       spel gekozen (0 = nog in het menu)
;    $41       cursorstand in het menu: 0 = snake, 1 = tetris
;    $50..$5F  tetris-toestand, zie daar
;    $60..$65  zes scorecijfers
;    $04..$0B  algemene hulpbytes
;    $00FD/$FE random, door de FPGA geschreven
;    $00FF     laatste toets, door de FPGA geschreven
;
;  Toetsen worden door de 6502 zelf op nul gezet zodra ze verwerkt zijn.
;  Zonder dat zou een druk meerdere keren tellen, want de spellus draait
;  sneller dan de FPGA een nieuw frame verstuurt.
; ============================================================================

; ---------------------------------------------------------------- opstarten
; Het menu wordt EEN KEER getekend. Daarna verandert alleen de marker.
; Zou je hier elke ronde het scherm wissen en opnieuw opbouwen, dan vangt de
; zender geregeld een half leeg scherm en zie je het beeld knipperen. Precies
; daarom loopt Snake wel vloeiend: die tekent ook maar een paar vakjes per keer.
boot:
        JSR clrscreen
        LDA #$00
        STA $40           ; nog niets gekozen
        STA $41           ; cursor op snake
        STA $42           ; vorige cursorstand
        JSR menutext
        JSR menumark
menuloop:
        JSR menukeys
        LDA $41
        CMP $42
        BEQ mlsame
        JSR menuunmark    ; oude marker weg
        LDA $41
        STA $42
        JSR menumark      ; nieuwe marker erbij
mlsame:
        LDA #$08
        JSR delay
        LDA $40
        BEQ menuloop
        LDA $41
        BEQ startsnake
        CMP #$01
        BEQ startetris
        CMP #$02
        BEQ startinv
        JMP brkstart
startsnake:
        JMP snakestart
startetris:
        JMP tetstart
startinv:
        JMP invstart

; ============================================================================
;  GEDEELDE HULPROUTINES
; ============================================================================

; het hele scherm ($0200..$05FF) leegmaken
clrscreen:
        LDA #$00
        LDX #$00
cls1:
        STA $0200,X
        STA $0300,X
        STA $0400,X
        STA $0500,X
        INX
        BNE cls1
        RTS

; wachten; A = aantal ronden van 256 stappen
delay:
        STA $0B
dly1:
        LDX #$00
dly2:
        DEX
        BNE dly2
        DEC $0B
        BNE dly1
        RTS

; toets ophalen en meteen wissen, zodat een druk maar een keer telt
getkey:
        LDA $FF
        LDX #$00
        STX $FF
        RTS

; tekst neerzetten
;   $04/$05 = wijzer naar de tekst, afgesloten met $FF
;   $06     = beeldrij, $07 = beginkolom
puttext:
        LDY $06
        LDA SCRLO,Y
        STA $08
        LDA SCRHI,Y
        STA $09
        LDX #$00
pt1:
        TXA
        TAY
        LDA ($04),Y
        CMP #$FF
        BEQ ptend
        STA $0A
        TXA
        CLC
        ADC $07
        TAY
        LDA $0A
        STA ($08),Y
        INX
        JMP pt1
ptend:  RTS

; zes scorecijfers op rij $06 vanaf kolom $07 zetten
putscore:
        LDY $06
        LDA SCRLO,Y
        STA $08
        LDA SCRHI,Y
        STA $09
        LDX #$00
ps1:
        LDA $60,X
        CLC
        ADC #$40          ; cijfer -> tegelcode
        STA $0A
        TXA
        CLC
        ADC $07
        TAY
        LDA $0A
        STA ($08),Y
        INX
        CPX #$06
        BNE ps1
        RTS

; score op nul
clrscore:
        LDA #$00
        LDX #$05
csc1:
        STA $60,X
        DEX
        BPL csc1
        RTS

; A honderdtallen bij de score optellen
addscore:
        CLC
        ADC $63
        STA $63
asc1:
        LDA $63
        CMP #$0A
        BCC ascdone
        SEC
        SBC #$0A
        STA $63
        INC $62
        LDA $62
        CMP #$0A
        BCC asc1
        LDA #$00
        STA $62
        INC $61
        LDA $61
        CMP #$0A
        BCC asc1
        LDA #$00
        STA $61
        INC $60
        JMP asc1
ascdone:
        RTS

; ============================================================================
;  MENU
; ============================================================================
menukeys:
        JSR getkey
        CMP #$77          ; W omhoog
        BEQ mkup
        CMP #$73          ; S omlaag
        BEQ mkdown
        CMP #$64          ; D starten
        BEQ mkgo
        RTS
mkup:
        LDA $41
        BEQ mkend
        DEC $41
mkend:  RTS
mkdown:
        LDA $41
        CMP #$03
        BEQ mkend
        INC $41
        RTS
mkgo:
        LDA #$01
        STA $40
        RTS

menutext:
        LDA #<TXKIES
        STA $04
        LDA #>TXKIES
        STA $05
        LDA #$04
        STA $06
        LDA #$0B
        STA $07
        JSR puttext
        LDA #<TXSNAKE
        STA $04
        LDA #>TXSNAKE
        STA $05
        LDA #$0A
        STA $06
        LDA #$0D
        STA $07
        JSR puttext
        LDA #<TXTETRIS
        STA $04
        LDA #>TXTETRIS
        STA $05
        LDA #$0E
        STA $06
        LDA #$0D
        STA $07
        JSR puttext
        LDA #<TXINV
        STA $04
        LDA #>TXINV
        STA $05
        LDA #$12
        STA $06
        LDA #$0D
        STA $07
        JSR puttext
        LDA #<TXBRK
        STA $04
        LDA #>TXBRK
        STA $05
        LDA #$16
        STA $06
        LDA #$0D
        STA $07
        JSR puttext
        LDA #<TXHELP
        STA $04
        LDA #>TXHELP
        STA $05
        LDA #$18
        STA $06
        LDA #$0A
        STA $07
        JSR puttext
        RTS

; tegel in A op de markerplek van regel $0C zetten (0 = snake, 1 = tetris)
; De vier regels staan op rij 10, 14, 18 en 22, dus rij = 10 + keuze * 4.
; Dat scheelt een rijtje vergelijkingen.
menuput:
        STA $0D
        LDA $0C
        ASL A
        ASL A
        CLC
        ADC #$0A
        TAY
        LDA SCRLO,Y
        STA $08
        LDA SCRHI,Y
        STA $09
        LDA $0D
        LDY #$0B
        STA ($08),Y
        RTS

menumark:
        LDA $41
        STA $0C
        LDA #$EE
        JMP menuput

menuunmark:
        LDA $42
        STA $0C
        LDA #$00
        JMP menuput

; ============================================================================
;  SNAKE
;  Dit is de gerepareerde versie: de muurcontrole rechts gebruikt $1F (was $07,
;  waardoor de slang na acht stappen doodging) en onder $06 (was $03, waardoor
;  het speelveld maar acht rijen hoog was).
;
;  $00/$01 appel, $02 richting (1 op, 2 rechts, 4 neer, 8 links),
;  $03 lengte in bytes, $10.. het lichaam
; ============================================================================
snakestart:
        JSR clrscreen
        JSR snakeinit
        JSR snakeapple
snakeloop:
        JSR snakekeys
        JSR snakehitapple
        JSR snakehitself
        JSR snakemove
        JSR snakedrawapple
        JSR snakedraw
        JSR snakewait
        JMP snakeloop

snakeinit:
        LDA #$02          ; richting = rechts
        STA $02
        LDA #$04          ; lengte = 4 bytes = 2 segmenten
        STA $03
        LDA #$11          ; kop midden op het scherm ($0411)
        STA $10
        LDA #$10
        STA $12
        LDA #$0F
        STA $14
        LDA #$04
        STA $11
        STA $13
        STA $15
        RTS

snakeapple:
        LDA $FE           ; lage byte: willekeurig 0..255
        STA $00
        LDA $FD           ; hoge byte: 2..5, dus binnen $0200..$05FF
        LSR A
        LSR A
        LSR A
        AND #$03
        CLC
        ADC #$02
        STA $01
        RTS

snakekeys:
        JSR getkey
        CMP #$77
        BEQ snup
        CMP #$64
        BEQ snright
        CMP #$73
        BEQ sndown
        CMP #$61
        BEQ snleft
        RTS
snup:
        LDA #$04          ; niet omkeren
        BIT $02
        BNE snkend
        LDA #$01
        STA $02
snkend: RTS
snright:
        LDA #$08
        BIT $02
        BNE snkend
        LDA #$02
        STA $02
        RTS
sndown:
        LDA #$01
        BIT $02
        BNE snkend
        LDA #$04
        STA $02
        RTS
snleft:
        LDA #$02
        BIT $02
        BNE snkend
        LDA #$08
        STA $02
        RTS

snakehitapple:
        LDA $00
        CMP $10
        BNE snhaend
        LDA $01
        CMP $11
        BNE snhaend
        INC $03           ; een segment langer
        INC $03
        LDA #$01
        JSR addscore
        JSR snakeapple
snhaend:
        RTS

snakehitself:
        LDX #$02
snhs1:
        LDA $10,X
        CMP $10
        BNE snhs2
        LDA $11,X
        CMP $11
        BEQ snakedead
snhs2:
        INX
        INX
        CPX $03
        BEQ snhs3
        JMP snhs1
snhs3:  RTS

snakemove:
        LDX $03
        DEX
        TXA
snmv1:
        LDA $10,X
        STA $12,X
        DEX
        BPL snmv1
        LDA $02
        LSR A
        BCS snmvup
        LSR A
        BCS snmvright
        LSR A
        BCS snmvdown
        LSR A
        BCS snmvleft
snmvup:
        LDA $10
        SEC
        SBC #$20
        STA $10
        BCC snmvup2
        RTS
snmvup2:
        DEC $11
        LDA #$01          ; boven $0200 = muur
        CMP $11
        BEQ snakedead
        RTS
snmvright:
        INC $10
        LDA #$1F          ; einde van de rij = muur
        BIT $10
        BEQ snakedead
        RTS
snmvdown:
        LDA $10
        CLC
        ADC #$20
        STA $10
        BCS snmvdn2
        RTS
snmvdn2:
        INC $11
        LDA #$06          ; onder $05FF = muur
        CMP $11
        BEQ snakedead
        RTS
snmvleft:
        DEC $10
        LDA $10
        AND #$1F
        CMP #$1F
        BEQ snakedead
        RTS

snakedrawapple:
        LDY #$00
        LDA #$EE
        STA ($00),Y
        RTS

snakedraw:
        LDX $03
        LDA #$00
        STA ($10,X)       ; staart wissen
        LDX #$00
        LDA #$11
        STA ($10,X)       ; kop tekenen
        RTS

snakewait:
        LDA #$14          ; de CPU loopt nu op 100 kHz in plaats van 10 kHz,
        JSR delay         ; dus de wachtlus moet tien keer langer
        RTS

; dood: scherm even rood kleuren en terug naar het menu
snakedead:
        LDA #$EE
        JSR snakefill
        LDA #$08
        JSR delay
        JMP boot

snakefill:
        STA $0A
        LDX #$00
snf1:
        LDA $0A
        STA $0200,X
        STA $0300,X
        STA $0400,X
        STA $0500,X
        INX
        BNE snf1
        RTS

; ============================================================================
;  TETRIS
;  Speelveld 10 breed en 20 hoog op PF. Op het scherm staat dat in de kolommen
;  11 t/m 20 en de rijen 5 t/m 24, met een rand eromheen.
;
;  Elk stuk is een masker van 16 bits over een vakje van 4 bij 4. Zeven stukken
;  maal vier draaiingen is 56 bytes, veel compacter dan een tabel met
;  coordinaten. Botsing testen is dat masker bit voor bit langslopen.
;
;  $50 soort   $51 draaiing   $52 x (met 2 opgeteld)   $53 y
;  $54 valteller   $55 valsnelheid   $56/$57 masker   $58 bitnummer
;  $59 kolom in het veld   $5A rij   $5B hulp   $5C vastgezet   $5D regels
; ============================================================================
tetstart:
        JSR clrscreen
        JSR clrscore
        LDA #$00
        LDX #$00          ; speelveld leegmaken: 200 bytes, dus met CPX tellen
tst1:                     ; en niet met BPL, want 199 is negatief voor de 6502
        STA PF,X
        INX
        CPX #$C8
        BNE tst1
        LDA #$1A
        STA $55           ; valsnelheid: een rij per 26 ronden
        LDA #$00
        STA $54
        JSR tetborder     ; rand en score staan vast, dus eenmalig
        JSR tetscore
        JSR tetnew
        JSR tetshow
tetloop:
        LDA #$00
        STA $5C           ; 'stuk is vastgezet' vlag wissen
        JSR tethide       ; het stuk weghalen waar het nu staat
        JSR tetkeys
        JSR tetgravity
        LDA $5C
        BEQ tlfree
        JSR tetfield      ; alleen na vastzetten het veld opnieuw tekenen
        JSR tetscore
tlfree:
        JSR tetshow       ; stuk op zijn nieuwe plek zetten
        LDA #$01
        JSR delay
        JMP tetloop

tetkeys:
        JSR getkey
        CMP #$61
        BEQ tkleft
        CMP #$64
        BEQ tkright
        CMP #$77
        BEQ tkrot
        CMP #$73
        BEQ tkdown
        RTS
tkleft:
        DEC $52
        JSR tetfits
        BEQ tkok
        INC $52
tkok:   RTS
tkright:
        INC $52
        JSR tetfits
        BEQ tkok
        DEC $52
        RTS
tkrot:
        INC $51
        LDA $51
        AND #$03
        STA $51
        JSR tetfits
        BEQ tkok
        DEC $51
        LDA $51
        AND #$03
        STA $51
        RTS
tkdown:
        JSR tetdrop
        RTS

; masker van het huidige stuk in $56/$57
tetmask:
        LDA $50
        ASL A
        ASL A
        CLC
        ADC $51
        ASL A
        TAY
        LDA PIECES,Y
        STA $56
        LDA PIECES+1,Y
        STA $57
        RTS

; past het stuk op zijn huidige plek? A=0 en Z=1 als het past
tetfits:
        JSR tetmask
        LDA #$00
        STA $58
tf1:
        ASL $57
        ROL $56           ; hoogste bit van het masker in de carry
        BCC tfnext
        LDA $58
        AND #$03
        CLC
        ADC $52
        SEC
        SBC #$02
        STA $59
        CMP #$0A          ; links eruit loopt om naar een groot getal
        BCS tfbad
        LDA $58
        LSR A
        LSR A
        CLC
        ADC $53
        STA $5A
        CMP #$14
        BCS tfbad
        ASL A
        ASL A
        ASL A
        STA $5B           ; 8 * rij
        LDA $5A
        ASL A             ; 2 * rij
        CLC
        ADC $5B           ; 10 * rij
        CLC
        ADC $59
        TAY
        LDA PF,Y
        BNE tfbad
tfnext:
        INC $58
        LDA $58
        CMP #$10
        BNE tf1
        LDA #$00
        RTS
tfbad:
        LDA #$01
        RTS

; stuk in het speelveld vastzetten
tetlock:
        JSR tetmask
        LDA #$00
        STA $58
tl1:
        ASL $57
        ROL $56
        BCC tlnext
        LDA $58
        AND #$03
        CLC
        ADC $52
        SEC
        SBC #$02
        STA $59
        LDA $58
        LSR A
        LSR A
        CLC
        ADC $53
        STA $5A
        ASL A
        ASL A
        ASL A
        STA $5B
        LDA $5A
        ASL A
        CLC
        ADC $5B
        CLC
        ADC $59
        TAY
        LDA $50
        CLC
        ADC #$02          ; soort 0..6 -> tegelcode $02..$08
        STA PF,Y
tlnext:
        INC $58
        LDA $58
        CMP #$10
        BNE tl1
        RTS

; een rij zakken; kan niet meer? dan vastzetten en een nieuw stuk
tetdrop:
        INC $53
        JSR tetfits
        BEQ tdfree
        DEC $53
        JSR tetlock
        JSR tetlines
        JSR tetnew
        LDA #$01
        STA $5C
tdfree:
        RTS

tetgravity:
        INC $54
        LDA $54
        CMP $55
        BCC tgend
        LDA #$00
        STA $54
        JSR tetdrop
tgend:  RTS

tetnew:
        LDA $FE
        AND #$07
        CMP #$07
        BCC tnok
        LDA #$00
tnok:
        STA $50
        LDA #$00
        STA $51
        LDA #$05
        STA $52
        LDA #$00
        STA $53
        JSR tetfits
        BEQ tnend
        JMP tetover       ; nieuw stuk past niet meer: einde
tnend:  RTS

; volle rijen wissen
tetlines:
        LDA #$00
        STA $5D
        LDA #$13          ; onderste rij eerst
        STA $5A
tln1:
        LDA $5A
        ASL A
        ASL A
        ASL A
        STA $5B
        LDA $5A
        ASL A
        CLC
        ADC $5B
        CLC
        ADC #<PF
        STA $04
        LDA #>PF
        STA $05
        LDY #$00
tln2:
        LDA ($04),Y
        BEQ tlnnot
        INY
        CPY #$0A
        BNE tln2
        JSR tetshift
        INC $5D
        JMP tln1          ; zelfde rij nog eens bekijken
tlnnot:
        DEC $5A
        BPL tln1
        LDA $5D
        BEQ tlnend
        ASL A             ; 200 punten per gewiste regel
        JSR addscore
tlnend: RTS

; alles boven rij $5A een rij omlaag schuiven
tetshift:
        LDA $5A
        ASL A
        ASL A
        ASL A
        STA $0A
        LDA $5A
        ASL A
        CLC
        ADC $0A
        CLC
        ADC #$09
        TAX
tsh1:
        CPX #$0A
        BCC tshtop
        LDA PF-10,X
        STA PF,X
        DEX
        JMP tsh1
tshtop:
        LDX #$09
        LDA #$00
tsh2:
        STA PF,X
        DEX
        BPL tsh2
        RTS

; Het stuk tekenen of wissen. $0E is de tegel die geschreven wordt: de kleur
; van het stuk om te tekenen, of $00 om het weg te halen.
tetput:
        JSR tetmask
        LDA #$00
        STA $58
tp1:
        ASL $57
        ROL $56
        BCC tp2
        LDA $58
        AND #$03
        CLC
        ADC $52
        SEC
        SBC #$02
        STA $59
        CMP #$0A
        BCS tp2
        LDA $58
        LSR A
        LSR A
        CLC
        ADC $53
        STA $5A
        CMP #$14
        BCS tp2
        LDA $5A
        CLC
        ADC #$05          ; speelveldrij 0 staat op beeldrij 5
        TAY
        LDA SCRLO,Y
        STA $08
        LDA SCRHI,Y
        STA $09
        LDA $59
        CLC
        ADC #$0B          ; speelveldkolom 0 staat op beeldkolom 11
        TAY
        LDA $0E
        STA ($08),Y
tp2:
        INC $58
        LDA $58
        CMP #$10
        BNE tp1
        RTS

tethide:
        LDA #$00
        STA $0E
        JMP tetput

tetshow:
        LDA $50
        CLC
        ADC #$02          ; soort 0..6 -> tegelcode $02..$08
        STA $0E
        JMP tetput

; het hele speelveld overtekenen; alleen nodig als er iets is vastgezet of
; als er regels gewist zijn
tetfield:
        LDA #$AB          ; $0200 + rij 5 * 32 + kolom 11
        STA $04
        LDA #$02
        STA $05
        LDX #$00
tfld1:
        LDY #$00
tfld2:
        LDA PF,X
        STA ($04),Y       ; ook nullen, anders blijven gewiste regels staan
        INX
        INY
        CPY #$0A
        BNE tfld2
        LDA $04
        CLC
        ADC #$20
        STA $04
        BCC tfld3
        INC $05
tfld3:
        CPX #$C8
        BNE tfld1
        RTS

tetscore:
        LDA #$1B
        STA $06
        LDA #$0D
        STA $07
        JMP putscore

tetborder:
        LDA #$04
        STA $5A
tb1:
        LDY $5A
        LDA SCRLO,Y
        STA $04
        LDA SCRHI,Y
        STA $05
        LDA #$01
        LDY #$0A
        STA ($04),Y
        LDY #$15
        STA ($04),Y
        INC $5A
        LDA $5A
        CMP #$19
        BNE tb1
        LDY #$19
        LDA SCRLO,Y
        STA $04
        LDA SCRHI,Y
        STA $05
        LDA #$01
        LDY #$0A
tb2:
        STA ($04),Y
        INY
        CPY #$16
        BNE tb2
        RTS

; einde: even laten zien en terug naar het menu
tetover:
        JSR tetfield
        LDA #<TXOVER
        STA $04
        LDA #>TXOVER
        STA $05
        LDA #$0E
        STA $06
        LDA #$0C
        STA $07
        JSR puttext
        LDA #$20
        JSR delay
        JMP boot

; ============================================================================
;  SPACE INVADERS
;
;  Een vloot van 8 bij 4 aliens schuift heen en weer en zakt een rij zodra hij
;  de rand raakt. Jij staat onderin, schiet met W en beweegt met A en D. De
;  aliens laten bommen vallen. Drie levens; raakt de vloot de grond of zijn je
;  levens op, dan is het spel uit. Alle aliens neer betekent een nieuwe golf
;  die een rij lager begint en sneller schuift.
;
;  De vloot wordt alleen opnieuw getekend als hij een stap zet. Kanon, kogel en
;  bom zijn maar een vakje groot en gaan elke ronde. Zou je elke ronde alles
;  hertekenen, dan krijg je hetzelfde geflikker terug als eerder bij Tetris.
;
;  ALIENS is een tabel van 32 bytes: 1 leeft, 0 is neer. Index = rij*8 + kolom.
;
;  $70 vlootpositie x (0..7)   $71 vlootrij      $72 richting (0 rechts)
;  $73 vloot-teller            $74 vloot-snelheid
;  $75 aantal aliens dat leeft $76 kanon-kolom
;  $77/$78 kogel x en y        $79 kogel actief
;  $7A/$7B bom x en y          $7C bom actief
;  $7D levens                  $7E/$7F/$0F hulpbytes
;  $0C kolom, $0D rij, $0E teken-of-wis-vlag
; ============================================================================
invstart:
        JSR clrscreen
        JSR clrscore
        LDA #$03
        STA $7D           ; levens
        LDA #$0C
        STA $74           ; begin-snelheid van de vloot
        LDA #$03
        STA $71           ; bovenste alienrij
        JSR invwave
        JSR invstatus
invloop:
        JSR invkeys
        JSR invbullet
        JSR invbomb
        JSR invfleet
        JSR invcannon
        LDA #$02
        JSR delay
        LDA $75
        BNE invloop
        ; alle aliens neer: volgende golf, een rij lager en sneller
        INC $71
        LDA $74
        CMP #$04
        BCC invnospeed
        DEC $74
        DEC $74
invnospeed:
        JSR invwave
        JMP invloop

; nieuwe golf klaarzetten
invwave:
        LDX #$00
        LDA #$01
iw1:
        STA ALIENS,X
        INX
        CPX #$20
        BNE iw1
        LDA #$20
        STA $75           ; 32 aliens
        LDA #$00
        STA $70
        STA $72
        STA $73
        STA $79           ; geen kogel
        STA $7C           ; geen bom
        LDA #$0F
        STA $76           ; kanon in het midden
        LDA #$01
        STA $0E
        JSR invfleetdraw
        RTS

; een tegel op kolom $0C, rij $0D zetten
invput:
        STA $0F
        LDY $0D
        LDA SCRLO,Y
        STA $08
        LDA SCRHI,Y
        STA $09
        LDY $0C
        LDA $0F
        STA ($08),Y
        RTS

; de hele vloot tekenen ($0E = 1) of wissen ($0E = 0)
invfleetdraw:
        LDA #$00
        STA $7E           ; rij j
ifd1:
        LDA #$00
        STA $7F           ; kolom i
ifd2:
        LDA $7E
        ASL A
        ASL A
        ASL A
        CLC
        ADC $7F
        TAY
        LDA ALIENS,Y
        BEQ ifd3
        LDA $7E           ; beeldrij = vlootrij + j*2
        ASL A
        CLC
        ADC $71
        STA $0D
        LDA $7F           ; beeldkolom = vlootpositie + i*2
        ASL A
        CLC
        ADC $70
        STA $0C
        LDA $0E
        BEQ ifdwis
        LDA $7E
        AND #$01
        CLC
        ADC #$09          ; even rij $09, oneven rij $0A
        JMP ifdzet
ifdwis:
        LDA #$00
ifdzet:
        JSR invput
ifd3:
        INC $7F
        LDA $7F
        CMP #$08
        BNE ifd2
        INC $7E
        LDA $7E
        CMP #$04
        BNE ifd1
        RTS

; toetsen: A en D bewegen, W schiet
invkeys:
        JSR getkey
        CMP #$61
        BEQ ikleft
        CMP #$64
        BEQ ikright
        CMP #$77
        BEQ ikfire
        RTS
ikleft:
        LDA $76
        BEQ ikend
        JSR invcannonwis
        DEC $76
ikend:  RTS
ikright:
        LDA $76
        CMP #$1F
        BEQ ikend
        JSR invcannonwis
        INC $76
        RTS
ikfire:
        LDA $79
        BNE ikend         ; er vliegt er al een
        LDA $76
        STA $77
        LDA #$1C
        STA $78           ; net boven het kanon
        LDA #$01
        STA $79
        RTS

invcannonwis:
        LDA $76
        STA $0C
        LDA #$1D
        STA $0D
        LDA #$00
        JMP invput

invcannon:
        LDA $76
        STA $0C
        LDA #$1D
        STA $0D
        LDA #$0B
        JMP invput

; eigen kogel omhoog
invbullet:
        LDA $79
        BNE ib1
        RTS
ib1:
        LDA $77           ; oude plek wissen
        STA $0C
        LDA $78
        STA $0D
        LDA #$00
        JSR invput
        DEC $78
        LDA $78
        CMP #$01
        BCS ib2
        LDA #$00          ; boven het scherm uit
        STA $79
        RTS
ib2:
        JSR invraak
        LDA $79
        BEQ ibend
        LDA $77
        STA $0C
        LDA $78
        STA $0D
        LDA #$0C
        JSR invput
ibend:  RTS

; raakt de kogel een alien?
invraak:
        LDX #$00
ir1:
        TXA               ; rij j: vlootrij + j*2
        ASL A
        CLC
        ADC $71
        CMP $78
        BEQ ir2
        INX
        CPX #$04
        BNE ir1
        RTS
ir2:
        STX $7E           ; j gevonden
        LDX #$00
ir3:
        TXA               ; kolom i: vlootpositie + i*2
        STA $0F
        ASL A
        CLC
        ADC $70
        STA $7F           ; kolom van deze alien bewaren
        CMP $77
        BEQ ir4
        INX
        CPX #$08
        BNE ir3
        RTS
ir4:
        STX $0F
        LDA $7E
        ASL A
        ASL A
        ASL A
        CLC
        ADC $0F
        TAY
        LDA ALIENS,Y
        BEQ irend
        LDA #$00
        STA ALIENS,Y      ; deze is neer
        LDA $7F           ; alien van het scherm halen, op ZIJN kolom
        STA $0C
        LDA $78
        STA $0D
        LDA #$00
        JSR invput
        LDA #$00
        STA $79           ; kogel is op
        DEC $75
        LDA #$01
        JSR addscore      ; 100 punten
        JSR invstatus
irend:  RTS

; bom van de aliens omlaag
invbomb:
        LDA $7C
        BNE ibm1
        ; nieuwe bom? afhankelijk van het toeval
        LDA $FE
        AND #$3F          ; ongeveer een bom per drie seconden
        BNE ibmend
        JSR invdrop
        RTS
ibm1:
        LDA $7A           ; oude plek wissen
        STA $0C
        LDA $7B
        STA $0D
        LDA #$00
        JSR invput
        INC $7B
        LDA $7B
        CMP #$1D
        BCC ibm2
        LDA #$00          ; onderaan: bom verdwijnt
        STA $7C
        RTS
ibm2:
        LDA $7B           ; op kanonhoogte en op dezelfde kolom?
        CMP #$1C
        BNE ibm3
        LDA $7A
        CMP $76
        BEQ invhit
ibm3:
        LDA $7A
        STA $0C
        LDA $7B
        STA $0D
        LDA #$0D
        JSR invput
ibmend: RTS

; een willekeurige alien laat een bom vallen
invdrop:
        LDA $FD
        AND #$07
        STA $7F           ; kolom i
        LDX #$03          ; onderste levende alien in die kolom zoeken
idp1:
        TXA
        ASL A
        ASL A
        ASL A
        CLC
        ADC $7F
        TAY
        LDA ALIENS,Y
        BNE idp2
        DEX
        BPL idp1
        RTS               ; hele kolom is neer
idp2:
        TXA
        ASL A
        CLC
        ADC $71
        CLC
        ADC #$01
        STA $7B           ; net onder die alien
        LDA $7F
        ASL A
        CLC
        ADC $70
        STA $7A
        LDA #$01
        STA $7C
        RTS

; je bent geraakt
invhit:
        LDA $7A           ; de bom van het scherm halen
        STA $0C
        LDA $7B
        STA $0D
        LDA #$00
        JSR invput
        LDA #$00
        STA $7C
        DEC $7D
        BNE ihleeft
        JMP invover       ; BEQ haalt de sprong niet meer, dus via een JMP
ihleeft:
        JSR invstatus
        JSR invcannonwis  ; oud kanon weg, anders blijft er een spook staan
        LDA #$0F
        STA $76
        JSR invcannon
        LDA #$08
        JSR delay
        RTS

; Vloot verplaatsen.
;
; Belangrijk: NIET eerst de hele vloot wissen en daarna opnieuw tekenen. Dat
; duurt ruim 2000 instructies, en de zender verstuurt in die tijd een stuk of
; acht beelden waarop de helft van de aliens ontbreekt. Precies het geflikker
; dat Tetris eerder had. Daarom wordt per alien gewist en meteen opnieuw
; gezet: dan mist er hoogstens eentje, en dat zie je niet.
invfleet:
        INC $73
        LDA $73
        CMP $74
        BCS if1
        RTS
if1:
        LDA #$00
        STA $73
        LDA $70           ; oude plek onthouden
        STA $66
        LDA $71
        STA $67
        LDA $72
        BNE if2
        LDA $70           ; naar rechts; acht aliens van twee breed is
        CMP #$10          ; veertien kolommen, dus tot en met 16 past
        BCS if3
        INC $70
        JMP if4
if2:
        LDA $70           ; naar links
        BEQ if3
        DEC $70
        JMP if4
if3:
        LDA $72           ; rand geraakt: omkeren en een rij zakken
        EOR #$01
        STA $72
        INC $71
        LDA $71
        CMP #$16
        BCC if4
        JMP invover       ; te laag: verloren
if4:
        ; per alien: wissen op ($66,$67), tekenen op ($70,$71)
        LDA #$00
        STA $7E
ifs1:
        LDA #$00
        STA $7F
ifs2:
        LDA $7E
        ASL A
        ASL A
        ASL A
        CLC
        ADC $7F
        TAY
        LDA ALIENS,Y
        BEQ ifs3
        LDA $7E
        ASL A
        CLC
        ADC $67
        STA $0D
        LDA $7F
        ASL A
        CLC
        ADC $66
        STA $0C
        LDA #$00
        JSR invput
        LDA $7E
        ASL A
        CLC
        ADC $71
        STA $0D
        LDA $7F
        ASL A
        CLC
        ADC $70
        STA $0C
        LDA $7E
        AND #$01
        CLC
        ADC #$09
        JSR invput
ifs3:
        INC $7F
        LDA $7F
        CMP #$08
        BNE ifs2
        INC $7E
        LDA $7E
        CMP #$04
        BNE ifs1
        RTS

; score en levens bovenin
invstatus:
        LDA #$00
        STA $06
        LDA #$0D
        STA $07
        JSR putscore
        LDA #$00
        STA $0D           ; levens als kanonnetjes linksboven
        LDX #$00
ist1:
        TXA
        CLC
        ADC #$01
        STA $0C
        TXA
        CMP $7D
        BCS ist2
        LDA #$0B
        JMP ist3
ist2:
        LDA #$00
ist3:
        JSR invput
        INX
        CPX #$03
        BNE ist1
        RTS

invover:
        LDA #<TXOVER
        STA $04
        LDA #>TXOVER
        STA $05
        LDA #$0E
        STA $06
        LDA #$0C
        STA $07
        JSR puttext
        LDA #$28
        JSR delay
        JMP boot

; ============================================================================
;  BREAKOUT
;
;  Vijf rijen blokjes van elk twee tegels breed, een peddel van vier tegels en
;  een bal die per stap een vakje schuin beweegt. Drie levens. Alle blokjes weg
;  betekent een nieuwe golf waarin de bal sneller gaat.
;
;  De richting staat als $01 of $FF in het geheugen, dus optellen werkt meteen.
;  Omkeren is EOR #$FE: dat wisselt precies tussen die twee waarden.
;
;  Alles wordt incrementeel getekend. De blokjes staan er na de opbouw gewoon;
;  alleen een geraakt blokje wordt gewist. Bal en peddel wissen zichzelf op hun
;  oude plek voordat ze op de nieuwe verschijnen.
;
;  $80 bal x     $81 bal y     $82 richting x   $83 richting y
;  $84 peddel x (linkerkant)   $85 levens       $86 blokjes over
;  $87 balteller $88 balsnelheid   $89/$8A hulp
;
;  BRICKS is 70 bytes: 5 rijen van 14. Blokje i in rij j beslaat de kolommen
;  2+2i en 3+2i, op beeldrij 2+j.
; ============================================================================
brkstart:
        JSR clrscreen
        JSR clrscore
        LDA #$03
        STA $85
        LDA #$03
        STA $88           ; bal beweegt eens per drie ronden
        JSR brkwave
brkloop:
        JSR brkkeys
        JSR brkball
        LDA #$01
        JSR delay
        LDA $86
        BNE brkloop
        ; alles weg: nieuwe golf, en de bal gaat sneller
        LDA $88
        CMP #$02
        BCC brknospeed
        DEC $88
brknospeed:
        JSR brkwave
        JMP brkloop

; nieuwe golf: blokjes vullen, tekenen, bal en peddel klaarzetten
brkwave:
        LDX #$00
        LDA #$01
bw1:
        STA BRICKS,X
        INX
        CPX #$46          ; 70 blokjes
        BNE bw1
        LDA #$46
        STA $86
        LDA #$00
        STA $89           ; rij j
bw2:
        LDA #$00
        STA $8A           ; blokje i
bw3:
        LDA $89           ; beeldrij = 2 + j
        CLC
        ADC #$02
        STA $0D
        LDA $8A           ; linkerkolom = 2 + i*2
        ASL A
        CLC
        ADC #$02
        STA $0C
        LDA $89           ; kleur per rij: $02 t/m $06
        CLC
        ADC #$02
        PHA
        JSR invput
        INC $0C
        PLA
        JSR invput
        INC $8A
        LDA $8A
        CMP #$0E
        BNE bw3
        INC $89
        LDA $89
        CMP #$05
        BNE bw2
        JSR brkreset
        JSR brkstatus
        RTS

; bal en peddel terug naar het midden
brkreset:
        LDA #$0E
        STA $84           ; peddel
        JSR brkpaddle
        LDA #$0F
        STA $80           ; bal boven de peddel
        LDA #$1B
        STA $81
        LDA #$01
        STA $82           ; naar rechtsboven
        LDA #$FF
        STA $83
        LDA #$00
        STA $87
        JSR brkballdraw
        RTS

; peddel tekenen ($0E) of wissen ($00); tegel staat in A
brkput4:
        STA $8A
        LDA #$1D
        STA $0D
        LDA $84
        STA $0C
        LDX #$00
bp1:
        LDA $8A
        JSR invput
        INC $0C
        INX
        CPX #$04
        BNE bp1
        RTS

brkpaddle:
        LDA #$0E
        JMP brkput4
brkpaddlewis:
        LDA #$00
        JMP brkput4

brkballdraw:
        LDA $80
        STA $0C
        LDA $81
        STA $0D
        LDA #$0F
        JMP invput
brkballwis:
        LDA $80
        STA $0C
        LDA $81
        STA $0D
        LDA #$00
        JMP invput

brkkeys:
        JSR getkey
        CMP #$61
        BEQ bkleft
        CMP #$64
        BEQ bkright
        RTS
bkleft:
        LDA $84
        BEQ bkend
        JSR brkpaddlewis
        DEC $84
        JSR brkpaddle
bkend:  RTS
bkright:
        LDA $84
        CMP #$1C          ; vier breed, dus tot en met kolom 28
        BEQ bkend
        JSR brkpaddlewis
        INC $84
        JSR brkpaddle
        RTS

; bal een stap laten zetten
brkball:
        INC $87
        LDA $87
        CMP $88
        BCS bb1
        RTS
bb1:
        LDA #$00
        STA $87
        JSR brkballwis
        ; zijkanten
        LDA $80
        CLC
        ADC $82
        STA $89           ; nieuwe x
        CMP #$01
        BCC bbxkeer
        CMP #$1F
        BCC bbxok
bbxkeer:
        LDA $82
        EOR #$FE          ; wisselt tussen $01 en $FF
        STA $82
        LDA $80
        CLC
        ADC $82
        STA $89
bbxok:
        ; boven- en onderkant
        LDA $81
        CLC
        ADC $83
        STA $8A           ; nieuwe y
        CMP #$01
        BCS bbyok
        LDA $83
        EOR #$FE
        STA $83
        LDA $81
        CLC
        ADC $83
        STA $8A
bbyok:
        LDA $8A
        CMP #$1D          ; peddelhoogte bereikt?
        BCC bbnopad
        LDA $89           ; binnen de peddel?
        SEC
        SBC $84
        CMP #$04
        BCS bbdood
        LDA $83           ; teruggekaatst
        EOR #$FE
        STA $83
        LDA $81
        CLC
        ADC $83
        STA $8A
bbnopad:
        ; blokje geraakt?
        JSR brkbrick
        ; nieuwe plek overnemen en tekenen
        LDA $89
        STA $80
        LDA $8A
        STA $81
        JMP brkballdraw

bbdood:
        DEC $85
        BNE bbleeft
        JMP brkover
bbleeft:
        JSR brkstatus
        JSR brkpaddlewis
        JSR brkreset
        LDA #$08
        JSR delay
        RTS

; zit er een blokje op ($89,$8A)?
brkbrick:
        LDA $8A
        SEC
        SBC #$02
        CMP #$05          ; alleen de rijen 2 t/m 6
        BCS bbrend
        STA $0F           ; j
        LDA $89
        SEC
        SBC #$02
        CMP #$1C          ; kolommen 2 t/m 29
        BCS bbrend
        LSR A             ; i = (x - 2) / 2
        TAX
        LDY $0F
        LDA BRKROW,Y      ; begin van rij j in de tabel
        STX $0F
        CLC
        ADC $0F
        TAY
        LDA BRICKS,Y
        BEQ bbrend
        LDA #$00
        STA BRICKS,Y      ; blokje weg
        DEC $86
        ; beide tegels van dit blokje wissen
        LDA $0F
        ASL A
        CLC
        ADC #$02
        STA $0C
        LDA $8A
        STA $0D
        LDA #$00
        JSR invput
        INC $0C
        LDA #$00
        JSR invput
        ; terugkaatsen en punten
        LDA $83
        EOR #$FE
        STA $83
        LDA $81
        CLC
        ADC $83
        STA $8A
        LDA #$01
        JSR addscore
        JSR brkstatus
bbrend: RTS

; score bovenin en levens linksboven
brkstatus:
        LDA #$00
        STA $06
        LDA #$0D
        STA $07
        JSR putscore
        LDA #$00
        STA $0D
        LDX #$00
bs1:
        TXA
        CLC
        ADC #$01
        STA $0C
        TXA
        CMP $85
        BCS bs2
        LDA #$0F
        JMP bs3
bs2:
        LDA #$00
bs3:
        JSR invput
        INX
        CPX #$03
        BNE bs1
        RTS

brkover:
        LDA #<TXOVER
        STA $04
        LDA #>TXOVER
        STA $05
        LDA #$0E
        STA $06
        LDA #$0C
        STA $07
        JSR puttext
        LDA #$28
        JSR delay
        JMP boot
