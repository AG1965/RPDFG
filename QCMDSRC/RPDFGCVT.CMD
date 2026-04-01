             CMD        PROMPT(CMD0001) +
                        PMTFILE(RPDFGMSGF *DYNAMIC) +
                        MSGF(RPDFGMSGF) +           
                        HLPID(*CMD) +        
                        HLPPNLGRP(RPDFGCVT) +
                        TEXT(*CMDPMT)              

             PARM       KWD(FILE) TYPE(*NAME) LEN(10) MIN(1) +
                          PROMPT(CMD0002)

             PARM       KWD(JOB) TYPE(QUALJOB) SNGVAL((*)) DFT(*) PROMPT(CMD0003)

             PARM       KWD(SPLNBR) TYPE(*INT4) DFT(*LAST) +
                          RANGE(000001 999999) SPCVAL((*ONLY 0) (*LAST -1)) +
                          PROMPT(CMD0004)

             PARM       KWD(PDFDIR) TYPE(*PNAME) CASE(*MIXED) DFT('.') LEN(128) VARY(*YES *INT2) +
                          PROMPT(CMD0005)

             PARM       KWD(PDFNAME) TYPE(*PNAME) LEN(128) VARY(*YES *INT2) +
                          DFT('<FILE>_<CRTDATE>_<CRTTIME>.pdf') CASE(*MIXED) +
                          PROMPT(CMD0006)

             PARM       KWD(PAPERSIZE) TYPE(*CHAR) LEN(20) VARY(*YES *INT2) RSTD(*YES) DFT(A4) +
                          VALUES(A3 A4 A5 +
                                 US_INVOICE US_EXECUTIVE US_LEGAL US_LETTER US_LEDGER) +
                          PROMPT(CMD0009)

             PARM      KWD(PAGRTT) TYPE(*CHAR) LEN(10) RSTD(*YES) DFT(*SPLFA) +
                          VALUES(*SPLFA *AUTO 0 90 180 270) +
                          PROMPT(CMD0022) 

             PARM      KWD(MARGINS) TYPE(MARGINS)  +
                          PROMPT(CMD0010) 

             PARM      KWD(TIMEZONE) TYPE(TIMEZONE) SNGVAL(*UTC) +
                          PROMPT(CMD0015) PMTCTL(*PMTRQS)

             PARM      KWD(OPTIONS) TYPE(*CHAR) LEN(10) SNGVAL(*NONE) MAX(10) +
                          DFT(*NONE) RSTD(*YES) +
                          SPCVAL((*NONE) (*GREENBAR) (*NUMBERS)) +
                          PROMPT(CMD0023) PMTCTL(*PMTRQS)

 QUALJOB:    QUAL       TYPE(*NAME) LEN(10)
             QUAL       TYPE(*NAME) LEN(10) PROMPT(CMD0007)
             QUAL       TYPE(*CHAR) LEN(6) RANGE(000001 999999) +
                          PROMPT(CMD0008)

 MARGINS:    ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0011) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0012) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0013) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0014) DFT(14.173)

 TIMEZONE:   ELEM       TYPE(*CHAR) LEN(5)   PROMPT(CMD0016) DFT(+0100)
             ELEM       TYPE(*CHAR) LEN(5)   PROMPT(CMD0017) DFT(+0200)
             ELEM       TYPE(*DEC)  LEN(2 0) PROMPT(CMD0018) DFT(03) RANGE(01 12)
             ELEM       TYPE(*CHAR) LEN(1)   RSTD(*YES) DFT(*LAST) SPCVAL((*LAST L)) +
                        VALUES(1 2 3 4 5 L) PROMPT(CMD0019)
             ELEM       TYPE(*DEC) LEN(2 0) PROMPT(CMD0020) DFT(10) RANGE(01 12)
             ELEM       TYPE(*CHAR) LEN(1)   RSTD(*YES) DFT(*LAST) SPCVAL((*LAST L)) +
                        VALUES(1 2 3 4 5 L) PROMPT(CMD0021)
