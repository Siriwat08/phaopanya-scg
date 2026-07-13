<!-- DOC-TYPE: living -->
# lmds-match-engine-builder

# Trinity + 8 Rules

LMDS Match Engine Builder — Trinity + 8 Rules
Status: LMDS V6.0.046 — Match Engine 100% complete (Phases 2+3), Search Service 2-Tier
Purpose: Help build, extend, and debug the matching logic — the brain of LMDS.
Key files: 05_NormalizeService, 06_PersonService, 07_PlaceService, 08_GeoService, 09_DestinationService, 10_MatchEngine, 10b_MatchDecision, 10d_MatchTestHarness, 10e_MatchResolvePersist, 17_SearchService, 21_AliasService

This skill is the brain builder — load lmds-architect first to know the file roles, then use this when touching any match logic.

1. The Mental Model
text

Copy
Raw SCG e-POD row

        ↓

05_NormalizeService (clean names, extract phones, build phonetic key)

        ↓

06_PersonService.resolvePerson (5 strategies)

        ↓

07_PlaceService.resolvePlace (incl. 20_ThGeoService.extractGeoFromAddress)

        ↓

08_GeoService.resolveGeo (proximity + grid)

        ↓

09_DestinationService.resolveDestination (Trinity intersection)

        ↓

10_MatchEngine.makeMatchDecision (8-rule matrix)

        ↓

executeDecision:

  AUTO_MATCH  → 11_TransactionService.upsertFactDelivery

  CREATE_NEW  → create master + upsertFactDelivery

  NEEDS_REVIEW → 12_ReviewService → Q_REVIEW

        ↓

autoEnrichAliasesFromFactBatch_ (self-healing alias, single-writer)
The Match Engine's job: given a raw row, decide what already exists in master, what needs creating, and what needs a human.

2. The 8 Rules (Detailed)
In 10b_MatchDecision.gs, defined as a MATCH_RULES table evaluated in priority order:

Rule 1 — INVALID_LATLNG (CRITICAL)
Trigger: raw_lat === 0 || raw_lng === 0 || raw_lat == null || raw_lng == null
Action: REVIEW_INVALID (confidence = 0)
Why CRITICAL: without coordinates, the shipment is undeliverable. Flag immediately.

Implementation pattern:

js

Copy
function isInvalidLatLng_(row) {

  const lat = row[FACT_IDX.RAW_LAT];

  const lng = row[FACT_IDX.RAW_LNG];

  return lat == null || lng == null || lat === 0 || lng === 0;

}
Rule 2 — LOW_QUALITY (HIGH)
Trigger: name too short (< 3 chars after normalize) OR address missing province.
Action: REVIEW
Why: unreliable data can't be matched safely.

Implementation pattern:

js

Copy
function isLowQuality_(row, ctx) {

  const name = row[FACT_IDX.SHIP_TO_NAME];

  const normName = normalizeForCompare(name);

  if (normName.length < 3) return true;

  if (!ctx.geo?.province) return true;

  return false;

}
Rule 3 — GEO_PROVINCE_CONFLICT (HIGH)
Trigger: resolved province (from LatLong) ≠ province in address.
Action: REVIEW (confidence = 50)
Why: if the address says "Bangkok" but the GPS says "Nonthaburi", something is wrong.

Implementation pattern:

js

Copy
function isProvinceConflict_(ctx) {

  const addrProvince = ctx.addressProvince;

  const geoProvince = ctx.geo?.province;

  return addrProvince && geoProvince && addrProvince !== geoProvince;

}
Rule 3.5 — NEARBY_PENDING (MEDIUM, Tiered Spatial)
Trigger: a nearby existing Geo Point exists.
Action: depends on distance band:


≤ 50m → AUTO_MERGE (treat as same place)

51-79m → YELLOW (auto-merge with flag)

80-100m → ORANGE (review)

100m → treat as new


Why: truck GPS has 10-50m noise; same building = same destination.

Implementation pattern:

js

Copy
function decideNearbyPending_(row, ctx) {

  const nearby = findNearbyGeos_(ctx.candidateGeo, 100);

  if (nearby.length === 0) return { action: 'CONTINUE' };  // fall through to next rule

  

  const closest = nearby[0];

  const distance = haversineDistanceM_(ctx.candidateGeo, closest);

  

  if (distance <= 50) return { action: 'AUTO_MERGE', confidence: 85, targetGeo: closest.geo_id };

  if (distance <= 79) return { action: 'AUTO_MERGE_FLAGGED', confidence: 75, targetGeo: closest.geo_id };

  if (distance <= 100) return { action: 'REVIEW', confidence: 60, targetGeo: closest.geo_id };

  return { action: 'CONTINUE' };

}
Rule 4 — FULL_MATCH (AUTO)
Trigger: Person + Place + Geo all match existing master rows.
Action: AUTO_MATCH (confidence = 100)
Why: all 3 FKs resolve = trivially correct.

Implementation pattern:

js

Copy
function isFullMatch_(ctx) {

  return ctx.person?.person_id && ctx.place?.place_id && ctx.geo?.geo_id

    && ctx.destination?.dest_id;

}
Rule 5 — GEO_ANCHOR (AUTO)
Trigger: existing Geo + existing Person, Place may be new.
Action: AUTO_MATCH (confidence = 95)
Why: GPS is hard to fake; if Geo + Person match, the place is almost certainly the same.

Implementation pattern:

js

Copy
function isGeoAnchor_(ctx) {

  return ctx.geo?.geo_id && ctx.person?.person_id && !ctx.place?.place_id;

}
Rule 6 — FUZZY_MATCH (AUTO)
Trigger: scoring ≥ THRESHOLD_AUTO (90).
Action: AUTO_MATCH
Why: names that score ≥ 90 on multiple strategies are statistically the same entity.

Scoring strategy (5 layers, 06_PersonService):

1.
Exact phone match (weight 40)
2.
Exact name match (weight 30)
3.
Exact phonetic key match (weight 15)
4.
Fuzzy name (Levenshtein / Dice, weight 10)
5.
Hybrid context (sold_to_name tie-breaker, weight 5)
Dynamic Weighting (V5.5.046): weights shift based on which signals are present. If phone is missing, name weight increases.

Implementation pattern:

js

Copy
function scorePersonCandidate_(row, candidate) {

  const signals = {

    phone: scorePhone_(row[FACT_IDX.SHIP_TO_PHONE], candidate.phone),

    name: scoreName_(row[FACT_IDX.SHIP_TO_NAME], candidate.canonical_name),

    phonetic: scorePhonetic_(row, candidate),

    fuzzy: scoreFuzzy_(row, candidate),

    context: scoreContext_(row, candidate)

  };

  

  const weights = dynamicWeights_(signals);  // 06_PersonService.dynamicWeights_

  const score = weightedSum_(signals, weights);

  return { score, signals, weights };

}
Rule 7 — ALL_NEW_WITH_GEO (CREATE_NEW)
Trigger: everything is new but has lat/lng.
Action: CREATE_NEW (create master + write to FACT_DELIVERY)
Why: with coordinates, we can create the master confidently.

Implementation pattern:

js

Copy
function isAllNewWithGeo_(ctx) {

  return !ctx.person?.person_id && !ctx.place?.place_id && !ctx.geo?.geo_id

    && ctx.candidateLat && ctx.candidateLng;

}
Rule 8 — DEFAULT (REVIEW)
Trigger: none of the above.
Action: REVIEW (NEEDS_REVIEW)
Why: be conservative — if we can't decide, let a human.

3. The Trinity Framework (Person + Place + Geo)
A Destination is only valid if all 3 FKs resolve.

text

Copy
Person    = 06_PersonService.resolvePerson

             ├─ if exact match by phone → return existing

             ├─ if exact match by name → return existing

             ├─ if exact phonetic match → return existing

             ├─ if fuzzy match (score ≥ threshold) → return existing

             └─ else → return null (caller will CREATE_NEW)


Place     = 07_PlaceService.resolvePlace

             ├─ if exact match by name+address → return existing

             ├─ if exact match by postal code → return existing

             ├─ extract province from address (20_ThGeoService)

             ├─ check if a Place with same name+province exists

             └─ else → return null


Geo       = 08_GeoService.resolveGeo

             ├─ if exact match by lat+lng (within 1m) → return existing

             ├─ if nearby match (within GEO_RADIUS_M) → return existing (Rule 3.5)

             └─ else → return null (caller will CREATE_NEW)


Destination = 09_DestinationService.resolveDestination

             ├─ if Person + Place + Geo all exist → look for existing Destination with this combo

             ├─ if existing Destination found → return it

             └─ else → return null (caller will CREATE_NEW or this becomes a NEEDS_REVIEW)
Why all 3 are required
A "destination" semantically means "this person at this place at this GPS". If any is missing:


Missing Person → "who" is unclear

Missing Place → "where" is unclear

Missing Geo → can't route the truck

When to skip Trinity
For Q_REVIEW rows where the engine can't decide, the human's job is to either:

1.
Confirm all 3 (full approval)
2.
Pick a different Person/Place/Geo (merge)
3.
Decide the data is bad (ignore)
4. Hybrid Alias System
Schema (8 cols)
text

Copy
M_ALIAS

  alias_id (A + 12 hex)

  master_uuid (FK → M_PERSON or M_PLACE)

  variant_name (the spelling/abbreviation)

  entity_type (PERSON | PLACE)

  confidence (0-1)

  source (FACT_DELIVERY | MANUAL | MIGRATION)

  created_at

  last_used
Single-Writer Pattern (HARD)
Only two functions can write to M_ALIAS:

1.
autoEnrichAliasesFromFactBatch_() in 10_MatchEngine.gs — auto pipeline
2.
createGlobalAlias() in 21_AliasService.gs — admin/migration
Anywhere else (Group 2 code, helpers, web app actions) → forbidden.

Self-Healing Alias (Phase 3)
When Q_REVIEW.decision = MERGE_TO_CANDIDATE:

1.
12_ReviewService.applyReviewDecision calls the resolver
2.
Resolver identifies the winning master_uuid and the losing raw name
3.
Calls autoEnrichAliasesFromFactBatch_ (passing the new alias)
4.
New M_ALIAS row: { variant_name: rawName, master_uuid: winner, source: 'FACT_DELIVERY', confidence: 0.8 }
5.
Future matching: raw name → M_ALIAS lookup → winner (O(1))
Confidence scoring

Initial: 0.5 (first time seen)

+0.1 each time alias is used in a successful match (last_used updated)

Cap at 0.95 (always allow human override)

Decay: if alias not used in 90 days, confidence drops by 0.1

Negative samples
SYS_NEGATIVE_SAMPLES (separate sheet) tracks pairs that the admin explicitly rejected. When findPersonCandidates_ runs, it filters out any pair that's in this table. The pair key is (ship_to_name_normalized | candidate_person_id).

5. 5-Strategy Person Search (06_PersonService)
js

Copy
function findPersonCandidates_(row, ctx) {

  const phone = row[FACT_IDX.SHIP_TO_PHONE];

  const name = row[FACT_IDX.SHIP_TO_NAME];

  const soldTo = row[FACT_IDX.SOLD_TO_NAME];  // context

  

  const candidates = [];

  

  // Strategy 1: exact phone

  if (phone) {

    const byPhone = searchByExactPhone_(phone);

    candidates.push(...byPhone.map(c => ({ ...c, strategy: 'phone', score: 100 })));

  }

  

  // Strategy 2: exact name

  if (name) {

    const byName = searchByExactName_(normalizeForCompare(name));

    candidates.push(...byName.map(c => ({ ...c, strategy: 'name', score: 95 })));

  }

  

  // Strategy 3: exact phonetic

  const phoneticKey = buildThaiPhoneticKey(name);

  if (phoneticKey) {

    const byPhonetic = searchByPhoneticKey_(phoneticKey);

    candidates.push(...byPhonetic.map(c => ({ ...c, strategy: 'phonetic', score: 85 })));

  }

  

  // Strategy 4: fuzzy name (Levenshtein / Dice)

  if (name && name.length >= 3) {

    const byFuzzy = searchByFuzzyName_(name, threshold=70);

    candidates.push(...byFuzzy.map(c => ({ ...c, strategy: 'fuzzy', score: c.score })));

  }

  

  // Strategy 5: context (sold_to_name tie-breaker)

  if (soldTo) {

    applyContextTieBreaker_(candidates, soldTo);

  }

  

  // Filter out negative samples

  const negatives = loadNegativeSamples_(name);

  const filtered = candidates.filter(c => !negatives.has(`${normalizeForCompare(name)}|${c.person_id}`));

  

  // Dedupe by person_id, keep highest score

  const deduped = dedupeByPersonId_(filtered);

  

  return deduped;

}
Dynamic Weighting (V5.5.046)
js

Copy
function dynamicWeights_(signals) {

  // If phone is present, weight it heavily; if not, lean on name

  const hasPhone = signals.phone > 0;

  const hasName = signals.name > 0;

  const hasContext = signals.context > 0;

  

  if (hasPhone && hasName && hasContext) {

    return { phone: 40, name: 30, phonetic: 15, fuzzy: 10, context: 5 };

  }

  if (hasPhone && hasName) {

    return { phone: 50, name: 35, phonetic: 10, fuzzy: 5, context: 0 };

  }

  if (hasName && hasContext) {

    return { phone: 0, name: 50, phonetic: 20, fuzzy: 20, context: 10 };

  }

  return { phone: 0, name: 50, phonetic: 25, fuzzy: 25, context: 0 };

}
Contextual Disambiguation (V5.5.047)
When two Person candidates have nearly identical name scores, use sold_to_name as tie-breaker:


If candidate A's last_sold_to matches current sold_to_name → A wins

Else if candidate B's last_sold_to matches → B wins

Else → keep both for review

Geofencing Tie-breaker (V5.5.047)
When 2+ Person candidates match, use the history of deliveries:


For each candidate, count how many of their past destinations are within 1 km of current Geo

The candidate with more nearby history wins (with 0.05 confidence boost)

If tie → review

6. Implementing a New Rule
If you need to add a Rule 9 (e.g. "PRICE_TIER_OVERRIDE" for VIP customers):

js

Copy
// In 10b_MatchDecision.gs:


// 1. Add to the rules table (priority = between 3.5 and 4 to evaluate before FULL_MATCH)

MATCH_RULES.splice(4, 0, {

  name: 'VIP_OVERRIDE',

  priority: 4.5,

  check: isVipOverride_,

  decide: decideVipOverride_

});


// 2. Implement the checker

function isVipOverride_(row, ctx) {

  const soldTo = row[FACT_IDX.SOLD_TO_NAME];

  return CONFIG.VIP_CUSTOMERS?.includes(soldTo) && ctx.geo?.geo_id;

}


// 3. Implement the decider

function decideVipOverride_(row, ctx) {

  // VIP customers get auto-merge even with weak name match

  return {

    action: 'AUTO_MERGE',

    confidence: 88,

    reason: 'VIP customer — auto-merge regardless of name score',

    masterRef: { person_id: ctx.person?.person_id, place_id: ctx.place?.place_id, geo_id: ctx.geo?.geo_id }

  };

}


// 4. Update the runbook in docs/01_SOP_Admin_LMDS.md (mention Rule 9)

// 5. Update README's "8 Rules" section → "9 Rules"

// 6. Bump APP_VERSION to 6.0.045

// 7. Run /REVIEW15 and /BUGHUNT
7. Adding a New Search Strategy (17_SearchService)
If you need a 3rd tier (e.g. "phonetic fallback for misspelled company names"):

js

Copy
// In 17_SearchService.gs:


function findBestGeoByPersonPlace_(shipToName, ctx) {

  // Tier 0: M_ALIAS Fast Track (O(1))

  const fast = fastLookupByShipToName_(shipToName);

  if (fast) return fast;

  

  // Tier 1: Person resolve → destinations

  const person = resolvePerson_(shipToName);

  if (person) {

    const dests = getDestsByPersonId_(person.person_id);

    if (dests.length > 0) return dests[0];

  }

  

  // Tier 2 (new): Phonetic fallback for companies

  if (looksLikeCompanyName_(shipToName)) {

    const phonetic = phoneticLookupByShipToName_(shipToName);

    if (phonetic && phonetic.confidence > 75) return phonetic;

  }

  

  return null;  // NOT_FOUND

}