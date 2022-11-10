  10 LET DR=PI/180
  20 LET RD=1/DR
  30 PRINT "ENTER LATITUDE (DEG)  ";
  40 INPUT B5
  50 PRINT B5
  60 PRINT "ENTER LONGDITUDE (DEG) ";
  70 INPUT L5
  80 PRINT L5
  90 PRINT "ENTER TIMEZONE (HRS) ";
 100 INPUT H
 110 PRINT H
 120 PRINT "ENTER MONTH, DAY ";
 130 INPUT M
 140 LET N=M
 145 GOSUB 600
 150 PRINT "/";
 160 INPUT D
 170 LET N=D
 180 GOSUB 600
 185 PRINT 
 190 LET B5=DR*B5
 200 LET N=INT (275*M/9)-2*INT ((M+9)/12)+D-30
 210 LET L0=4.8771+0.0172*(N+0.5-L5/360)
 220 LET C=0.03342*SIN (L0+1.345)
 230 LET C2=RD*(ATN (TAN (L0+C))-ATN (0.9175*TAN (L0+C))-C)
 240 LET SD=0.3978*SIN (L0+C)
 250 LET CD=SQR (1-SD*SD)
 260 LET SC=(SD*SIN (B5)+0.0145)/(COS (B5)*CD)
 270 IF ABS (SC)<=1 THEN GOTO 310
 280 IF SC>1 THEN PRINT "SUN UP ALL DAY"
 290 IF SC<-1 THEN PRINT "SUN DOWN ALL DAY"
 300 GOTO 520
 310 LET C3=RD*ATN (SC/SQR (1-SC*SC))
 320 LET R1=6-H-(L5+C2+C3)/15
 330 LET HR=INT (R1)
 340 LET MR=INT ((R1-HR)*60)
 350 PRINT 
 360 LET S1=18-H-(L5+C2-C3)/15
 370 LET HS=INT (S1)
 380 LET MS=INT ((S1-HS)*60)
 390 PRINT "SUNRISE AT ";
 400 LET N=HR
 410 GOSUB 600
 420 PRINT ":";
 430 LET N=MR
 440 GOSUB 600
 450 PRINT 
 460 PRINT "SUNSET AT  ";
 470 LET N=HS
 480 GOSUB 600
 490 PRINT ":";
 500 LET N=MS
 510 GOSUB 600
 520 STOP 
 600 REM PRINT TWO-DIGIT N
 610 IF N<10 THEN PRINT "0";
 620 PRINT N;
 630 RETURN 
 990 REM 55.9533,-3.1883