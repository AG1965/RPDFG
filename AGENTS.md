# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Build System

Build via CL program `QCLPSRC/MAKE.CLLE` - pass library name as parameter:

```
CALL PGM(MAKE) PARM('MYLIB')
```

Build creates:

- Service program `RPDFG` (NOMAIN module) from `QRPGMOD/RPDFG.SQLRPGLE`
- Command `RPDFGCVT` and program from `QRPGSRC/RPDFGCVT.SQLRPGLE`
- Binding directory `RPDFG` with service program reference
- Message file `RPDFGMSGF` with custom messages (RPDF001-RPDF009, CMD0001-CMD0030)
- Panel group `RPDFGCVT` for command help

All compilation uses `CRTSQLRPGI` with `TGTCCSID(*JOB)` - CCSID handling is critical.

## Critical CCSID Requirements

**MUST NOT** have system QCCSID=65535. Job CCSID must be set to valid value (typically device default CCSID).

Code uses three CCSID contexts simultaneously:

- `CCSID(*JOBRUN)` for command parameters and messages
- `CCSID(*UTF8)` for PDF content strings
- `CCSID(*HEX)` for PDF binary markers (EOL, header bytes)

## Non-Standard Architecture

**Service program exports MUST maintain exact order** in `QSRVSRC/RPDFG.BND` - signature is `V010` and order-dependent.

**Object/Dictionary management uses parallel arrays** not linked lists:

- `RPDFG_obj_T` array (max objects determined at compile time)
- `RPDFG_dict_T` array (max dictionaries determined at compile time)
- Objects track `objNumberForPDF` (PDF numbering) separately from array index
- `inUse` flag marks active slots - deletion marks as not in use, doesn't free

**Pages tree has hard limits**:

- `PAGES_PER_PAGES = 5` (max "Pages" objects in tree)
- `PAGE_PER_PAGES = 5` (max "Page" objects per "Pages")
- These constants appear in both QRPGMOD and QRPGSRC - must stay synchronized

## Code Style

**Free-format RPG** (`**FREE` directive) with:

- `CTL-OPT` for control options, not H-specs
- `Dcl-` prefix for all declarations (Dcl-S, Dcl-DS, Dcl-PR, Dcl-C, Dcl-ENum)
- `End-` terminators (End-DS, End-PR, End-ENum)
- Qualified data structures (`QUALIFIED` keyword)
- `CONST` parameters where applicable
- `TEMPLATE` for reusable data structure definitions
- `LIKEDS()` and `LIKE()` for type references

**CCSID annotations required** on character fields when not default:

```rpg
Dcl-S RPDFGMSGF CHAR(21) CONST CCSID(*JOBRUN) INZ('*LIBL/RPDFGMSGF');
```

**Naming convention**: `RPDFG_` prefix for all exported symbols and templates.

## Testing

Test spooled file generator: `CRTTSTSPLF` command (German prompts in CMD source).

Creates test spooled files with configurable:

- Page size (lines/columns)
- LPI/CPI values
- Page rotation
- Font settings

No automated test framework - manual testing via spooled file conversion.

## PDF Generation Flow

1. Call `RPDFG_openPdfFile()` - opens IFS file for writing
2. Create objects via `RPDFG_newObject()` and dictionaries via `RPDFG_newDictionary()`
3. Build Pages tree with `RPDFG_setRelation()` (parent/kid relationships)
4. Add dictionary entries with `RPDFG_addDictEntry()`
5. Write page content streams:
   - `RPDFG_startStream()`
   - `RPDFG_addToStreamTextBlock()` (or UTF8/UCS2 variants)
   - `RPDFG_endStream()`
6. Serialize objects with `RPDFG_serializeObject()` (invalidates object index!)
7. Write remaining objects with `RPDFG_serializeUnwrittenObjects()`
8. Call `RPDFG_closePdfFile()`

**Critical**: After `RPDFG_serializeObject()`, the object index is no longer valid - object is written and marked not in use.

## Command Usage

```CLLE
RPDFGCVT FILE(QSYSPRT) JOB(*) SPLNBR(*LAST) PDFFILE('output.pdf')
```

Special parameter values:

- `SPLNBR(*ONLY 0)` or `(*LAST -1)` - internal numeric codes
- `PAGRTT(*SPLFA)` - use spooled file attribute (default)
- `PAGRTT(*AUTO)` - auto-detect from page dimensions
- `LPI(*SPLFA -1)` or `(*AUTO -2)` - special values for lines per inch
- `CPI(*SPLFA -1)` or `(*AUTO -2)` - special values for characters per inch
- `PDFNAME` supports substitution variables: `<FILE>`, `<CRTDATE>`, `<CRTTIME>`, `<USER>`

Margins in points (1/72 inch), default right/bottom = 7pt.

## Known Issues (from README)

- PDF compatibility limited to Chrome and VS Code viewers
- Page tree errors with >5 pages (NOT due to hard-coded limits)
- Timezone handling not implemented
- Umlauts render bold (font issue)
- No overlay support yet
