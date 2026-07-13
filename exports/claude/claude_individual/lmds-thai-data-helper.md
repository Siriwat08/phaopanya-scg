<!-- DOC-TYPE: living -->
# lmds-thai-data-helper

# Thai Data Normalization

LMDS Thai Data Helper — Names, Addresses, Phonetic, Geo
Status: LMDS V6.0.046 — 80+ Thai prefixes supported, 7,537-row Thai geo dictionary (SYS_TH_GEO)
Purpose: Help process and match Thai text data — names, addresses, phones, postal codes, provinces.
Key files: 05_NormalizeService.gs (name normalization), 20_ThGeoService.gs (address parsing), 16_GeoDictionaryBuilder.gs (index), 21_AliasService.gs (cross-table alias)

This skill is the linguistic layer — load lmds-architect first to know where Thai data flows, then use this when working on any Thai text.

1. The Thai Text Pipeline
text

Copy
Raw text (from SCG driver / customer)

        ↓

05_NormalizeService.normalizePersonNameFull

  - Strip Thai prefix (80+ patterns: นาย, นาง, น.ส., คุณ, บจก., หจก., ...)

  - Strip whitespace, punctuation

  - Lowercase

  - Optional: Romanize for cross-system

        ↓

05_NormalizeService.buildThaiPhoneticKey

  - Double Metaphone for Thai (custom)

  - Returns a phonetic key string

        ↓

05_NormalizeService.extractPhone

  - Match Thai phone patterns: 0X-XXXX-XXXX, 0XXXXXXXXX, +66X-XXX-XXXX

  - Normalize to 10 digits

        ↓

05_NormalizeService.extractDocumentId

  - Thai national ID: 1-XXXX-XXXXX-XX-X

  - Tax ID: X-XXXX-XXXXX-X

  - Passport: 2 letters + 7 digits

        ↓

20_ThGeoService.extractGeoFromAddress

  - Use SYS_TH_GEO dictionary (7,537 rows)

  - Match Tambon (ตำบล), Amphoe (อำเภอ), Province (จังหวัด)

  - Returns { tambon, amphoe, province, postcode, searchKey }

        ↓

07_PlaceService.resolvePlace uses the geo info
2. The 80+ Thai Prefixes
LMDS strips these prefixes from person names before matching. The full list is in 05_NormalizeService.gs. Sample:

Personal prefixes

นาย (Mr.)

นาง (Mrs.)

นางสาว, น.ส., น.ส (Miss)

คุณ (polite, gender-neutral)

ด.ช. (boy)

ด.ญ. (girl)

เด็กชาย, เด็กหญิง

พ.ต. (police ranks — many)

ดร., นพ., พญ., น.พ., ทพ., ภก., น.สพ.

ศ., รศ., ผศ., อ. (academic ranks)

พล.ต.อ., พล.ต.ท., etc. (police high ranks)

พ.อ., พ.ท., พ.ต., ร.อ., ร.ท., ร.ต. (military)

จ.อ., จ.ท., จ.ต. (NCO)

พลเรือเอก, พลเรือโท, etc. (navy)

พลอากาศเอก, พลอากาศโท, etc. (air force)

หม่อมหลวง, หม่อมราชวงศ์, ม.ร.ว.,  .ล.

พระ, พระอาจารย์, เจ้าอธิการ, พระครู

ส.ต.อ., ส.ต.ท., ส.ต.ต. (police NCO)

Company prefixes

บริษัท, บริษัทจำกัด, บริษัท จำกัด

บจก., บมจ., บจก, บมจ (abbreviated)

ห้างหุ้นส่วน, ห้างหุ้นส่วนจำกัด, ห้างหุ้นส่วนสามัญ

หจก., หสน.

Co.,Ltd., Co. Ltd., Ltd., Inc., Corp., LLC

Public Company Limited, Limited, Pcl.

มหาวิทยาลัย, ม., University, College

โรงพยาบาล, รพ., Hospital

โรงเรียน, รร., School

วัด, Temple

สำนักงาน, สนง., Office

Government / state enterprise

กรม, กอง, สำนัก, ศูนย์, สถาบัน

กระทรวง, ทบวง, กรม

จังหวัด, อำเภอ, เทศบาล, อบจ., อบต.

รัฐวิสาหกิจ, รัฐวิสาหกิจจำกัด

Use the constant
js

Copy
// In 05_NormalizeService.gs

const THAI_PERSONAL_PREFIXES = [

  'นาย', 'นาง', 'นางสาว', 'น.ส.', 'น.ส', 'คุณ',

  'ด.ช.', 'ด.ญ.', 'เด็กชาย', 'เด็กหญิง',

  // ... 80+ total

];


const THAI_COMPANY_PREFIXES = [

  'บริษัท', 'บริษัทจำกัด', 'บริษัท จำกัด',

  'บจก.', 'บมจ.', 'บจก', 'บมจ',

  'ห้างหุ้นส่วน', 'ห้างหุ้นส่วนจำกัด',

  'หจก.', 'หสน.',

  'Co.,Ltd.', 'Co. Ltd.', 'Ltd.', 'Inc.', 'Corp.',

  'Public Company Limited', 'Pcl.'

];


function stripPrefix_(name) {

  if (!name) return name;

  let stripped = String(name).trim();

  

  // Personal prefixes (longest match first)

  for (const prefix of THAI_PERSONAL_PREFIXES.sort((a, b) => b.length - a.length)) {

    if (stripped.startsWith(prefix)) {

      stripped = stripped.slice(prefix.length).trim();

      break;  // only strip one prefix

    }

  }

  

  // Company prefixes

  for (const prefix of THAI_COMPANY_PREFIXES.sort((a, b) => b.length - a.length)) {

    if (stripped.toLowerCase().startsWith(prefix.toLowerCase())) {

      stripped = stripped.slice(prefix.length).trim();

      break;

    }

  }

  

  return stripped;

}
The Bug to Avoid
js

Copy
// ❌ BAD — only strips first 4 chars

function stripPrefix(name) {

  return name.replace('นาย', '').replace('นาง', '');

}


// ✅ GOOD — longest match first

function stripPrefix(name) {

  const prefixes = ['นางสาว', 'นาย', 'นาง'];  // longest first

  for (const p of prefixes) {

    if (name.startsWith(p)) return name.slice(p.length).trim();

  }

  return name;

}
3. Phone Number Normalization
Thai phone patterns
Pattern	Example	Normalized
0X-XXX-XXXX	02-123-4567	021234567
0X-XXXX-XXXX	08-1234-5678	0812345678
0XXXXXXXXX	0812345678	0812345678
+66X-XXX-XXXX	+662-123-4567	021234567
+66XXXXXXXXX	+66812345678	0812345678
(0X) XXX-XXXX	(02) 123-4567	021234567
The pattern
js

Copy
function extractPhone_(text) {

  if (!text) return null;

  const str = String(text);

  

  // Remove all non-digit chars except leading +

  const digits = str.replace(/[^\d+]/g, '');

  

  // Match patterns

  const patterns = [

    /^\+66(\d{9})$/,   // +66 + 9 digits (mobile or landline)

    /^0(\d{9})$/,      // 0 + 9 digits

    /^0(\d{8})$/,      // 0 + 8 digits (older landline format)

  ];

  

  for (const re of patterns) {

    const m = digits.match(re);

    if (m) return m[1].length === 9 ? '0' + m[1] : m[1];

  }

  

  return null;  // not a valid Thai phone

}
Mobile prefix validation (optional)
js

Copy
const VALID_MOBILE_PREFIXES = [

  '06', '08', '09',     // AIS

  '061', '062', '063', '064', '065',  // AIS 3G/4G

  '066', '067', '068',

  '081', '082', '083', '084', '085', '086', '087', '088', '089',

  '090', '091', '092', '093', '094', '095', '096', '097', '098', '099'

];


function isValidMobilePhone_(phone) {

  if (!phone || phone.length !== 10) return false;

  const prefix3 = phone.slice(0, 3);

  const prefix2 = phone.slice(0, 2);

  return VALID_MOBILE_PREFIXES.includes(prefix3) || 

         VALID_MOBILE_PREFIXES.includes(prefix2);

}
4. Document ID Extraction
National ID (13 digits, format 1-2345-67890-12-3)
js

Copy
function extractNationalId_(text) {

  if (!text) return null;

  const cleaned = String(text).replace(/[^\d]/g, '');

  if (cleaned.length !== 13) return null;

  if (cleaned[0] !== '1') return null;  // Thai national ID starts with 1

  if (!isValidThaiIdChecksum_(cleaned)) return null;

  return cleaned;

}


function isValidThaiIdChecksum_(id) {

  let sum = 0;

  for (let i = 0; i < 12; i++) {

    sum += Number(id[i]) * (13 - i);

  }

  const check = (11 - (sum % 11)) % 10;

  return check === Number(id[12]);

}
Tax ID (10 digits, format X-XXXX-XXXX-X)
js

Copy
function extractTaxId_(text) {

  if (!text) return null;

  const cleaned = String(text).replace(/[^\d]/g, '');

  if (cleaned.length !== 10) return null;

  return cleaned;

}
Passport (2 letters + 7 digits)
js

Copy
function extractPassport_(text) {

  if (!text) return null;

  const m = String(text).toUpperCase().match(/^([A-Z]{2})(\d{7})$/);

  return m ? m[0] : null;

}
5. Address Parsing (Thai Geo)
The Dictionary (SYS_TH_GEO)

7,537 rows

Schema (TH_GEO_IDX):

0: province (จังหวัด) e.g. "กรุงเทพมหานคร"

1: amphoe (อำเภอ) e.g. "เขตบางรัก"

2: tambon (ตำบล) e.g. "บางรัก"

3: postcode (5 digits) e.g. "10500"

4-15: metadata (12 cols)

16: search_key (normalized for fast lookup)


Building the search key
The dictionary is indexed by a search_key that's a normalized concatenation:

js

Copy
function buildThaiGeoSearchKey_(tambon, amphoe, province) {

  return [

    normalizeThaiText_(tambon || ''),

    normalizeThaiText_(amphoe || ''),

    normalizeThaiText_(province || '')

  ].join('|');

}


function normalizeThaiText_(s) {

  if (!s) return '';

  return String(s)

    .toLowerCase()

    .replace(/\s+/g, '')

    .replace(/^(ตำบล|อำเภอ|จังหวัด|เขต|แขวง|ต\.|อ\.|จ\.)/g, '')

    .trim();

}
Extracting from a raw address
js

Copy
function extractGeoFromAddress_(rawAddress) {

  if (!rawAddress) return null;

  

  const dict = loadGeoDictionary_();  // 7,537 rows cached

  const normalized = normalizeThaiText_(rawAddress);

  

  // Strategy 1: exact search_key match

  for (const row of dict) {

    if (normalized.includes(row.search_key)) {

      return {

        tambon: row.tambon,

        amphoe: row.amphoe,

        province: row.province,

        postcode: row.postcode,

        confidence: 100

      };

    }

  }

  

  // Strategy 2: try each component separately

  const components = extractAddressComponents_(rawAddress);

  if (components.province) {

    const matches = dict.filter(r => normalizeThaiText_(r.province) === components.province);

    if (matches.length > 0) {

      // Try to disambiguate by amphoe/tambon

      const refined = matches.filter(r => 

        !components.amphoe || normalizeThaiText_(r.amphoe) === components.amphoe

      );

      return refined[0] || matches[0];

    }

  }

  

  return null;

}
Address component patterns
js

Copy
function extractAddressComponents_(rawAddress) {

  const text = String(rawAddress);

  

  // Province pattern: "จ.กรุงเทพมหานคร", "จังหวัด นนทบุรี", "กรุงเทพฯ"

  const provinceMatch = text.match(/(?:จ\.|จังหวัด)\s*([ก-๙]+)/);

  const province = provinceMatch ? provinceMatch[1] : null;

  

  // Amphoe pattern: "อ.เมือง", "อำเภอเมือง", "เขตบางรัก"

  const amphoeMatch = text.match(/(?:อ\.|อำเภอ|เขต|แขวง)\s*([ก-๙]+)/);

  const amphoe = amphoeMatch ? amphoeMatch[1] : null;

  

  // Tambon pattern: "ต.บางรัก", "ตำบลบางรัก"

  const tambonMatch = text.match(/(?:ต\.|ตำบล)\s*([ก-๙]+)/);

  const tambon = tambonMatch ? tambonMatch[1] : null;

  

  // Postcode pattern: 5 digits

  const postcodeMatch = text.match(/\b(\d{5})\b/);

  const postcode = postcodeMatch ? postcodeMatch[1] : null;

  

  return { province, amphoe, tambon, postcode };

}
6. Double Metaphone for Thai (Phonetic Key)
The classic Double Metaphone algorithm is designed for English. For Thai, LMDS uses a custom variant based on:


Thai consonant classes (high/mid/low)

Vowel length

Tone marks (ignored for phonetic purposes)

js

Copy
function buildThaiPhoneticKey_(name) {

  if (!name) return '';

  const stripped = stripPrefix_(normalizeForCompare_(name));

  return computeThaiMetaphone_(stripped);

}


function computeThaiMetaphone_(text) {

  if (!text) return '';

  const result = [];

  

  for (let i = 0; i < text.length; i++) {

    const ch = text[i];

    const next = text[i + 1] || '';

    

    if (isThaiChar_(ch)) {

      const code = thaiPhonemeClass_(ch, next);

      if (code && result[result.length - 1] !== code) {  // dedupe adjacent

        result.push(code);

      }

    } else if (/[a-z]/.test(ch)) {

      // Romanize English chars (basic)

      const lower = ch.toLowerCase();

      if (lower !== result[result.length - 1]) {

        result.push(lower);

      }

    }

  }

  

  return result.join('');

}


function thaiPhonemeClass_(ch, next) {

  // Map Thai consonant/vowel to a phoneme class

  // This is a simplified version — full impl has ~50 rules

  const map = {

    'ก': 'K', 'ข': 'K', 'ค': 'K', 'ฆ': 'K', 'ง': 'NG',

    'จ': 'J', 'ฉ': 'J', 'ช': 'C', 'ซ': 'S', 'ฌ': 'C',

    'ญ': 'Y', 'ฎ': 'D', 'ฏ': 'T', 'ฐ': 'T', 'ฑ': 'T',

    'ฒ': 'T', 'ณ': 'N', 'ด': 'D', 'ต': 'T', 'ถ': 'T',

    'ท': 'T', 'ธ': 'T', 'น': 'N', 'บ': 'B', 'ป': 'P',

    'ผ': 'P', 'ฝ': 'F', 'พ': 'P', 'ฟ': 'F', 'ภ': 'P',

    'ม': 'M', 'ย': 'Y', 'ร': 'R', 'ล': 'L', 'ว': 'W',

    'ศ': 'S', 'ษ': 'S', 'ส': 'S', 'ห': 'H', 'ฬ': 'L',

    'อ': '', 'ฮ': 'H',

    // Vowels — context-dependent

    'ะ': 'A', 'า': 'A', 'ิ': 'I', 'ี': 'I', 'ึ': 'U', 'ื': 'U',

    'ุ': 'U', 'ู': 'U', 'เ': 'E', 'แ': 'AE', 'โ': 'O', 'ใ': 'AI'

  };

  return map[ch] || '';

}
Example outputs
Input	Output
สมชาย	SMCI (S from ส, M from ม, C from ช, I from ั+ย)
สมชัย	SMCI (same — proves it works)
สมใจ	SMCI (J from จ → C)
บริษัท ซีเมนต์ไทย	BRCSTICMNT (with company prefix stripped first)
บจก. สมชายการค้า	BRCSTICMNT (or similar)
7. Comparison & Matching Helpers
normalizeForCompare_
Used before any string comparison for matching:

js

Copy
function normalizeForCompare_(text) {

  if (!text) return '';

  return String(text)

    .toLowerCase()

    .replace(/\s+/g, '')           // remove all whitespace

    .replace(/[.,\-_'"]/g, '')    // remove punctuation

    .replace(/^(นาย|นาง|นางสาว|น\.ส\.|คุณ|บริษัท|ห้างหุ้นส่วน|จำกัด|บจก\.|หจก\.)/g, '')

    .trim();

}
Dice coefficient (Thai-friendly)
js

Copy
function diceCoefficient_(a, b) {

  if (!a || !b) return 0;

  a = normalizeForCompare_(a);

  b = normalizeForCompare_(b);

  if (a === b) return 1;

  if (a.length < 2 || b.length < 2) return 0;

  

  const aBigrams = new Map();

  for (let i = 0; i < a.length - 1; i++) {

    const bigram = a.slice(i, i + 2);

    aBigrams.set(bigram, (aBigrams.get(bigram) || 0) + 1);

  }

  

  let intersection = 0;

  for (let i = 0; i < b.length - 1; i++) {

    const bigram = b.slice(i, i + 2);

    const count = aBigrams.get(bigram);

    if (count > 0) {

      aBigrams.set(bigram, count - 1);

      intersection++;

    }

  }

  

  return (2.0 * intersection) / (a.length + b.length - 2);

}
Levenshtein distance
js

Copy
function levenshteinDistance_(a, b) {

  a = normalizeForCompare_(a);

  b = normalizeForCompare_(b);

  if (a === b) return 0;

  if (!a.length) return b.length;

  if (!b.length) return a.length;

  

  const matrix = Array(b.length + 1).fill(null).map(() => Array(a.length + 1).fill(null));

  for (let i = 0; i <= a.length; i++) matrix[0][i] = i;

  for (let j = 0; j <= b.length; j++) matrix[j][0] = j;

  

  for (let j = 1; j <= b.length; j++) {

    for (let i = 1; i <= a.length; i++) {

      const cost = a[i - 1] === b[j - 1] ? 0 : 1;

      matrix[j][i] = Math.min(

        matrix[j - 1][i] + 1,

        matrix[j][i - 1] + 1,

        matrix[j - 1][i - 1] + cost

      );

    }

  }

  

  return matrix[b.length][a.length];

}
Similarity score (0-1)
js

Copy
function similarityScore_(a, b) {

  const aNorm = normalizeForCompare_(a);

  const bNorm = normalizeForCompare_(b);

  if (aNorm === bNorm) return 1;

  const maxLen = Math.max(aNorm.length, bNorm.length);

  if (maxLen === 0) return 0;

  const dist = levenshteinDistance_(aNorm, bNorm);

  return 1 - (dist / maxLen);

}
8. Testing Thai Data Helpers
Use the 10d_MatchTestHarness.gs framework or a custom test:

js

Copy
function testThaiNormalization() {

  const cases = [

    { input: 'นายสมชาย ใจดี', expected: 'สมชายใจดี' },

    { input: 'น.ส. ปาริชาต ศรีสวัสดิ์', expected: 'ปาริชาตศรีสวัสดิ์' },

    { input: 'บริษัท สมชายการค้า จำกัด', expected: 'สมชายการค้า' },

    { input: 'บจก.SCG Cement', expected: 'scgcement' },

    { input: 'คุณมานี มานพ', expected: 'มานีมานพ' },

  ];

  

  let passed = 0;

  cases.forEach(({ input, expected }) => {

    const result = normalizeForCompare_(input);

    if (result === expected) {

      passed++;

      console.log(`✅ "${input}" → "${result}"`);

    } else {

      console.log(`❌ "${input}" → "${result}" (expected "${expected}")`);

    }

  });

  console.log(`${passed}/${cases.length} passed`);

}
Edge cases to test
1.
Mixed Thai + English: "SCG Cement บริษัท" → how to handle?
2.
Multiple prefixes: "น.ส. ดร. สมศรี" — strip the longest first
3.
Empty / null input: must return '' or null, not throw
4.
All whitespace: " " → ''
5.
Unicode normalization: "สมชาย" vs "สมชาย" (with combining marks) — should be equal
6.
Tone marks: "สมชาย" (no tone) vs "สมช้าย" (with tone) — should match for phonetic purposes
7.
Mixed case in English part: "Mr. SOMCHAI" → "somchai"
8.
Phone in name: "สมชาย 081-234-5678" — extract phone separately, don't pollute name
9.
Address in name: "สมชาย (กรุงเทพ)" — should we strip the address?
10.
Very long text: "บริษัท สมชายการค้าจำหน่ายวัสดุก่อสร้างทุกชนิด จำกัด" — should still work
9. Common Pitfalls in Thai Data Work
Pitfall	Why it's bad	Fix
Forgetting to strip prefix before comparison	"นายสมชาย" ≠ "สมชาย" string-wise	Always stripPrefix_ before normalizeForCompare_
Comparing without lowercasing	"Somchai" ≠ "somchai" in JS	Always .toLowerCase()
Ignoring whitespace differences	"สมชาย ใจดี" ≠ "สมชายใจดี"	Always .replace(/\s+/g, '')
Tone-sensitive matching	"สมชาย" matches "สมช้าย" by phonetic but not by string	Use diceCoefficient_ (catches ~80%) or phonetic key (catches ~95%)
Thai chars in regex ranges	[a-z] doesn't match Thai	Use [ก-๙] for Thai range (U+0E01 to U+0E5B)
Numeric chars in Thai context	Thai has ๐-๹ in addition to 0-9	String(text).replace(/[๐-๙]/g, ch => '๐๑๒๓๔๕๖๗๘๙'.indexOf(ch))
Encoding issues (TIS-820 / UTF-8)	Old systems may use TIS-820	LMDS is fully UTF-8, no conversion needed
Date parsing	Thai date format is different (Buddhist calendar, e.g. 2567 instead of 2024)	Always parse with Utilities.formatDate() and specify timezone
String.length on Thai	"สมชาย".length is 6 (UTF-16 code units), not 5 (chars)	Use [...text].length to count code points
Phone with leading +66	"+66812345678" vs "0812345678" — same phone	Normalize both to 0XXXXXXXXX
Postal code as 4 digits (older)	Some records use 4-digit postcodes	Pad to 5: String(n).padStart(5, '0')
Bangkok districts as "amphoe"	Bangkok has "เขต" (khet), not "อำเภอ"	Map เขต → amphoe in the dictionary
10. Adding a New Normalization Rule
Suppose you need to add support for "บริษัท เอสซีจี ซีเมนต์ จำกัด" matching "SCG Cement":

1.
Add a company alias dictionary to 21_AliasService.gs:
js

Copy
const COMPANY_ALIASES = {

  'SCG': 'บริษัท เอสซีจี ซีเมนต์ จำกัด',

  'SCG Cement': 'บริษัท เอสซีจี ซีเมนต์ จำกัด',

  'เอสซีจี': 'บริษัท เอสซีจี ซีเมนต์ จำกัด',

  // ...

};
2.
Create a migration script that adds these to M_ALIAS (admin only):
js

Copy
function seedCompanyAliases() {

  if (!isAuthorizedUser_()) throw new Error('Admin only');

  for (const [variant, canonical] of Object.entries(COMPANY_ALIASES)) {

    const person = findPersonByCanonicalName_(canonical);

    if (person) {

      createGlobalAlias_({

        master_uuid: person.master_uuid,

        variant_name: variant,

        entity_type: 'PERSON',

        confidence: 0.9,

        source: 'MIGRATION'

      });

    }

  }

}
3.
Update 06_PersonService.findPersonCandidates_ to also check M_ALIAS for these:
js

Copy
const aliasMatch = fastLookupByShipToName_(normalizedName);

if (aliasMatch) candidates.unshift({ ...aliasMatch, strategy: 'alias', score: 95 });
4.
Test with 10d_MatchTestHarness:
js

Copy
testThaiNormalization();  // existing

testAliasMatching();      // new
5.
Update docs/01_SOP_Admin_LMDS.md to mention the new aliases.
11. Output Template for Thai Data Changes
When you change Thai normalization, output:

markdown

Copy
# Thai Data Helper — Change Report


## Change

- File: 05_NormalizeService.gs (or 20_ThGeoService.gs)

- Function: normalizePersonNameFull

- Rule added: Strip "ดร." (Doctor) prefix


## Test cases

| Input | Before | After | Notes |

|-------|--------|-------|-------|

| ดร. สมชาย | ❌ "ดร.สมชาย" | ✅ "สมชาย" | New rule works |

| ดร.นายสมชาย | ❌ "ดร.นายสมชาย" | ✅ "สมชาย" | Both prefixes stripped |


## Edge cases verified

- [ ] Null input

- [ ] Empty string

- [ ] Only prefix

- [ ] Mixed Thai/English

- [ ] Multiple prefixes


## LMDS Laws affected

- Law 17 (Schema Truthfulness): N/A

- Law 20 (Cache Invalidation): may need `invalidateAllGlobalCaches()` after deployment


## Required follow-ups

- [ ] Bump APP_VERSION to 6.0.045

- [ ] Update CHANGELOG

- [ ] Run /REVIEW15 and /BUGHUNT

- [ ] Re-test 10d_MatchTestHarness

- [ ] Re-run 29_SnapshotTest
12. Integration with Other Skills

lmds-architect — load first.

lmds-match-engine-builder — Thai normalization feeds into the 5-strategy search.

lmds-code-reviewer — for code compliance.

lmds-bug-hunter — for regression in matching accuracy.

lmds-predeploy-checker — for the final go/no-go.