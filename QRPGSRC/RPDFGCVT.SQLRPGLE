**FREE
CTL-OPT MAIN(MAIN) DFTACTGRP(*NO) ACTGRP('RPDFG') BNDDIR('RPDFG')
        OPTION(*NODEBUGIO:*SRCSTMT:*NOUNREF)
        DATEDIT(*YMD) CCSID(*EXACT) CCSIDCVT(*LIST:*EXCP)
        TEXT('RPDFGCVT - Convert SCS spooled files to PDF format');
// -----------------------------------------------------------------------------
// RPDFGCVT - Convert SCS spooled files to PDF format
// -----------------------------------------------------------------------------
Dcl-PR MAIN EXTPGM('RPDFGCVT');
   SplfName        CHAR( 10) CONST;
   QualJob         CHAR( 26) CONST;
   SplfNbr          INT( 10) CONST;
   PDF_Path     VARCHAR(128) CONST;
   PDF_File     VARCHAR(128) CONST;
   PaperFormat  VARCHAR( 20) CONST;
   Margins       LIKEDS(RPDFG_Margins_T) CONST;
   TimeZones     LIKEDS(RPDFG_TimeZone_T) CONST;
End-PR;

// max. number of "Pages" objects in the "Pages" tree
Dcl-C  PAGES_PER_PAGES        5;
// max. number of "Page" objects in a "Pages" object
Dcl-C  PAGE_PER_PAGES         5;

Dcl-C  SQL_OK                 0;
Dcl-C  SQL_ERROR_NOTFOUND     100;

Dcl-C  SPLFNBR_ONLY_NUM       0;
Dcl-C  SPLFNBR_LAST_NUM       -1;

Dcl-DS CCSID_JOBRUN CONST QUALIFIED;
   SLASH       CHAR(1) INZ('/') CCSID(*JOBRUN);
   COLON       CHAR(1) INZ(':') CCSID(*JOBRUN);
   UNDERLINE   CHAR(1) INZ('_') CCSID(*JOBRUN);
End-DS;

Dcl-S  RPDFGMSGF  CHAR(21) CONST CCSID(*JOBRUN) INZ('*LIBL/RPDFGMSGF');
Dcl-DS MSGID QUALIFIED CONST;
   RPDF001     CHAR(7) INZ('RPDF001') CCSID(*JOBRUN);
   RPDF003     CHAR(7) INZ('RPDF003') CCSID(*JOBRUN);
   RPDF004     CHAR(7) INZ('RPDF004') CCSID(*JOBRUN);
   RPDF005     CHAR(7) INZ('RPDF005') CCSID(*JOBRUN);
   RPDF006     CHAR(7) INZ('RPDF006') CCSID(*JOBRUN);
   RPDF007     CHAR(7) INZ('RPDF007') CCSID(*JOBRUN);
   RPDF008     CHAR(7) INZ('RPDF008') CCSID(*JOBRUN);
   RPDF009     CHAR(7) INZ('RPDF009') CCSID(*JOBRUN);
End-DS;

Dcl-ENum PAGRTT QUALIFIED;
   AUTO              '*AUTO';
   DEVD              '*DEVD';
   COR               '*COR';
   PORTRAIT          '0';
   LANDSCAPE         '90';
   PORTRAIT_REVERSE  '180';
   LANDSCAPE_REVERSE '270';
End-ENum;


Dcl-PR QCMDEXC EXTPGM('QCMDEXC');
   CmdString     CHAR(32702) CONST OPTIONS(*VARSIZE);
   CmdLength   PACKED(15:5)  CONST;
End-PR;

// -----------------------------------------------------------------------------
Dcl-DS SQL_Diag QUALIFIED;
   MessageId        char(10) ;
   MessageId1       varchar(7) ;
   MessageId2       like(SQL_Diag.MessageId1) ;
   MessageLength    int(5) ;
   MessageText      varchar(32740) ;
   ReturnedSQLCode  char(5) ;
   ReturnedSQLState char(5) ;
   RowsCount        int(10) ;
End-DS;

// Program Status Data Structure
Dcl-DS PSDS PSDS QUALIFIED;
   JobName   CHAR(10) POS(244);
   JobUser   CHAR(10) POS(254);
   JobNumber CHAR( 6) POS(264);
   CompileUDate CHAR( 6) POS(288);
   CompileTime  CHAR( 6) POS(294);
End-DS;

// message data for message ids RPDF0002 - RPDF0009
Dcl-DS RPDF000n QUALIFIED;
   idx        INT(10);
   maxIdx     INT(10);
   key        CHAR(16);
   value1     CHAR(128);
   value2     CHAR(128);
End-DS;

/INCLUDE 'QSRVCPY/RPDFG.RPGLEINC'

/INCLUDE 'QSYSCPY/DIFS.RPGLEINC'
/INCLUDE 'QSYSCPY/PERRNO.RPGLEINC'



// =============================================================================
// M A I N
// =============================================================================
Dcl-Proc MAIN;
   Dcl-PI *N;
      p_SplfName        CHAR( 10) CONST;
      p_QualJob         CHAR( 26) CONST;
      p_SplfNbr          INT( 10) CONST;
      p_PDF_Path     VARCHAR(128) CONST;
      p_PDF_File     VARCHAR(128) CONST;
      p_PaperFormat  VARCHAR( 20) CONST;
      p_Margins       LIKEDS(RPDFG_Margins_T)  CONST;
      p_TimeZones     LIKEDS(RPDFG_TimeZone_T) CONST;
   End-PI;

   Dcl-DS h_QualJob QUALIFIED;
      Name        CHAR(10);
      User        CHAR(10);
      Number      CHAR( 6);
   End-DS;
   Dcl-S  h_Job            VARCHAR(28);
   Dcl-S  h_SplfName       CHAR(10);
   Dcl-S  h_SplfNbr        INT(10);
   Dcl-S  h_SplfNbrChar    CHAR(5);

   Dcl-S  TotalPageCount   INT(10) Inz(0);
   Dcl-S  PageCount        INT(10) Inz(0);

   Dcl-S  Offset           INT(10) Inz(0);

   Dcl-S  h_OutBuffer      VARCHAR(100000) INZ('') CCSID(*UTF8);

   Dcl-S  h_Cmd            VARCHAR(2000) INZ('');

   // various object indices
   Dcl-S  i_Root           INT(10);
   Dcl-S  i_F1             INT(10);
   Dcl-S  i_Font           INT(10);
   Dcl-S  h_Font           INT(10);
   Dcl-S  i_PagesRoot      INT(10);
   Dcl-S  i_Pages          INT(10) INZ(-1);
   Dcl-S  i_Contents       INT(10) INZ(-1);
   Dcl-S  i_Page           INT(10);
   Dcl-S  i_Info           INT(10);
   Dcl-S  i_Xref           INT(10);
   Dcl-S  i_Trailer        INT(10);

   Dcl-S  pdfObjRef_Root   LIKE(RPDFG_ref);
   Dcl-S  pdfObjRef_Font   LIKE(RPDFG_ref);
   Dcl-S  pdfObjRef_Info   LIKE(RPDFG_ref);

   Dcl-S  h_startxref      INT(10) INZ(0);

   // pages depth - needed for page tree structure
   // how many elements are on each level of the page tree
   Dcl-DS h_PageDepth      DIM(10) QUALIFIED;
      count                INT(10) INZ(0);
      objIdx               INT(10) INZ(0);
   End-DS;
   Dcl-S  h_PageDepthMax   INT(10);
   // how many Page-objects fit into all Pages objects
   Dcl-S  h_DepthMaxPages  INT(10);

   Dcl-S  h_Resources_string  VARCHAR(1000) CCSID(*UTF8);
   Dcl-S  h_MediaBox_string   LIKE(RPDFG_getMediaBoxString);

   Dcl-DS SplfAtr LIKEDS(RPDFG_SplfAtr_T) DIM(*AUTO:2);

   Dcl-DS SplDta QUALIFIED;
      FCFC        CHAR(  1);
      LINE        CHAR(378);
   End-DS;

   Dcl-ENum FCFC QUALIFIED;
      SPACE      ' ';
      SPACE2     '0';
      SPACE3     '-';
      SUPPRESS   '+';
      CHANNEL01  '1';
      CHANNEL02  '2';
      CHANNEL03  '3';
      CHANNEL04  '4';
      CHANNEL05  '5';
      CHANNEL06  '6';
      CHANNEL07  '7';
      CHANNEL08  '8';
      CHANNEL09  '9';
      CHANNEL10  'A';
      CHANNEL11  'B';
      CHANNEL12  'C';
   End-ENum;

   Dcl-S  h_LineNumber INT(10);
   Dcl-S  h_PosX       PACKED(10:4);
   Dcl-S  h_PosY       PACKED(10:4);

   Dcl-S  #i           INT(10);
   Dcl-S  #d           INT(10);

   Dcl-S  Sav_SQLCOD   LIKE(SQLCOD);

   // For output - bad idea
   Dcl-DS xref QUALIFIED;
      ByteOffset    ZONED(10);
      ObjNumber       INT(10);
      GenNumber       INT(10);
      InUse           CHAR(1);
   End-DS;

   // message data for message id RPDF0001
   Dcl-DS RPDF0001 QUALIFIED;
      SplFName   CHAR(10);
      JobName    CHAR(10);
      JobUser    CHAR(10);
      JobNumber  CHAR(6);
      SplfNbr    CHAR(5);
   End-DS;
   // --------------------------------------------------------------------------



   // --------------------------------------------------------------------------
   RPDFG_initPaperFormat(p_PaperFormat:
                         p_Margins.Left:
                         p_Margins.Top:
                         p_Margins.Right:
                         p_Margins.Bottom);
   // --------------------------------------------------------------------------
   h_QualJob = p_QualJob;
   IF h_QualJob.Name = '*';
      h_QualJob.Name   = PSDS.JobName;
      h_QualJob.User   = PSDS.JobUser;
      h_QualJob.Number = PSDS.JobNumber;
   ENDIF;
   h_Job = %TRIMR(h_QualJob.Number) + '/' +
           %TRIMR(h_QualJob.User) + '/' +
           %TRIMR(h_QualJob.Name);
   h_SplfName = p_SplfName;
   h_SplfNbr  = p_SplfNbr;


   // retrieve the spooled file attributes and check that we got only one spooled file
   EXEC SQL DECLARE C1 CURSOR FOR
            SELECT OUTPUT_QUEUE_NAME,
                   OUTPUT_QUEUE_LIBRARY_NAME,
                   SPOOLED_FILE_NAME,
                   FILE_NUMBER,
                   USER_NAME,
                   STRIP(COALESCE(USER_DATA, 'no_usrdta')) USER_DATA,
                   JOB_NAME,
                   CREATE_TIMESTAMP,
                   TOTAL_PAGES,
                   STRIP(FORM_TYPE),
                   PAGE_LENGTH,
                   PAGE_WIDTH,
                   PAGE_ROTATION
              FROM QSYS2.OUTPUT_QUEUE_ENTRIES
             WHERE SPOOLED_FILE_NAME = :h_SplfName
               AND JOB_NAME          = :h_Job
               AND (FILE_NUMBER      = :h_SplfNbr OR :h_SplfNbr < 1)
             ORDER BY FILE_NUMBER DESC
             LIMIT 2;

   EXEC SQL OPEN C1;
   Sav_SQLCOD = SQLCOD;
   IF Sav_SQLCOD = SQL_OK;
      EXEC SQL FETCH C1
                 FOR 2 ROWS
                INTO :SplfAtr;
      Sav_SQLCOD = SQLCOD;
   ENDIF;
   EXEC SQL CLOSE C1;

   SELECT;
      WHEN Sav_SQLCOD = SQL_OK OR
           (Sav_SQLCOD > 0 AND
            Sav_SQLCOD <> SQL_ERROR_NOTFOUND);
         IF p_SplfNbr = SPLFNBR_ONLY_NUM AND
            %ELEM(SplfAtr) > 1;
            // TODO: nicht eindeutig, mehrere Spooldateien gefunden
         ENDIF;
      WHEN Sav_SQLCOD = SQL_ERROR_NOTFOUND;
         RPDF0001.SplFName = h_SplfName;
         RPDF0001.JobName  = h_QualJob.Name;
         RPDF0001.JobUser  = h_QualJob.User;
         RPDF0001.JobNumber= h_QualJob.Number;
         SELECT;
            WHEN p_SplfNbr = SPLFNBR_ONLY_NUM;
               h_SplfNbrChar = '*ONLY';
            WHEN p_SplfNbr = SPLFNBR_LAST_NUM;
               h_SplfNbrChar = '*LAST';
            OTHER;
               h_SplfNbrChar = %CHAR(p_SplfNbr);
         ENDSL;
         RPDF0001.SplfNbr  = h_SplfNbrChar;
         SND-MSG *ESCAPE %MSG(MSGID.RPDF001:RPDFGMSGF:RPDF0001)
                         %TARGET(*CTLBDY:1);
      OTHER;
         // TODO: SQL error handling
         // SND-MSG *ESCAPE %MSG('RPDF001':RPDFGMSGF:RPDF0001)
         //                 %TARGET(*CTLBDY:1);
   ENDSL;

   RPDFG_openPdfFile(p_PDF_Path:p_PDF_File:SplfAtr(1));

   MONITOR;
      h_Cmd = 'CRTPF FILE(QTEMP/RPDFGCVT) RCDLEN(387) SIZE(*NOMAX)';
      QCMDEXC(h_Cmd:%LEN(h_Cmd));
   ON-ERROR;
   ENDMON;

   h_Cmd = 'CPYSPLF FILE(' + SplfAtr(1).SplfName +')' +
                  ' TOFILE(QTEMP/RPDFGCVT)' +
                  ' JOB(' + h_Job + ')' +
                  ' SPLNBR(' + %CHAR(h_SplfNbr) + ')' +
                  ' CTLCHAR(*FCFC)';
   QCMDEXC(h_Cmd:%LEN(h_Cmd));

   EXEC SQL DECLARE C2 CURSOR FOR
            SELECT SUBSTR(RPDFGCVT, 1, 1) FCFC,
                   SUBSTR(RPDFGCVT, 2, 378) LINE
              FROM QTEMP.RPDFGCVT;

   EXEC SQL OPEN C2;

   // ==========================================================================
   // --------------------------------------------------------------------------
   // actual PDF creation
   RPDFG_calculatePrintingValues(SplfAtr(1).Page_Rotation:
                                 SplfAtr(1).Page_Length:
                                 SplfAtr(1).Page_Width);

   // Strategy for large PDF files with many pages:
   // The PDF-file has to know it's pages-page-tree with parent kids and count 
   // of kids+grandchildren.
   // I can't hold all that in the storage at the same time.
   // So some mechanism is necessary to minimize storage consumption.
   // root --> root-Pages [kids, count of ALL kids in this branch] 
   //           --> Pages [Parent, kids, count]
   // ---------------------------------------------------------------------
   // Calculate the maximum depth of the page tree with the number of pages
   // and the number of kids per Pages object.
   h_PageDepthMax  = 0;
   h_DepthMaxPages = 1;
   DOU h_DepthMaxPages > SplfAtr(1).Total_Pages;
      h_PageDepthMax  += 1;
      h_DepthMaxPages  = h_DepthMaxPages * PAGE_PER_PAGES;
   ENDDO;



   // root object
   i_Root    = RPDFG_newObject();
   RPDFG_addDictEntry(i_Root:'Type':'Catalog');
   pdfObjRef_Root = RPDFG_ref(i_Root);

   // Pages object
   i_Pages   = RPDFG_newObject();
   RPDFG_addDictEntry(i_Pages:'Type':'Pages');
   // put this in the tree
   h_PageDepth(1).count  = 1;
   h_PageDepth(1).objIdx = i_Pages;
   // add the reference to the Pages object to the root object
   RPDFG_addDictEntry(i_Root:'Pages' :RPDFG_ref(i_Pages));

   // "Root" is now ready and can be written; Object Index will be re-used for antoher object
   RPDFG_serializeObject(i_Root);

   // Font object
   i_Font    = RPDFG_newObject();
   RPDFG_addDictEntry(i_Font:'Type'    :'Font');
   RPDFG_addDictEntry(i_Font:'Subtype' :'/Type1');
   RPDFG_addDictEntry(i_Font:'BaseFont':'/Courier');
   // remember the reference to the font object in the PDF file
   pdfObjRef_Font = RPDFG_ref(i_Font);
   // Font is ready
   RPDFG_serializeObject(i_Font);

   // -------------------------------------------------------
   // create reusable h_Resources_string for the Page object
   // -------------------------------------------------------
   // Page - Font - F1 dictionary
   i_F1 = RPDFG_newObject(RPDFG_SPECIAL_OBJECT.INTERNAL);
   RPDFG_addDictEntry(i_F1:'F1':pdfObjRef_Font);
   // Page - Font dictionary
   h_Font = RPDFG_newObject(RPDFG_SPECIAL_OBJECT.INTERNAL);
   RPDFG_addDictEntry(h_Font:'Font':RPDFG_serializeDict(RPDFG_getObjDictIdx(i_F1)));
   h_Resources_string = RPDFG_serializeDict(RPDFG_getObjDictIdx(h_Font));
   // The dictionaries of F1 and h_Font are now gone, so the objects have to be deleted, too!!!
   RPDFG_deleteObject(i_F1);
   RPDFG_deleteObject(h_Font);
   // -------------------------------------------------------
   // This one is needed for every page, so we create it once and reuse the string
   h_MediaBox_string = RPDFG_getMediaBoxString();
   // --------------------------------------------------------------------------
   // check the tree depth and create new "Pages" objects
   FOR #d = 2 TO h_PageDepthMax - 1;
      IF h_PageDepth(#d).count < 1;
         h_PageDepth(#d).count += 1;
         h_PageDepth(#d).objIdx = RPDFG_newObject();
         RPDFG_addDictEntry(h_PageDepth(#d).objIdx:'Type':'Pages');
         // connect the new "Pages" object to it's parent in the tree
         RPDFG_addDictEntry(h_PageDepth(#d).objIdx:'Parent' :RPDFG_ref(h_PageDepth(#d-1).objIdx));
      ENDIF;
   ENDFOR;
   // --------------------------------------------------------------------------


   // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   DOU 'all' = 'data read';

      EXEC SQL FETCH C2 INTO :SplDta;
      IF SQLCOD <> SQL_OK;
         LEAVE;
      ENDIF;

      IF SplDta.FCFC = FCFC.CHANNEL01;

         IF PageCount > 0;
            RPDFG_serializeObject(i_Page);
            RPDFG_serializeObject(i_Contents);
         ENDIF;

         PageCount += 1;

         // check if the current "Pages" tree has place for another "Page" object,
         // otherwise create a new "Pages" object and so on
         FOR #d = 2 TO h_PageDepthMax - 1;
            IF RPDFG_getNumberOfKids(h_PageDepth(#d).objIdx) = PAGES_PER_PAGES;
               // full, write it
               RPDFG_serializeObject(h_PageDepth(#d).objIdx);
               // we need a new one
               h_PageDepth(#d).objIdx = RPDFG_newObject();
               RPDFG_setRelation(h_PageDepth(#d-1).objIdx:
                                 h_PageDepth(#d).objIdx);
            ENDIF;
         ENDFOR;

         IF h_PageDepthMax > 1;
            // the current Pages object is the one on the max depth level - 1
            i_Pages = h_PageDepth(h_PageDepthMax-1).objIdx;
         ELSE;
            // There is only 1 level when the number of total pages < PAGE_PER_PAGES
            i_Pages = h_PageDepth(1).objIdx;
         ENDIF;
         // but is there place for another "Page" object?
         IF RPDFG_getNumberOfKids(i_Pages) = PAGE_PER_PAGES;
            // full, write it
            RPDFG_serializeObject(i_Pages);
            // we need a new one
            i_Pages = RPDFG_newObject();
            h_PageDepth(#d).objIdx = i_Pages;
         ENDIF;

         // create Page object
         i_Page = RPDFG_newObject();
         RPDFG_addDictEntry(i_Page:'Type':'Page');
         // add the Page object ref to the current Pages object
         // RPDFG_addObjKidRef(i_Pages:i_Page);
         // RPDFG_g_obj(i_Pages).NbrOfKids += 1;
         // RPDFG_g_obj(i_Pages).Kids(RPDFG_g_obj(i_Pages).NbrOfKids) = i_Page;
         // // the parent of the "Page" is the current "Pages" object
         // RPDFG_addDictEntry(i_Page:'Parent':RPDFG_ref(i_Pages));
         RPDFG_setRelation(i_Pages:i_Page);
         RPDFG_addDictEntry(i_Page:'Resources':h_Resources_string);
         RPDFG_addDictEntry(i_Page:'MediaBox':h_MediaBox_string);
         // RPDFG_addDictEntry(i_Page:'Rotate':%CHAR(RPDFG_getRotate()));

         h_LineNumber = 0;

         i_Contents = RPDFG_newObject(RPDFG_SPECIAL_OBJECT.CONTENTS);
         RPDFG_addDictEntry(i_Page:'Contents':RPDFG_ref(i_Contents));

         // RPDFG_startStream();

      ENDIF; // new page
      // --------------------------------------------------


      // RPDFG_calcLinePos(h_LineNumber:1:h_PosX:h_PosY);

      // RPDFG_addToStream(PDF_TEXTBLOCK_BEGIN + CCSID_HEX.EOL +
      //          '/F1 ' + %CHAR(g_PDF.FontSize) + PDF_TEXT_FONT_RESSOURCE + CCSID_HEX.EOL +
      //          %CHAR(h_PosX) + ' ' + %CHAR(h_PosY) + ' Td' + CCSID_HEX.EOL +
      //          '(' + %TRIMR(SplDta.LINE) + ') Tj' + CCSID_HEX.EOL +
      //          PDF_TEXTBLOCK_END + CCSID_HEX.EOL);

      SELECT;
         WHEN SplDta.FCFC = FCFC.SUPPRESS;
            // do nothing, stay on the same line
         WHEN SplDta.FCFC = FCFC.SPACE2;
            h_LineNumber += 2;
         WHEN SplDta.FCFC = FCFC.SPACE3;
            h_LineNumber += 3;
         OTHER;
            h_LineNumber += 1;
      ENDSL;

      // we do not need to write empty lines
      IF %TRIMR(SplDta.LINE) <> '';
         RPDFG_addToStreamTextBlock1252(h_LineNumber:
                                        1:
                                        SplDta.LINE);
         // RPDFG_addToStreamTextBlock(h_LineNumber:
         //                            1:
         //                            SplDta.LINE);
         // no idea why this won't work
         // RPDFG_addToStreamTextBlockUcs2(h_LineNumber:
         //                                1:
         //                                SplDta.LINE);
      ENDIF;


   ENDDO; // read all spooled file lines

   // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

   EXEC SQL CLOSE C2;

   RPDFG_serializeObject(i_Page);
   RPDFG_serializeObject(i_Contents);

   // "Info" object
   i_Info = RPDFG_newObject();
   RPDFG_addDictEntry(i_Info:
                      'Author':'(' + SplfAtr(1).UserName + ')');
   RPDFG_addDictEntry(i_Info:
                      'CreationDate':'(D:' + %CHAR(SplfAtr(1).CreateTimestamp:*ISO0) + 
                      '+00''00''' +
                      ')');
   RPDFG_addDictEntry(i_Info:'Creator':
                      '(RPDFGCVT https://ag1965.github.com/RPDFG)');
   RPDFG_addDictEntry(i_Info:'Producer':
                      '(RPDFG Compiled (D:' + PSDS.CompileUDate + PSDS.CompileTime + ') IBMi)');
   // /Title (No Title)
   // /Subject (None)
   // /Keywords (ClibPDF)
   pdfObjRef_Info = RPDFG_ref(i_Info);
   RPDFG_serializeObject(i_Info);

   // write all remaining objects (e.g. Pages objects that are not full and therefore not written yet)
   RPDFG_serializeUnwrittenObjects();

   // xref
   i_Xref = RPDFG_newObject(RPDFG_SPECIAL_OBJECT.XREF);
   RPDFG_serializeObject(i_Xref);

   // trailer
   i_Trailer = RPDFG_newObject(RPDFG_SPECIAL_OBJECT.TRAILER);
   RPDFG_addDictEntry(i_Trailer:'Size':%CHAR(RPDFG_getTotalNumberOfObjects() + 1));
   RPDFG_addDictEntry(i_Trailer:'Root':pdfObjRef_Root);
   RPDFG_addDictEntry(i_Trailer:'Info':pdfObjRef_Info);
   RPDFG_serializeObject(i_Trailer);

   // startxref + close PDF file
   RPDFG_closePdfFile();

End-Proc;
