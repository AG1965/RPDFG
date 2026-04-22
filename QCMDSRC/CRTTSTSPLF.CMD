            CMD        PROMPT('Test-Spooldatei erzeugen') TEXT(*CMDPMT)

            PARM       KWD(PAGESIZE) TYPE(PAGESIZE) +
                        PROMPT('Seitengröße')

            PARM       KWD(PAGES) TYPE(*DEC) LEN(3 0) RANGE(1 99) +
                        DFT(1) PROMPT('Anzahl zu erzeugender Seiten')

            PARM       KWD(LPI) TYPE(*DEC) LEN(5 1) +
                        RSTD(*YES) VALUES(3 4 6 7.5 8 9 12) +
                        PROMPT('Zeilen je Zoll')

            PARM       KWD(CPI) TYPE(*DEC) LEN(5 1) +
                        RSTD(*YES) VALUES(5 10 12 13.3 15 16.7 18 20) +
                        PROMPT('Zeichen je Zoll')

            PARM       KWD(PAGRTT) TYPE(*DEC) LEN(3 0) +
                        RSTD(*YES) VALUES(0 90 180 270) DFT(*NOCHG) +
                        SPCVAL((*NOCHG -4) (*AUTO -1) (*DEVD -2) (*COR -3)) +

            PARM       KWD(FONT) TYPE(FONT) +
                          PROMPT('Schriftart')

            PARM       KWD(OUTQ) TYPE(QUALOBJ) +
                          PROMPT('Ausgabewarteschlange')

            PARM       KWD(HOLD) TYPE(*CHAR) LEN(10) DFT(*YES) +
                          RSTD(*YES) VALUES(*YES *NO) +
                          PROMPT('Spool-Datei anhalten')

            PARM       KWD(SAVE) TYPE(*CHAR) LEN(10) DFT(*NO) +
                          RSTD(*YES) VALUES(*YES *NO) +
                          PROMPT('Spool-Datei sichern')

PAGESIZE:   ELEM TYPE(*DEC) LEN(3 0) DFT(72) RANGE(1 255) +
                 PROMPT('Zeilen pro Seite')
            ELEM TYPE(*DEC) LEN(3 0) DFT(132) RANGE(1 378) +
                 PROMPT('Zeichen pro Zeile')


FONT:       ELEM TYPE(*DEC) LEN(10 0) +
                 PROMPT('Kennung')
            ELEM TYPE(*DEC) LEN(4 1) RANGE(0.1 999.9) +
                 PROMPT('Punktgröße')

QUALOBJ:    QUAL       TYPE(*NAME) LEN(10) MIN(1)
            QUAL       TYPE(*NAME) LEN(10) DFT(*LIBL) +
                         SPCVAL((*LIBL)) PROMPT('Bibliothek')
