**FREE
CTL-OPT NOMAIN
        OPTION(*NODEBUGIO:*SRCSTMT:*NOUNREF)
        DATEDIT(*YMD) CCSID(*EXACT) CCSIDCVT(*LIST:*EXCP)
        TEXT('RPDFG - Functions to create a pdf file');
// -----------------------------------------------------------------------------
// RPDFG - Functions to create a pdf file
// https://ag1965.github.io/RPDFG/
// -----------------------------------------------------------------------------

// as i'm using pointers to these, i can't define this DS as CONST. :-(
Dcl-DS  PDF QUALIFIED;
   HEADER                CHAR( 8) INZ('%PDF-1.4');
   OBJ_STR               CHAR( 3) INZ('obj');
   OBJ_END               CHAR( 6) INZ('endobj');
   STREAM_STR            CHAR( 6) INZ('stream');
   STREAM_END            CHAR( 9) INZ('endstream');
   ARRAY_STR             CHAR( 1) INZ('[');
   ARRAY_END             CHAR( 1) INZ(']');
   DICTIONARY_STR        CHAR( 2) INZ('<<');
   DICTIONARY_END        CHAR( 3) INZ(' >>');
   TEXTBLOCK_BEGIN       CHAR( 2) INZ('BT');
   TEXTBLOCK_END         CHAR( 2) INZ('ET');
   FONT_SELECT_NUMBER    CHAR( 1) INZ('F');
   TEXT_FONT_RESSOURCE   CHAR( 2) INZ('Tf');
   MATRIX_SCALE_1_1      CHAR( 8) INZ('1 0 0 1 ');
   TEXT_MATRIX           CHAR( 2) INZ('Tm');
   TEXT_DRAW             CHAR( 2) INZ('Tj');
   XREF                  CHAR( 4) INZ('xref');
   TRAILER               CHAR( 7) INZ('trailer');
   STARTXREF             CHAR( 9) INZ('startxref');
   EOF                   CHAR( 5) INZ('%%EOF');
End-DS;



Dcl-DS CCSID_JOBRUN CONST QUALIFIED;
   SLASH          CHAR(1) INZ('/') CCSID(*JOBRUN);
   COLON          CHAR(1) INZ(':') CCSID(*JOBRUN);
   UNDERLINE      CHAR(1) INZ('_') CCSID(*JOBRUN);
   BACKSLASH      CHAR(1) INZ('\') CCSID(*JOBRUN);
   BRACKET_OPEN   CHAR(1) INZ('(') CCSID(*JOBRUN);
   BRACKET_CLOSE  CHAR(1) INZ(')') CCSID(*JOBRUN);
End-DS;

Dcl-DS CCSID_UCS2 CONST QUALIFIED;
   SLASH          UCS2(1) INZ('/');
   COLON          UCS2(1) INZ(':');
   UNDERLINE      UCS2(1) INZ('_');
   BACKSLASH      UCS2(1) INZ('\');
   BRACKET_OPEN   UCS2(1) INZ('(');
   BRACKET_CLOSE  UCS2(1) INZ(')');
End-DS;

Dcl-DS CCSID_HEX    CONST QUALIFIED;
   EOL            CHAR(2) INZ(x'0D0A')           CCSID(*HEX);
   HEADER_LINE2   CHAR(7) INZ(x'25FFFFFFFF0D0A') CCSID(*HEX);
End-DS;

Dcl-C  ADD_EOL  'EOL';

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


// max. number of "Pages" objects in the "Pages" tree
Dcl-C  PAGES_PER_PAGES        5;
// max. number of "Page" objects in a "Pages" object
Dcl-C  PAGE_PER_PAGES         5;

Dcl-C  SQL_OK                 0;
Dcl-C  SQL_ERROR_NOTFOUND     100;

Dcl-C  SPLFNBR_ONLY_NUM       0;
Dcl-C  SPLFNBR_LAST_NUM       -1;

Dcl-C  MM_IN_1_INCH      25.4000;
Dcl-C  POINTS_IN_1_INCH  72.0000;
Dcl-C  BORDER_IN_POINTS  14.1732; // 5mm in points (1/72 inch)

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
// global fields
// objects - this is a reusable pool
Dcl-DS RPDFG_g_obj     LIKEDS(RPDFG_obj_T) DIM(100) INZ(*LIKEDS);
Dcl-S  RPDFG_g_objIdx  LIKE(RPDFG_objIdx_T) Inz(0);
// objects might contain dictionaries, this is a reusable pool
Dcl-DS RPDFG_g_dict    LIKEDS(RPDFG_dict_T) DIM(100) INZ(*LIKEDS);
Dcl-S  RPDFG_g_dictIdx LIKE(RPDFG_dictIdx_T) Inz(0);

Dcl-DS g_PDF QUALIFIED;
   // physical size pf the paper = MediaBox in PDF
   PaperHeight  PACKED(8:3) INZ(0);
   PaperWidth   PACKED(8:3) INZ(0);
   // margins (5mm)
   MarginTop    PACKED(8:3) INZ(0);
   MarginBottom PACKED(8:3) INZ(0);
   MarginLeft   PACKED(8:3) INZ(0);
   MarginRight  PACKED(8:3) INZ(0);
   // size of the printable area = CropBox in PDF
   PageHeight   PACKED(8:3) INZ(0);
   PageWidth    PACKED(8:3) INZ(0);
   LPI          PACKED(8:3) INZ(0);
   CPI          PACKED(8:3) INZ(0);
   FontSize     PACKED(8:3) INZ(0);

   objNumberForPDF    INT(10) INZ(0); // counts up with newObject

   PDF_FileName   VARCHAR(257) INZ('');
   Ifs_handle        LIKE(IFS_Open) INZ(-1);
   Ifs_byteCount      INT(10) INZ(0);

   PageStream     VARCHAR(64000:4) CCSID(*HEX);

   Rotate          INT(5) INZ(0);
   
   startxref       INT(10) INZ(0);
   xrefByteOffset  INT(10) INZ(0) DIM(100000);

End-DS;



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

// -----------------------------------------------------------------------------
// new Object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_newObject EXPORT;
   Dcl-PI *N LIKE(rtn_objIdx);
      p_specialMode  CHAR(1) CONST OPTIONS(*NOPASS);
   End-PI;

   Dcl-S rtn_objIdx     LIKE(RPDFG_objIdx_T) INZ(0);
   Dcl-S h_SpecialMode  LIKE(p_specialMode)  INZ(' ');

   Dcl-S #i             LIKE(RPDFG_objIdx_T);

   // --------------------------------------------------------------------------
   IF %PASSED(p_specialMode);
      h_SpecialMode = p_specialMode;
   ENDIF;

   FOR #i = 1 to RPDFG_g_objIdx;
      IF NOT RPDFG_g_obj(#i).inUse;
         rtn_objIdx = #i;
         LEAVE;
      ENDIF;
   ENDFOR;

   IF rtn_objIdx = 0;
      IF RPDFG_g_objIdx = %ELEM(RPDFG_g_obj);
         // RPDF0003 "Max number of objects reached"
         RPDF000n.idx    = 0;
         RPDF000n.maxIdx = %ELEM(RPDFG_g_obj);
         SND-MSG *ESCAPE %MSG(MSGID.RPDF003:RPDFGMSGF:RPDF000n)
                         %TARGET(*CTLBDY:1);
      ENDIF;
      RPDFG_g_objIdx += 1;
      rtn_objIdx = RPDFG_g_objIdx;
   ENDIF;

   RESET RPDFG_g_obj(rtn_objIdx);
   RPDFG_g_obj(rtn_objIdx).inUse = *ON;
   RPDFG_g_obj(rtn_objIdx).SpecialMode = h_SpecialMode;
   IF h_SpecialMode = *BLANK OR
      h_SpecialMode = RPDFG_SPECIAL_OBJECT.CONTENTS;
      g_PDF.objNumberForPDF += 1;
      RPDFG_g_obj(rtn_objIdx).objNumberForPDF = g_PDF.objNumberForPDF;
   ENDIF;

   RETURN rtn_objIdx;

End-Proc;

// -----------------------------------------------------------------------------
// new dictionary
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_newDictionary EXPORT;
   Dcl-Pi *N LIKE(rtn_dictIdx);
   End-Pi;

   Dcl-S rtn_dictIdx  LIKE(RPDFG_objIdx_T) INZ(0);

   Dcl-S #i  LIKE(RPDFG_objIdx_T);

   FOR #i = 1 to RPDFG_g_dictIdx;
      IF NOT RPDFG_g_dict(#i).inUse;
         rtn_dictIdx = #i;
         LEAVE;
      ENDIF;
   ENDFOR;

   IF rtn_dictIdx = 0;
      IF RPDFG_g_dictIdx = %ELEM(RPDFG_g_dict);
         // RPDF0004 "Max number of Dictionaries reached"
         RPDF000n.idx    = 0;
         RPDF000n.maxIdx = %ELEM(RPDFG_g_dict);
         SND-MSG *ESCAPE %MSG(MSGID.RPDF004:RPDFGMSGF:RPDF000n)
                           %TARGET(*CTLBDY:1);
      ENDIF;
      RPDFG_g_dictIdx += 1;
      rtn_dictIdx = RPDFG_g_dictIdx;
   ENDIF;

   RESET RPDFG_g_dict(rtn_dictIdx);
   RPDFG_g_dict(rtn_dictIdx).inUse = *ON;

   RETURN rtn_dictIdx;

End-Proc;

// -----------------------------------------------------------------------------
// retrieve a pointer to an object array entry
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_rtvPtrObj EXPORT;
   Dcl-PI *N LIKE(rtn_Pointer);
      p_objIdx    INT(10) CONST;
   End-PI;

   Dcl-S rtn_Pointer  POINTER;

   rtn_Pointer = %ADDR(RPDFG_g_obj(p_objIdx));

   RETURN rtn_Pointer;

End-Proc;

// -----------------------------------------------------------------------------
// retrieve a pointer to an dictionary array entry
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_rtvPtrDict EXPORT;
   Dcl-Pi *N LIKE(rtn_Pointer);
      p_dictIdx    INT(10) CONST;
   End-Pi;

   Dcl-S rtn_Pointer  POINTER;

   rtn_Pointer =  %ADDR(RPDFG_g_dict(p_dictIdx));

   RETURN rtn_Pointer;

End-Proc;

// -----------------------------------------------------------------------------
// retrieve a reference to an object number for PDF output
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_ref EXPORT;
   Dcl-Pi *N LIKE(rtn_string);
      p_objIdx    INT(10) CONST;
   End-Pi;

   Dcl-S rtn_objNumberForPDF INT(10) INZ(0);
   Dcl-S rtn_string          VARCHAR(32);

   rtn_objNumberForPDF = RPDFG_g_obj(p_objIdx).objNumberForPDF;
   rtn_string = %CHAR(rtn_objNumberForPDF) + ' 0 R';

   RETURN rtn_string;

End-Proc;

// -----------------------------------------------------------------------------
// get the dictionary index of an object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_getObjDictIdx  EXPORT;
   Dcl-Pi *N LIKE(rtn_dictIdx);
      p_objIdx    INT(10) CONST;
   End-Pi;
   Dcl-S  rtn_dictIdx    INT(10);

   rtn_dictIdx = RPDFG_g_obj(p_objIdx).dictIdx;

   RETURN rtn_dictIdx;

End-Proc;

// -----------------------------------------------------------------------------
// get the number of kids of an object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_getNumberOfKids  EXPORT;
   Dcl-Pi *N LIKE(rtn_NumberOfKids);
      p_objIdx    LIKE(RPDFG_objIdx_T) CONST;
   End-Pi;
   Dcl-S  rtn_NumberOfKids   INT(10);

   rtn_NumberOfKids = RPDFG_g_obj(p_objIdx).NbrOfKids;

   RETURN rtn_NumberOfKids;

End-Proc;

// -----------------------------------------------------------------------------
// get the total number of objects
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_getTotalNumberOfObjects  EXPORT;
   Dcl-Pi *N LIKE(rtn_NumberOfObjects);
   End-Pi;
   Dcl-S  rtn_NumberOfObjects   INT(10);

   rtn_NumberOfObjects = g_PDF.objNumberForPDF;

   RETURN rtn_NumberOfObjects;

End-Proc;

// -----------------------------------------------------------------------------
// set the parent:kids relations in the Pages tree
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_setRelation  EXPORT;
   Dcl-Pi *n;
      p_parentObjIdx    LIKE(RPDFG_objIdx_T) CONST;
      p_kidObjIdx       LIKE(RPDFG_objIdx_T) CONST;
   End-Pi;

   Dcl-DS myParent      LIKEDS(RPDFG_obj_T) BASED(Ptr_myParent);
   Dcl-S  Ptr_myParent  POINTER;
   Dcl-DS myKid         LIKEDS(RPDFG_obj_T) BASED(Ptr_myKid);
   Dcl-S  Ptr_myKid     POINTER;

   Dcl-S  #i         INT(10);

   Ptr_myParent = RPDFG_rtvPtrObj(p_parentObjIdx);
   Ptr_myKid    = RPDFG_rtvPtrObj(p_kidObjIdx);

   IF myParent.NbrOfKids = %ELEM(myParent.Kids);
      // RPDF0009 "Could not add kid "&3" to object #"&1"; maximum number of entries &2 reached."
      RPDF000n.idx    = p_parentObjIdx;
      RPDF000n.maxIdx = %ELEM(myParent.Kids);
      RPDF000n.key    = RPDFG_ref(p_kidObjIdx);
      SND-MSG *ESCAPE %MSG(MSGID.RPDF009:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   myParent.NbrOfKids += 1;
   myParent.Kids(myParent.NbrOfKids) = RPDFG_ref(p_kidObjIdx);
   myKid.Parent = RPDFG_ref(p_parentObjIdx);

End-Proc;

// -----------------------------------------------------------------------------
// add an entry to a dictionary (and link the dictionary to the object)
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_addDictEntry  EXPORT;
   Dcl-Pi *n;
      p_objIdx    INT(10) CONST;
      p_Key       VARCHAR(  16) CONST;
      p_Value     VARCHAR(1024) CONST;
   End-Pi;

   Dcl-S  myDictIdx  INT(10);

   Dcl-DS myObj      LIKEDS(RPDFG_obj_T) BASED(Ptr_myObj);
   Dcl-S  Ptr_myObj  POINTER;

   Dcl-DS myDict     LIKEDS(RPDFG_dict_T) BASED(Ptr_myDict);
   Dcl-S  Ptr_myDict POINTER;

   Dcl-S  #i         INT(10);

   Dcl-C  NONE       -1;

   Ptr_myObj = RPDFG_rtvPtrObj(p_objIdx);
   IF myObj.dictIdx = NONE;
      // object has no dictionary yet, create one and link it to the object
      myDictIdx = RPDFG_newDictionary();
      myObj.dictIdx = myDictIdx;
   ELSE;
      myDictIdx = myObj.dictIdx;
   ENDIF;

   Ptr_myDict = RPDFG_rtvPtrDict(myDictIdx);

   #i = %lookup(p_Key:myDict.DictKeys:1:myDict.NbrOfDictEntries);
   IF #i <> 0;
      // RPDF0005 "Dictionary entry already exists"
      RPDF000n.idx    = myDictIdx;
      RPDF000n.maxIdx = 0;
      RPDF000n.key    = p_Key;
      RPDF000n.value1 = p_Value;
      RPDF000n.value2 = myDict.DictValues(#i);
      SND-MSG *ESCAPE %MSG(MSGID.RPDF005:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   IF myDict.NbrOfDictEntries = %ELEM(myDict.DictKeys);
      // RPDF0006 "Dictionary full"
      RPDF000n.idx    = myDictIdx;
      RPDF000n.maxIdx = %ELEM(myDict.DictKeys);
      RPDF000n.key    = p_Key;
      RPDF000n.value1 = p_Value;
      SND-MSG *ESCAPE %MSG(MSGID.RPDF006:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   myDict.NbrOfDictEntries += 1;
   #i = myDict.NbrOfDictEntries;

   myDict.DictKeys(#i)   = p_Key;
   myDict.DictValues(#i) = p_Value;

End-Proc;

// -----------------------------------------------------------------------------
// Serialize an object as a string
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_serializeObject  EXPORT;
   Dcl-Pi *N;
      p_objIdx        INT(10)   CONST;
   End-Pi;

   Dcl-DS myObj       LIKEDS(RPDFG_obj_T) BASED(Ptr_myObj);
   Dcl-S Ptr_myObj    POINTER;

   Dcl-S #i               INT(10);
   Dcl-S myBuffer     VARCHAR(100000) CCSID(*HEX);
   Dcl-S h_Buffer     VARCHAR(100000) CCSID(*UTF8);

   Dcl-S h_string     VARCHAR(100)  INZ('') CCSID(*UTF8);
   Dcl-S h_kidsString VARCHAR(1000) INZ('');

   Dcl-S h_ContentsLength INT(10) INZ(0);

   Dcl-C XREF_FIRST_OBJECT_NUMBER  '0';
   Dcl-C XREF_OBJECT_0             '0000000000 65535 f';

   Dcl-DS h_XREF_Template QUALIFIED;
      offset          ZONED(10:0);
      spacer1         CHAR(1) INZ(' ');
      generation      CHAR(5) INZ('00000');
      spacer2         CHAR(1) INZ(' ');
      inUse           CHAR(1) INZ('n');
   End-DS;

   // --------------------------------------------------------------

   IF p_objIdx < 1 OR p_objIdx > RPDFG_g_objIdx;
      // RPDF0007 "Invalid &3 index "&1". (Must be between 1 and &2.)"
      RPDF000n.idx    = p_objIdx;
      RPDF000n.maxIdx = RPDFG_g_objIdx;
      RPDF000n.key    = 'object';
      SND-MSG *ESCAPE %MSG(MSGID.RPDF007:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   Ptr_myObj = RPDFG_rtvPtrObj(p_objIdx);

   IF NOT myObj.inUse;
      // RPDF0008 "Invalid &3 index "&1", &3 is not in use."
      RPDF000n.idx    = p_objIdx;
      RPDF000n.key    = 'object';
      SND-MSG *ESCAPE %MSG(MSGID.RPDF008:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   // special objects have no object number for PDF output
   IF myObj.objNumberForPDF > 0;
      g_PDF.xrefByteOffset(myObj.objNumberForPDF) = g_PDF.Ifs_byteCount;
   ENDIF;
   // ---------------------------------------------------
   %LEN(myBuffer) = 0;
   SELECT;
      WHEN myObj.SpecialMode = RPDFG_SPECIAL_OBJECT.XREF;
         g_PDF.startxref = g_PDF.Ifs_byteCount;
         // write the xref table
         h_Buffer = PDF.XREF;
         RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);
         h_Buffer = XREF_FIRST_OBJECT_NUMBER + ' ' + %CHAR(g_PDF.objNumberForPDF + 1);
         RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);
         h_Buffer = XREF_OBJECT_0;
         RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);

         FOR #i = 1 TO g_PDF.objNumberForPDF;
            h_XREF_Template.offset = g_PDF.xrefByteOffset(#i);
            h_Buffer = h_XREF_Template;
            RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);
         ENDFOR;
         // ---------------------------------------------------
      OTHER;

         IF myObj.objNumberForPDF > 0;
            h_Buffer = %CHAR(myObj.objNumberForPDF) + ' 0 ' + PDF.OBJ_STR;
         ENDIF;
         IF myObj.SpecialMode = RPDFG_SPECIAL_OBJECT.TRAILER;
            h_Buffer = PDF.TRAILER;
            RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);
            h_Buffer = '';
         ENDIF;

         IF myObj.NbrOfKids > 0;
            h_kidsString = PDF.ARRAY_STR + ' ';
            FOR #i = 1 TO myObj.NbrOfKids;
               h_kidsString += myObj.Kids(#i) + ' ';
            ENDFOR;
            h_kidsString += PDF.ARRAY_END;
            RPDFG_addDictEntry(p_objIdx:'Kids':h_kidsString);
            RPDFG_addDictEntry(p_objIdx:'Count':%CHAR(myObj.NbrOfKids));
         ENDIF;

         IF myObj.Parent <> '';
            RPDFG_addDictEntry(p_objIdx:'Parent':myObj.Parent);
         ENDIF;

         IF myObj.SpecialMode = RPDFG_SPECIAL_OBJECT.CONTENTS;
            h_ContentsLength = %LEN(g_PDF.PageStream) - 
                               %LEN(PDF.STREAM_STR) - 
                               %LEN(CCSID_HEX.EOL);
            RPDFG_addDictEntry(p_objIdx:'Length':%CHAR(h_ContentsLength));
         ENDIF;

         IF myObj.dictIdx > 0;
            IF %LEN(h_Buffer) > 0;
               h_Buffer += ' ';
            ENDIF;
            h_Buffer += RPDFG_serializeDict(myObj.dictIdx);
         ENDIF;

         IF myObj.SpecialMode = RPDFG_SPECIAL_OBJECT.CONTENTS;
            RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);
            h_Buffer = '';
            RPDFG_writeBuffer(%ADDR(myBuffer:*DATA):
                               %LEN(myBuffer));
            %LEN(myBuffer) = 0;
            RPDFG_endStream();
         ENDIF;

         IF myObj.objNumberForPDF > 0;
            h_Buffer += CCSID_HEX.EOL + PDF.OBJ_END;
         ENDIF;
         RPDFG_add(%ADDR(myBuffer):%ADDR(h_Buffer:*DATA):%LEN(h_Buffer):ADD_EOL);

   ENDSL;
   // ---------------------------------------------------

   RPDFG_writeBuffer(%ADDR(myBuffer:*DATA):
                     %LEN(myBuffer));

   myObj.inUse = *OFF; // mark as not in use after writing to file

   RETURN;

End-Proc;
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Delete an object (mark as not in use)
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_deleteObject  EXPORT;
   Dcl-Pi *N;
      p_objIdx        INT(10)   CONST;
   End-Pi;

   Dcl-DS myObj       LIKEDS(RPDFG_obj_T) BASED(Ptr_myObj);
   Dcl-S Ptr_myObj    POINTER;

   // --------------------------------------------------------------

   IF p_objIdx < 1 OR p_objIdx > RPDFG_g_objIdx;
      // RPDF0007 "Invalid &3 index "&1". (Must be between 1 and &2.)"
      RPDF000n.idx    = p_objIdx;
      RPDF000n.maxIdx = RPDFG_g_objIdx;
      RPDF000n.key    = 'object';
      SND-MSG *ESCAPE %MSG(MSGID.RPDF007:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   Ptr_myObj = RPDFG_rtvPtrObj(p_objIdx);

   myObj.inUse = *OFF;

   RETURN;

End-Proc;


// -----------------------------------------------------------------------------
// Serialize a dictionary as a string
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_serializeDict   EXPORT;
   Dcl-Pi *N LIKE(rtn_string) RTNPARM;
      p_dictIdx       INT(10)   CONST;
   End-Pi;

   Dcl-S rtn_string VARCHAR(32000) INZ('') CCSID(*UTF8);

   Dcl-DS myDict      LIKEDS(RPDFG_dict_T) BASED(Ptr_myDict);
   Dcl-S  Ptr_myDict  POINTER;

   Dcl-S  #i         INT(10);


   IF p_dictIdx < 1 OR p_dictIdx > RPDFG_g_dictIdx;
      // RPDF0007 "Invalid &3 index "&1". (Must be between 1 and &2.)"
      RPDF000n.idx    = p_dictIdx;
      RPDF000n.maxIdx = RPDFG_g_dictIdx;
      RPDF000n.key    = 'dictionary';
      SND-MSG *ESCAPE %MSG(MSGID.RPDF007:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   Ptr_myDict = RPDFG_rtvPtrDict(p_dictIdx);

   IF NOT myDict.inUse;
      // RPDF0008 "Invalid &3 index "&1", &3 is not in use."
      RPDF000n.idx    = p_dictIdx;
      RPDF000n.key    = 'dictionary';
      SND-MSG *ESCAPE %MSG(MSGID.RPDF008:RPDFGMSGF:RPDF000n)
                        %TARGET(*CTLBDY:1);
   ENDIF;

   rtn_string = PDF.DICTIONARY_STR;

   FOR #i = 1 TO myDict.NbrOfDictEntries;
      rtn_string += ' /' + myDict.DictKeys(#i) + ' ' + myDict.DictValues(#i);
   ENDFOR;

   rtn_string += PDF.DICTIONARY_END;

   myDict.inUse = *OFF; // mark as not in use after serializing

   RETURN rtn_string;

End-Proc;
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Set paper formats
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_initPaperFormat  EXPORT;
   Dcl-PI *n;
      p_PaperFormat     VARCHAR(20) CONST;
      p_MarginLeftPts    PACKED(8:3) CONST;
      p_MarginTopPts     PACKED(8:3) CONST;
      p_MarginRightPts   PACKED(8:3) CONST;
      p_MarginBottomPts  PACKED(8:3) CONST;
   End-PI;

   Dcl-ENum PAPERFORMAT QUALIFIED;
      A3             'A3';
      A4             'A4';
      A5             'A5';
      US_INVOICE     'US_INVOICE';
      US_EXECUTIVE   'US_EXECUTIVE';
      US_LEGAL       'US_LEGAL';
      US_LETTER      'US_LETTER';
      US_LEDGER      'US_LEDGER';
   End-ENum;
   // all of these measures are in portrait orientation.

   RESET g_PDF;
   %LEN(g_PDF.PageStream) = 0;

   SELECT;
      WHEN p_PaperFormat   = PAPERFORMAT.A3;
         g_PDF.PaperHeight = 420.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216
         g_PDF.PaperWidth  = 297.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216

      WHEN p_PaperFormat   = PAPERFORMAT.A4;
         g_PDF.PaperHeight = 297.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216
         g_PDF.PaperWidth  = 210.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216

      WHEN p_PaperFormat   = PAPERFORMAT.A5;
         g_PDF.PaperHeight = 210.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216
         g_PDF.PaperWidth  = 148.0000 / MM_IN_1_INCH * POINTS_IN_1_INCH; // mm according to ISO 216

      WHEN p_PaperFormat   = PAPERFORMAT.US_INVOICE;
         g_PDF.PaperHeight =   8.5000 * POINTS_IN_1_INCH; // inch
         g_PDF.PaperWidth  =   5.5000 * POINTS_IN_1_INCH; // inch

      WHEN p_PaperFormat   = PAPERFORMAT.US_EXECUTIVE;
         g_PDF.PaperHeight =  10.5000 * POINTS_IN_1_INCH; // inch
         g_PDF.PaperWidth  =   7.2500 * POINTS_IN_1_INCH; // inch

      WHEN p_PaperFormat   = PAPERFORMAT.US_LEGAL;
         g_PDF.PaperHeight =  14.0000 * POINTS_IN_1_INCH; // inch
         g_PDF.PaperWidth  =   8.5000 * POINTS_IN_1_INCH; // inch

      WHEN p_PaperFormat   = PAPERFORMAT.US_LETTER; // ANSI A
         g_PDF.PaperHeight =  11.0000 * POINTS_IN_1_INCH; // inch
         g_PDF.PaperWidth  =   8.5000 * POINTS_IN_1_INCH; // inch

      WHEN p_PaperFormat   = PAPERFORMAT.US_LEDGER; // ANSI B
         g_PDF.PaperHeight =  17.0000 * POINTS_IN_1_INCH; // inch
         g_PDF.PaperWidth  =  11.0000 * POINTS_IN_1_INCH; // inch

      OTHER;
         // TODO: Error message "Unknown paper format"
   ENDSL;

   RPDFG_g_objIdx  = 0;
   RPDFG_g_dictIdx = 0;

   // g_PDF.MarginLeft   = 14.1732; // 5mm in 1/72 inch
   g_PDF.MarginLeft   = p_MarginLeftPts;
   // g_PDF.MarginTop    = 14.1732; // 5mm in 1/72 inch
   g_PDF.MarginTop    = p_MarginTopPts;
   // g_PDF.MarginRight  = 14.1732; // 5mm in 1/72 inch
   g_PDF.MarginRight  = p_MarginRightPts;
   // g_PDF.MarginBottom = 14.1732; // 5mm in 1/72 inch
   g_PDF.MarginBottom = p_MarginBottomPts;

End-Proc;



// -----------------------------------------------------------------------------
// Calculate page dimensions, LPI, CPI
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_calculatePrintingValues  EXPORT;
   Dcl-PI *n;
      p_Page_Rotation     VARCHAR( 5)   CONST;
      p_Page_Length           INT(10)   CONST;
      p_Page_Width            INT(10)   CONST;
   End-PI;

   Dcl-ENum ORIENTATION QUALIFIED;
      L 'L';
      P 'P';
   End-Enum;

   Dcl-S h_FontSize_A  PACKED(8:3);
   Dcl-S h_FontSize_B  PACKED(8:3);

   Dcl-S h_Orientation CHAR(1);

   SELECT;
      WHEN p_Page_Rotation = PAGRTT.PORTRAIT;
         h_Orientation = ORIENTATION.P;
         g_PDF.Rotate = 0;
      WHEN p_Page_Rotation = PAGRTT.PORTRAIT_REVERSE;
         h_Orientation = ORIENTATION.P;
         g_PDF.Rotate = 180;
      WHEN p_Page_Rotation = PAGRTT.LANDSCAPE;
         h_Orientation = ORIENTATION.L;
         g_PDF.Rotate = 90;
      WHEN p_Page_Rotation = PAGRTT.LANDSCAPE_REVERSE;
         h_Orientation = ORIENTATION.L;
         g_PDF.Rotate = 270;
      OTHER;
         IF p_Page_Width > p_Page_Length;
            h_Orientation = ORIENTATION.L;
            g_PDF.Rotate = 90;
         ELSE;
            h_Orientation = ORIENTATION.P;
            g_PDF.Rotate = 0;
         ENDIF;
   ENDSL;

   IF h_Orientation = ORIENTATION.P;
      g_PDF.PageHeight = g_PDF.PaperHeight - g_PDF.MarginTop - g_PDF.MarginBottom;
      g_PDF.PageWidth  = g_PDF.PaperWidth  - g_PDF.MarginLeft - g_PDF.MarginRight;
   ELSE;
      g_PDF.PageHeight = g_PDF.PaperWidth  - g_PDF.MarginTop - g_PDF.MarginBottom;
      g_PDF.PageWidth  = g_PDF.PaperHeight - g_PDF.MarginLeft - g_PDF.MarginRight;
   ENDIF;

   g_PDF.LPI = g_PDF.PageHeight / p_Page_Length;
   g_PDF.CPI = g_PDF.PageWidth  / p_Page_Width;

   // the maximum font size is the lower number of
   // a) 75% of the lines per inch
   h_FontSize_A = g_PDF.LPI * 0.75;
   // b) the width of monospaced characters is aprox. 60% of the font-size
   h_FontSize_B = g_PDF.CPI / 0.6;

   IF h_FontSize_A < h_FontSize_B;
      g_PDF.FontSize = h_FontSize_A;
   ELSE;
      g_PDF.FontSize = h_FontSize_B;
   ENDIF;

End-Proc;

// -----------------------------------------------------------------------------
// return the MediaBox string for the PDF page dictionary
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_getMediaBoxString  EXPORT;
   Dcl-PI *N LIKE(rtn_MediaBox_string);
   End-PI;

   Dcl-S rtn_MediaBox_string VARCHAR(32) CCSID(*UTF8);

   IF g_PDF.Rotate = 90 OR g_PDF.Rotate = 270;
      rtn_MediaBox_string = PDF.ARRAY_STR +
                           '0 ' +
                           '0 ' +
                           %CHAR(g_PDF.PaperHeight) + ' ' +
                           %CHAR(g_PDF.PaperWidth) +
                           PDF.ARRAY_END;
   ELSE;
      rtn_MediaBox_string = PDF.ARRAY_STR +
                           '0 ' +
                           '0 ' +
                           %CHAR(g_PDF.PaperWidth) + ' ' +
                           %CHAR(g_PDF.PaperHeight) +
                           PDF.ARRAY_END;
   ENDIF;

   return rtn_MediaBox_string;

End-Proc;


// -----------------------------------------------------------------------------
// return the rotation
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_getRotate  EXPORT;
   Dcl-PI *N LIKE(rtn_rotate);
   End-PI;

   Dcl-S rtn_rotate LIKE(g_PDF.Rotate);

   rtn_rotate = g_PDF.Rotate;

   return rtn_rotate;

End-Proc;

// -----------------------------------------------------------------------------
// Calculate the position of the line
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_calcLinePos  EXPORT;
   Dcl-Pi *n;
      // line number of the SCS spooled file
      p_LineNbr      INT(10)   CONST;
      // character position (normally 1)
      p_CharPos      INT(10)   CONST;
      // returned position in points (1/72 inch) from the left edge of the page
      p_PosX         PACKED(8:3);
      // returned position in points (1/72 inch) from the bottom edge of the page
      p_PosY         PACKED(8:3);
   End-Pi;

   p_PosY = g_PDF.PageHeight - (p_LineNbr * g_PDF.LPI);
   p_PosX = g_PDF.MarginLeft + (p_CharPos - 1) * g_PDF.CPI;

End-Proc;
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// start the stream of a page object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_startStream  EXPORT;
   Dcl-Pi *n;
   End-PI;

   Dcl-S h_buffer VARCHAR(64) CCSID(*UTF8);

   %LEN(g_PDF.PageStream) = 0;
   h_buffer = PDF.STREAM_STR;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_buffer:*DATA):%LEN(h_buffer):ADD_EOL);

End-Proc;

// -----------------------------------------------------------------------------
// add something to the stream of a page object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_addToStream  EXPORT;
   Dcl-Pi *n;
      p_string        VARCHAR(1024)      CONST OPTIONS(*TRIM) CCSID(*UTF8);
   End-PI;

   Dcl-S h_string LIKE(p_string);

   h_string = p_string;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string):%LEN(h_string):ADD_EOL);

End-Proc;

// -----------------------------------------------------------------------------
// end the stream of a page object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_endStream  EXPORT;
   Dcl-Pi *n;
   End-PI;

   Dcl-S h_buffer VARCHAR(64) CCSID(*UTF8);

   h_buffer = PDF.STREAM_END;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_buffer:*DATA):%LEN(h_buffer));

   RPDFG_writeBuffer(%ADDR(g_PDF.PageStream:*DATA):%LEN(g_PDF.PageStream));

End-Proc;

// -----------------------------------------------------------------------------
// add a Textblock to the stream of a page object (UTF8)
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_addToStreamTextBlock  EXPORT;
   Dcl-Pi *n;
      // line number   (1 - 255)
      p_lineNumber       INT(10)        CONST;
      // column number (1 - 378)
      p_column           INT(10)        CONST;
      // line to write
      p_line2Write   VARCHAR(378)       CONST;
   End-PI;

   Dcl-S  h_line2Write      VARCHAR(1024);
   Dcl-S  h_line2WriteUTF8  VARCHAR(1024) CCSID(*UTF8);
   Dcl-S  h_string          VARCHAR(1024) CCSID(*UTF8);

   Dcl-S  h_PosX       PACKED(8:3);
   Dcl-S  h_PosY       PACKED(8:3);
   Dcl-S  h_FontNumber    INT(10) INZ(1);
   Dcl-S  h_FontSize   LIKE(g_PDF.FontSize);

   IF %LEN(g_PDF.PageStream) = 0;
      RPDFG_startStream();
   ENDIF;

   RPDFG_calcLinePos(p_LineNumber:p_column:h_PosX:h_PosY);

   h_FontSize = g_PDF.FontSize;

   // Escape special characters in the string
   h_line2Write = %TRIMR(p_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BACKSLASH    :
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BACKSLASH    :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BRACKET_OPEN :
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BRACKET_OPEN :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BRACKET_CLOSE:
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BRACKET_CLOSE:h_line2Write);

   h_line2WriteUTF8 = h_line2Write;

   // "/BT"
   h_string = PDF.TEXTBLOCK_BEGIN;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "/F1 10.0 Tf"
   h_string = '/' + PDF.FONT_SELECT_NUMBER + %CHAR(h_FontNumber) + ' ' +
                                             %CHAR(h_FontSize) + ' ' + PDF.TEXT_FONT_RESSOURCE;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "1 0 0 1 100.00 700.00 Tm"
   h_string = PDF.MATRIX_SCALE_1_1 + %CHAR(h_PosX) + ' ' + %CHAR(h_PosY) + ' ' + PDF.TEXT_MATRIX;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "(text) Tj"
   h_string = '(' + h_line2WriteUTF8 + ') ' + PDF.TEXT_DRAW;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "/ET"
   h_string = PDF.TEXTBLOCK_END;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);

End-Proc;

// -----------------------------------------------------------------------------
// add a Textblock to the stream of a page object 
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_addToStreamTextBlock1252  EXPORT;
   Dcl-Pi *n;
      // line number   (1 - 255)
      p_lineNumber       INT(10)        CONST;
      // column number (1 - 378)
      p_column           INT(10)        CONST;
      // line to write
      p_line2Write   VARCHAR(378)       CONST;
   End-PI;

   Dcl-S  h_line2Write      VARCHAR(1024);
   Dcl-S  h_line2Write1252  VARCHAR(1024) CCSID(1252);
   Dcl-S  h_string          VARCHAR(1024) CCSID(1252);

   Dcl-S  h_PosX       PACKED(8:3);
   Dcl-S  h_PosY       PACKED(8:3);
   Dcl-S  h_FontNumber    INT(10) INZ(1);
   Dcl-S  h_FontSize   LIKE(g_PDF.FontSize);

   IF %LEN(g_PDF.PageStream) = 0;
      RPDFG_startStream();
   ENDIF;

   RPDFG_calcLinePos(p_LineNumber:p_column:h_PosX:h_PosY);

   h_FontSize = g_PDF.FontSize;

   // Escape special characters in the string
   h_line2Write = %TRIMR(p_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BACKSLASH    :
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BACKSLASH    :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BRACKET_OPEN :
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BRACKET_OPEN :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_JOBRUN.BRACKET_CLOSE:
                       CCSID_JOBRUN.BACKSLASH + CCSID_JOBRUN.BRACKET_CLOSE:h_line2Write);

   h_line2Write1252 = h_line2Write;

   // "/BT"
   h_string = PDF.TEXTBLOCK_BEGIN;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "/F1 10.0 Tf"
   h_string = '/' + PDF.FONT_SELECT_NUMBER + %CHAR(h_FontNumber) + ' ' +
                                             %CHAR(h_FontSize) + ' ' + PDF.TEXT_FONT_RESSOURCE;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "1 0 0 1 100.00 700.00 Tm"
   h_string = PDF.MATRIX_SCALE_1_1 + %CHAR(h_PosX) + ' ' + %CHAR(h_PosY) + ' ' + PDF.TEXT_MATRIX;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "(text) Tj"
   h_string = '(' + h_line2Write1252 + ') ' + PDF.TEXT_DRAW;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "/ET"
   h_string = PDF.TEXTBLOCK_END;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);

End-Proc;

// -----------------------------------------------------------------------------
// add a UCS2 Textblock to the stream of a page object
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_addToStreamTextBlockUcs2  EXPORT;
   Dcl-Pi *n;
      // line number   (1 - 255)
      p_lineNumber       INT(10)    CONST;
      // column number (1 - 378)
      p_column           INT(10)    CONST;
      // line to write
      p_line2Write   VARUCS2(378)   CONST;
   End-PI;

   Dcl-S  h_line2Write      VARUCS2(1024);
   // Dcl-S  h_line2WriteUTF8  VARCHAR(1024) CCSID(*UTF8);
   Dcl-S  h_string          VARCHAR(1024) CCSID(*UTF8);

   Dcl-S  h_PosX       PACKED(8:3);
   Dcl-S  h_PosY       PACKED(8:3);
   Dcl-S  h_FontNumber    INT(10) INZ(1);
   Dcl-S  h_FontSize   LIKE(g_PDF.FontSize);

   Dcl-S  PDF_BOM_UTF16BE  CHAR(2) INZ(X'FEFF') CCSID(*HEX);

   IF %LEN(g_PDF.PageStream) = 0;
      RPDFG_startStream();
   ENDIF;

   RPDFG_calcLinePos(p_LineNumber:p_column:h_PosX:h_PosY);

   h_FontSize = g_PDF.FontSize;

   // Escape special characters in the string
   h_line2Write = %TRIMR(p_line2Write);
   h_line2Write = %SCANRPL(CCSID_UCS2.BACKSLASH    :
                       CCSID_UCS2.BACKSLASH + CCSID_UCS2.BACKSLASH    :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_UCS2.BRACKET_OPEN :
                       CCSID_UCS2.BACKSLASH + CCSID_UCS2.BRACKET_OPEN :h_line2Write);
   h_line2Write = %SCANRPL(CCSID_UCS2.BRACKET_CLOSE:
                       CCSID_UCS2.BACKSLASH + CCSID_UCS2.BRACKET_CLOSE:h_line2Write);

   // "/BT"
   h_string = PDF.TEXTBLOCK_BEGIN;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "/F1 10.0 Tf"
   h_string = '/' + PDF.FONT_SELECT_NUMBER + %CHAR(h_FontNumber) + ' ' +
                                             %CHAR(h_FontSize) + ' ' + PDF.TEXT_FONT_RESSOURCE;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   // "1 0 0 1 100.00 700.00 Tm"
   h_string = PDF.MATRIX_SCALE_1_1 + %CHAR(h_PosX) + ' ' + %CHAR(h_PosY) + ' ' + PDF.TEXT_MATRIX;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);

   // "(FEFF + text) Tj"
   h_string = '(';
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string));
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(PDF_BOM_UTF16BE):%LEN(PDF_BOM_UTF16BE));
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_line2Write:*DATA):%LEN(h_line2Write)*2);
   h_string = ') ' + PDF.TEXT_DRAW;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);

   // "/ET"
   h_string = PDF.TEXTBLOCK_END;
   RPDFG_add(%ADDR(g_PDF.PageStream):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);

End-Proc;

// -----------------------------------------------------------------------------
// replace substitution variables in the output file name
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_replaceSubstVar;
   Dcl-Pi *n LIKE(rtn_string) RTNPARM;
      p_string        VARCHAR(257)      CONST OPTIONS(*TRIM) CCSID(*JOBRUN);
      p_SplfAtr       LIKEDS(RPDFG_SplfAtr_T) CONST;
   End-PI;
   Dcl-S rtn_string   LIKE(p_string);

   // i can't specify the CCSID for an ENum, which would be perfect
   Dcl-DS SUBSTVAR CONST QUALIFIED;
      FILE           CHAR( 6)  CCSID(*JOBRUN) INZ('<FILE>');
      JOB            CHAR( 5)  CCSID(*JOBRUN) INZ('<JOB>');
      JOBNAM         CHAR( 8)  CCSID(*JOBRUN) INZ('<JOBNAM>');
      JOBUSR         CHAR( 8)  CCSID(*JOBRUN) INZ('<JOBUSR>');
      JOBNBR         CHAR( 8)  CCSID(*JOBRUN) INZ('<JOBNBR>');
      USER           CHAR( 6)  CCSID(*JOBRUN) INZ('<USER>');
      USRDTA         CHAR( 8)  CCSID(*JOBRUN) INZ('<USRDTA>');
      FORMTYPE       CHAR(10)  CCSID(*JOBRUN) INZ('<FORMTYPE>');
      OUTQNAME       CHAR(10)  CCSID(*JOBRUN) INZ('<OUTQNAME>');
      OUTQLIB        CHAR( 9)  CCSID(*JOBRUN) INZ('<OUTQLIB>');
      CRTDATE        CHAR( 9)  CCSID(*JOBRUN) INZ('<CRTDATE>');
      CRTTIME        CHAR( 9)  CCSID(*JOBRUN) INZ('<CRTTIME>');
      CRTTIMESTAMP   CHAR(14)  CCSID(*JOBRUN) INZ('<CRTTIMESTAMP>');
   End-DS;

   Dcl-S myJobParts  VARCHAR(10) DIM(3);
   Dcl-S myJob_Name     LIKE(p_SplfAtr.Job_Name);
   Dcl-S myCrtDate      CHAR(10);
   Dcl-S myCrtTime      CHAR( 8);
   Dcl-S myCrtTimestamp CHAR( 8);

   myJobParts = %SPLIT(p_SplfAtr.Job_Name:CCSID_JOBRUN.SLASH);
   myJob_Name = %SCANRPL(CCSID_JOBRUN.SLASH:CCSID_JOBRUN.UNDERLINE:myJob_Name);
   myCrtDate      = %CHAR(%DATE(p_SplfAtr.CreateTimestamp));
   myCrtTime      = %CHAR(%TIME(p_SplfAtr.CreateTimestamp));
   myCrtTimestamp = %CHAR(p_SplfAtr.CreateTimestamp);

   rtn_string = p_string;
   rtn_string = %scanrpl(SUBSTVAR.FILE    :p_SplfAtr.SplfName:rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.JOB     :myJob_Name        :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.JOBNAM  :myJobParts(3)     :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.JOBUSR  :myJobParts(2)     :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.JOBNBR  :myJobParts(1)     :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.USER    :p_SplfAtr.UserName:rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.USRDTA  :p_SplfAtr.UserData:rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.FORMTYPE:p_SplfAtr.FormType:rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.OUTQNAME:p_SplfAtr.OutqName:rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.OUTQLIB :p_SplfAtr.OutqLib :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.CRTDATE      :myCrtDate      :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.CRTTIME      :myCrtTime      :rtn_string);
   rtn_string = %scanrpl(SUBSTVAR.CRTTIMESTAMP :myCrtTimestamp :rtn_string);

   // remove invalid characters
   rtn_string = %scanrpl(CCSID_JOBRUN.COLON:CCSID_JOBRUN.UNDERLINE:rtn_string);

   RETURN rtn_string;

End-Proc;

// -----------------------------------------------------------------------------
// Open the IFS file for output
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_openPdfFile  EXPORT;
   Dcl-Pi *n;
      p_PDF_Path                  VARCHAR(128) CONST OPTIONS(*TRIM);
      p_PDF_File                  VARCHAR(128) CONST OPTIONS(*TRIM);
      p_SplfAtr        LIKEDS(RPDFG_SplfAtr_T) CONST;
   End-PI;

   Dcl-S  h_Path           VARCHAR(128) INZ('');
   Dcl-S  h_PathPart       VARCHAR(128);
   Dcl-S  h_PathParts      LIKE(h_PathPart) DIM(*AUTO:64);
   Dcl-S  h_Cmd            VARCHAR(2000) INZ('');

   Dcl-DS h_HeaderBuffer   QUALIFIED;
      length      INT(10);
      value      CHAR(32) CCSID(*HEX);
   End-DS;
   Dcl-S  h_string         VARCHAR(32) CCSID(*UTF8);

   Dcl-S error LIKE(errno);

   // Create directories if they do not exist
   h_Path      = '';
   h_PathParts = %SPLIT(p_PDF_Path:CCSID_JOBRUN.SLASH);
   FOR-EACH h_PathPart in h_PathParts;
      h_Path += h_PathPart;
      IF '.'  <> h_PathPart AND
         '..' <> h_PathPart;
         h_Cmd = 'MKDIR DIR(''' + h_Path + ''')';
         MONITOR;
            QCMDEXC(h_Cmd:%LEN(h_Cmd));
         ON-ERROR;
         ENDMON;
      ENDIF;
      h_Path += '/';
   ENDFOR;


   g_PDF.PDF_FileName = p_PDF_Path + '/' + p_PDF_File;
   g_PDF.PDF_FileName = RPDFG_replaceSubstVar(g_PDF.PDF_FileName:p_SplfAtr);

   g_PDF.Ifs_byteCount = 0;

   g_PDF.Ifs_handle = IFS_Open(g_PDF.PDF_FileName:
                               #O_WRONLY +
                                  #O_CREAT +
                                  #O_TRUNC +
                                  #O_CCSID +
                                  #O_INHERITMODE:
                               #S_IRWXU +
                                  #S_IRWXG +
                                  #S_IRWXO:
                               1208); // UTF-8 CCSID

   error  = errno();
   IF 0 <> error;
      SND-MSG *ESCAPE 'IFS_Open: ' + %CHAR(error) + ' ' + %STR(strerror(error));
   ENDIF;

   h_HeaderBuffer.length = 0;
   h_string = PDF.HEADER;
   RPDFG_add(%ADDR(h_HeaderBuffer):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   RPDFG_writeBuffer(%ADDR(h_HeaderBuffer.value):h_HeaderBuffer.length);
   // add a comment in line 2 with 4 characters > 128 to force binary treatment
   h_HeaderBuffer.length = %LEN(CCSID_HEX.HEADER_LINE2);
   h_HeaderBuffer.value  = CCSID_HEX.HEADER_LINE2;
   RPDFG_writeBuffer(%ADDR(h_HeaderBuffer.value):h_HeaderBuffer.length);

End-Proc;
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// write something to the IFS
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_writeBuffer  EXPORT;
   Dcl-Pi *n;
      p_Ptr_Buffer    POINTER      CONST;
      p_Buffer_Len        INT(10)  CONST;
   End-PI;

   Dcl-S h_BytesWritten LIKE(IFS_Write);

   Dcl-S error LIKE(errno);

   h_BytesWritten = IFS_Write(g_PDF.Ifs_handle:
                              p_Ptr_Buffer:
                              p_Buffer_Len);
   error  = errno();
   IF 0 <> error;
      SND-MSG *ESCAPE 'IFS_Write: ' + %CHAR(error) + ' ' + %STR(strerror(error));
   ENDIF;

   g_PDF.Ifs_byteCount += h_BytesWritten;

End-Proc;
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// serialize unwritten objects
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_serializeUnwrittenObjects EXPORT;
   Dcl-Pi *n;
   End-PI;

   Dcl-S #i                   INT(10);

   FOR #i = 1 TO RPDFG_g_objIdx;
      IF RPDFG_g_obj(#i).inUse;
         RPDFG_serializeObject(#i);
      ENDIF;
   ENDFOR;

   RETURN;

End-Proc;

// -----------------------------------------------------------------------------
// Close the IFS file
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_closePdfFile EXPORT;
   Dcl-Pi *n;
   End-PI;

   Dcl-S  h_EndOfFileBuffer   VARCHAR(64:4) CCSID(*HEX);
   Dcl-S  h_string            VARCHAR(32)   CCSID(*UTF8);
   // Dcl-S #i                   INT(10);

   IF g_PDF.Ifs_handle < 0;
      // TODO: error message "File is not open"
      RETURN; // file is not open, nothing to do
   ENDIF;

   // better: error.
   // FOR #i = 1 TO RPDFG_g_objIdx;
   //    IF RPDFG_g_obj(#i).inUse AND
   //       RPDFG_g_obj(#i).objNumberForPDF > 0;
   //       RPDFG_serializeObject(#i);
   //    ENDIF;
   // ENDFOR;

   %LEN(h_EndOfFileBuffer) = 0;
   h_string = PDF.STARTXREF;
   RPDFG_add(%ADDR(h_EndOfFileBuffer):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   h_string = %CHAR(g_PDF.startxref);
   RPDFG_add(%ADDR(h_EndOfFileBuffer):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   h_string = PDF.EOF;
   RPDFG_add(%ADDR(h_EndOfFileBuffer):%ADDR(h_string:*DATA):%LEN(h_string):ADD_EOL);
   RPDFG_writeBuffer(%ADDR(h_EndOfFileBuffer:*DATA):%LEN(h_EndOfFileBuffer));

   IFS_Close(g_PDF.Ifs_handle);

   g_PDF.Ifs_handle = -1;

End-Proc;


// -----------------------------------------------------------------------------
// add something to a buffer in a safe mode to prevent translations
// be sure to specify VARCHAR(n:4) if n is < 65535!
// -----------------------------------------------------------------------------
Dcl-Proc RPDFG_add EXPORT;
   Dcl-Pi *n;
      p_PtrToBuffer    POINTER      CONST;
      p_PtrFromBuffer  POINTER      CONST;
      p_Len            INT(10)      CONST;
      p_add_Special    VARCHAR(10)  CONST OPTIONS(*NOPASS);
   End-PI;

   Dcl-DS h_ToBuffer  QUALIFIED BASED(p_PtrToBuffer);
      BufferLength      INT(10);
      BufferValue       CHAR(100000) CCSID(*HEX);
   End-DS;
   Dcl-S  h_FromBuffer  CHAR(100000) BASED(p_PtrFromBuffer) CCSID(*HEX);

   %SUBST(h_ToBuffer.BufferValue:
          h_ToBuffer.BufferLength + 1:p_Len) = %SUBST(h_FromBuffer:1:p_Len);
   h_ToBuffer.BufferLength += p_Len;

   IF %PASSED(p_add_Special);
      SELECT;
         WHEN p_add_Special = ADD_EOL;
            %SUBST(h_ToBuffer.BufferValue:
                  h_ToBuffer.BufferLength + 1:%LEN(CCSID_HEX.EOL)) = CCSID_HEX.EOL;
            h_ToBuffer.BufferLength += %LEN(CCSID_HEX.EOL);
         OTHER;
            // TODO: error message "Unknown special add type"
      ENDSL;
   ENDIF;

   RETURN;

End-Proc;


// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
DCL-PROC SQL_Diagnostics ;
   EXEC SQL GET DIAGNOSTICS
            :SQL_Diag.RowsCount = ROW_COUNT;

   EXEC SQL GET DIAGNOSTICS CONDITION 1
            :SQL_Diag.ReturnedSQLCode  = DB2_RETURNED_SQLCODE,
            :SQL_Diag.ReturnedSQLState = RETURNED_SQLSTATE,
            :SQL_Diag.MessageLength    = MESSAGE_LENGTH,
            :SQL_Diag.MessageText      = MESSAGE_TEXT,
            :SQL_Diag.MessageId        = DB2_MESSAGE_ID,
            :SQL_Diag.MessageId1       = DB2_MESSAGE_ID1,
            :SQL_Diag.MessageId2       = DB2_MESSAGE_ID2 ;
END-PROC ;
