**FREE

Ctl-Opt DFTACTGRP(*NO) OPTION(*NODEBUGIO:*SRCSTMT:*NOUNREF) DEBUG(*CONSTANTS);
Ctl-Opt TEXT('Create Test-Spooled File');

Dcl-F QSYSPRT PRINTER(378) USROPN OFLIND(OverflowIndicator);

Dcl-S OverflowIndicator IND;
Dcl-DS PrtCtlDS qualified len(15) ;
   SpaceBefore char(3) inz('  0') ;
   SpaceAfter  char(3) inz('  1') ;
   SkipBefore  char(3) inz('  0') ;
   SkipAfter   char(3) inz('  0') ;
End-DS;

Dcl-DS myOutput       QUALIFIED;
   Line    Char(378);
End-DS;

Dcl-S myRuler  LIKE(myOutput.Line);

Dcl-DS QualObj_T  QUALIFIED TEMPLATE;
   Name                CHAR(10);
   LibName             CHAR(10);
End-DS;

Dcl-DS PI_PageSize_T  QUALIFIED TEMPLATE;
   NbrOfElems          Int(5);
   LINES               Packed(3:0);
   COLS                Packed(3:0);
End-DS;

Dcl-DS PI_Font_T      QUALIFIED TEMPLATE;
   NbrOfElems          Int(5);
   ID                  Packed(10:0);
   POINTS              Packed(4:1);
End-DS;


Dcl-C SEQ_1_10        '----+----0';
Dcl-C PAGRTT_NOCHG    -4;
Dcl-C PAGRTT_AUTO     -1;
Dcl-C PAGRTT_DEVD     -2;
Dcl-C PAGRTT_COR      -3;

Dcl-S #i              PACKED(3:0);
Dcl-S #p              PACKED(3:0);
Dcl-S #l              PACKED(3:0);
Dcl-S #Page           PACKED(3:0) INZ(0);

Dcl-S #Cmd_Output     LIKE(#Cmd);
Dcl-S #Cmd            Varchar(3000);
Dcl-PR QCMDEXC  EXTPGM('QCMDEXC');
   Cmd            Char(32000) OPTIONS(*VARSIZE) CONST;
   CmdLen         Packed(15:5) CONST;
End-PR;

// -----------------------------------------------------------------------------
Dcl-PI *N;
   PI_PageSize   LIKEDS(PI_PageSize_T);
   PI_Pages      PACKED(3:0);
   PI_LPI        PACKED(5:1);
   PI_CPI        PACKED(5:1);
   PI_PagRtt     PACKED(3:0);
   PI_Font       LIKEDS(PI_Font_T);
   PI_Outq       LIKEDS(QualObj_T);
   PI_Hold       CHAR(10);
   PI_Save       CHAR(10);
End-PI;


#Cmd = 'OVRPRTF FILE(QSYSPRT)' +
              ' PAGESIZE(' + %CHAR(PI_PAGESIZE.LINES) + ' ' +
                             %CHAR(PI_PAGESIZE.COLS) + ')' +
                ' OVRFLW(' + %CHAR(PI_PAGESIZE.LINES) + ')';
SELECT;
   WHEN %SUBST(PI_OUTQ.Name:1:1) = '*';
      #Cmd += ' OUTQ(' + PI_OUTQ.Name + ')';
   WHEN PI_OUTQ.Name <> '';
      #Cmd += ' OUTQ(' + %TRIMR(PI_Outq.LibName) + '/' + PI_OUTQ.Name + ')';
ENDSL;

IF PI_LPI <> 0;
   #Cmd += ' LPI(' + %CHAR(PI_LPI) + ')';
ENDIF;
IF PI_CPI <> 0;
   #Cmd += ' CPI(' + %CHAR(PI_CPI) + ')';
ENDIF;
IF PI_FONT.ID <> 0;
   #Cmd += ' FONT(' + %CHAR(PI_FONT.ID);
   IF PI_FONT.POINTS <> 0;
      #Cmd += ' ' + %CHAR(PI_FONT.POINTS);
   ENDIF;
   #Cmd += ')';
ENDIF;

SELECT;
   WHEN PI_PagRtt = PAGRTT_NOCHG;
   WHEN PI_PagRtt = PAGRTT_AUTO;
      #Cmd += ' PAGRTT(*AUTO)';
   WHEN PI_PagRtt = PAGRTT_DEVD;
      #Cmd += ' PAGRTT(*DEVD)';
   WHEN PI_PagRtt = PAGRTT_COR;
      #Cmd += ' PAGRTT(*COR)';
   WHEN PI_PagRtt >= 0;
      #Cmd += ' PAGRTT(' + %CHAR(PI_PagRtt) + ')';
ENDSL;
#Cmd += ' HOLD(' + %TRIMR(PI_Hold) + ')' +
        ' SAVE(' + %TRIMR(PI_Save) + ')' +
        ' SECURE(*YES)';

QCMDEXC(#Cmd:%LEN(#Cmd));

OPEN QSYSPRT;

EXEC SQL   SET :myRuler = REPEAT(:SEQ_1_10, 40);
FOR #i = 10 TO 378 BY 10;
   %SUBST(myRuler:#i-%LEN(%CHAR(#i))+1:%LEN(%CHAR(#i))) = %CHAR(#i);
ENDFOR;

FOR #Page = 1 TO PI_Pages;

   PrtCtlDS.SkipBefore = '001';

   FOR #i = 1 TO PI_PageSize.LINES;

      RESET myOutput;
      myOutput.Line = myRuler;

      IF #i = 1;
         %SUBST(myOutput.Line:PI_PageSize.COLS-8:9) = ' Seite' +
                                                      %EDITW(#Page:'  0');
         %SUBST(myOutput.Line:22:21) = ' ' +
                %SCANRPL('.':':':%SUBST(%CHAR(%TIMESTAMP()):1:19));
         #Cmd_Output = #Cmd;
      ENDIF;

      %SUBST(myOutput.Line:3:5) = ' ' + %EDITW(#i:'  0');

      IF #i = 11;
         #l = %LEN(#Cmd_Output);
         IF #l > PI_PageSize.COLS - 30;
            #Cmd_Output = '...' + %SUBST(#Cmd_Output:#l-(PI_PageSize.COLS-33)+1);
            #l = %SCANR(' ':#Cmd_Output:1:%INT(#l / 2));
         ENDIF;
         #p = (PI_PageSize.COLS - #l) / 2 + 1;
         %SUBST(myOutput.Line:
                #p:
                #l+2) = ' ' + %SUBST(#Cmd_Output:1:#l);
         IF #l <> %LEN(#Cmd_Output);
            #Cmd_Output = %SUBST(#Cmd_Output:#l + 1);
         ELSE;
            #Cmd_Output = '';
         ENDIF;
      ENDIF;

      IF #i = 12 AND #Cmd_Output <> '';
         #p = (PI_PageSize.COLS - %LEN(#Cmd_Output)) / 2 + 1;
         %SUBST(myOutput.Line:
                #p:
                %LEN(#Cmd_Output)+2) = ' ' + #Cmd_Output;
      ENDIF;

      IF PI_PageSize.COLS < 378;
         %SUBST(myOutput.Line:PI_PageSize.COLS + 1) = '';
      ENDIF;

      WRITE QSYSPRT myOutput;
      RESET PrtCtlDS;

   ENDFOR;

ENDFOR;



*INLR = *ON;