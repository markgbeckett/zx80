  10 REM PROGRAM TO COMPUTE
  20 REM SUNRISE AND SUNET TIMES
  30 REM AT A GIVEN LOCATION,
  40 REM TIMEZONE, AND DATE
  50 REM 
  60 REM ADAPTED FROM PROGRAM BY 
  70 REM R.G. STUART, MEXICO CITY
  80 REM SKY AND TELESCOPE 89.3
  90 REM (1995), PP.84-
 100 REM SUNRISE/SUNSET TABLE
 110 GOSUB 9000
 120 GOSUB 8000
 130 GOSUB 3000
 140 PRINT 
 150 PRINT "--------------------------------"
 155 PRINT "DATE         SUNRISE SUNSET"
 160 FOR I=1 TO 7
 170 PRINT 
 180 GOSUB 4000
 190 PRINT "  ";
 200 GOSUB 5000
 210 GOSUB 2000
 220 NEXT I
 230 PRINT 
 240 PRINT "--------------------------------"
 250 STOP 
2000 REM FIND NEXT DAY
2010 LET D=D+1
2020 IF D<=N(M) THEN RETURN 
2030 LET D=1
2040 LET M=M+1
2050 IF M<=12 THEN RETURN 
2060 LET M=1
2070 LET Y=Y+1
2080 RETURN 
3000 REM CHECK FOR LEAP YEAR
3010 LET T1=Y/4
3020 IF (T1<>INT T1) THEN RETURN 
3030 LET T1=Y/100
3040 IF (T1=INT T1) THEN GOTO 3070
3050 LET N(2)=N(2)+1
3060 RETURN 
3070 LET T1=Y/400
3080 IF (T1<>INT T1) THEN RETURN 
3090 GOTO 3050
4000 REM PRINT DATE
4010 LET T=D
4020 GOSUB 7100
4030 PRINT "/";
4040 LET T=M
4050 GOSUB 7100
4060 PRINT "/";
4070 LET T=Y
4080 GOSUB 7000
4090 RETURN 
5000 REM COMPUTE SUN UP AND SUN DOWN
5010 LET N=INT (275*M/9)-2*INT ((M+9)/12)+D-30
5020 LET L0=4.8771+0.0172*(N+0.5-L5/360)
5030 LET C=0.03342*SIN (L0+1.345)
5040 LET C2=RD*(ATN (TAN (L0+C))-ATN (0.9175*TAN (L0+C))-C)
5050 LET SD=0.3978*SIN (L0+C)
5060 LET CD=SQR (1-SD*SD)
5070 LET SC=(SD*SIN (B5)+0.0145)/(COS (B5)*CD)
5080 PRINT " ";
5090 IF ABS (SC)<=1 THEN GOSUB 5130
5100 IF SC>1 THEN PRINT "SUN UP ALL DAY"
5110 IF SC<-1 THEN PRINT "SUN DOWN ALL DAY"
5120 GOTO 5350
5130 LET C3=RD*ATN (SC/SQR (1-SC*SC))
5140 LET R1=6-H-(L5+C2+C3)/15
5150 LET HR=INT (R1)
5160 LET MR=INT ((R1-HR)*60)
5170 LET S1=18-H-(L5+C2-C3)/15
5180 LET HS=INT (S1)
5190 LET MS=INT ((S1-HS)*60)
5200 LET T=HR
5210 GOSUB 7100
5220 PRINT ":";
5230 LET T=MR
5240 GOSUB 7100
5250 PRINT "   ";
5260 LET T=HS
5270 GOSUB 7100
5280 PRINT ":";
5290 LET T=MS
5300 GOSUB 7100
5350 RETURN 
7000 REM PRINT FOUR-DIGIT NUMBER
7010 IF T<1000 THEN PRINT "0";
7020 IF T<100 THEN PRINT "0";
7100 REM PRINT TWO-DIGIT NUMBER
7110 IF T<10 THEN PRINT "0";
7120 PRINT T;
7130 RETURN 
8000 REM GET INPUTS
8010 PRINT "ENTER LATITUDE (DEG) ";
8020 INPUT B5
8030 PRINT B5
8035 LET B5=DR*B5
8040 PRINT "ENTER LONGDITUDE (DEG) ";
8050 INPUT L5
8060 PRINT L5
8070 PRINT "ENTER TIMEZONE (HRS) ";
8080 INPUT H
8090 PRINT H
8100 PRINT "ENTER DATE (D,M,Y) ";
8110 INPUT D
8120 INPUT M
8130 INPUT Y
8140 GOSUB 4000
8150 RETURN 
9000 REM INITIALISATION
9010 DIM N(12)
9020 LET N(1)=31
9025 LET N(2)=28
9030 LET N(3)=31
9035 LET N(4)=30
9040 LET N(5)=31
9045 LET N(6)=30
9050 LET N(7)=31
9055 LET N(8)=31
9060 LET N(9)=30
9065 LET N(10)=31
9070 LET N(11)=30
9075 LET N(12)=31
9080 LET DR=PI/180
9090 LET RD=1/DR
9100 RETURN 
