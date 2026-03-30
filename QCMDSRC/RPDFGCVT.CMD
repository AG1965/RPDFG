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

             PARM      KWD(MARGINS) TYPE(MARGINS)  +
                          PROMPT(CMD0010) 

 QUALJOB:    QUAL       TYPE(*NAME) LEN(10)
             QUAL       TYPE(*NAME) LEN(10) PROMPT(CMD0007)
             QUAL       TYPE(*CHAR) LEN(6) RANGE(000001 999999) +
                          PROMPT(CMD0008)

 MARGINS:    ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0011) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0012) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0013) DFT(14.173)
             ELEM       TYPE(*DEC) LEN(8 3) PROMPT(CMD0014) DFT(14.173)
