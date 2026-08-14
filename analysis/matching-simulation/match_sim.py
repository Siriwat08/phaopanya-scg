"""
LMDS Match Simulation — จำลอง pipeline จับคู่ของระบบ LMDS V6.0 ด้วยข้อมูลจริง
================================================================================
กลยุทธ์การจำลอง (Data-Driven Approach):
  - ระบบ LMDS เป็น self-learning: Master (M_PERSON/M_PLACE/M_GEO_POINT)
    ถูกสร้างขึ้นมาจากข้อมูลเดือนแรก แล้วเดือนต่อๆ ไปจะ match กับ master ได้
  - จึงจำลองด้วย train/test ตัดตามเดือน:
      training = แถวที่ QC != '' (ข้อมูลส่วนใหญ่ = ก.พ.-เม.ย. 2026)
      ที่ใช้เป็น "master reference": กลุ่ม unique (person key, place key, geo key)
      test     = แถว QC = WARNING + ส่วน PASS สุ่ม
  - Key ที่ใช้ match (จำลอง normalize อย่างง่าย):
      PERSON: (ชื่อปลายนทาง, อีเมล/โทรที่สกัดจากชื่อ, รหัสลูกค้า)
      PLACE:  (ที่อยู่ปลายนทาง normalised, province)
      GEO:    haversine เทียบ geo point เด่น (lat,lng เฉลี่ย) radius 100m
  - ตัดสินใจตาม rules 1-8 ใน makeMatchDecision():
      Rule 4:FOUND ทั้ง 3 → AUTO_MATCH
      Rule 5:geo+person → AUTO_MATCH
      Rule 6:fuzzy → REVIEW
      Rule 7/8:มี GPS แต่ไม่เจอ master → CREATE_NEW
      ไม่มี GPS → REVIEW_NOGEO
Output: match_report.md + match_result.csv
"""
import csv
import math
import re
import random
from collections import Counter, defaultdict

SRC = "SCGนครหลวงJWDภูมิภาค_SCHEMA_V4.0_เต็ม.csv"

# ---------------------------------------------------------------- constants
GEO_RADIUS_M = 100
NEARBY_YELLOW = 120
NEARBY_ORANGE = 150
TH_PROVINCES = {
    "นครปฐม", "นนทบุรี", "ปทุมธานี", "พิษณุโลก", "พรหมบุรี", "พระนครศรีอยุทธยา",
    "พิจิตร", "เพชรบุรี", "เพชรบูรณ์", "แพร่", "ฟาร์ม", "ภูเก็ต", "มหาสารคาม",
    "มุกดาหาร", "ยะลา", "ยโสธร", "ร้อยเอ็ด", "ระนอง", "ระยอง", "ราชบุรี",
    "ลบุรี", "ลำปาง", "ลำพูน", "เลย", "ศรีสะเกษ", "สกลนคร", "สงขลา",
    "สตูล", "สมุทรปราการ", "สมุทรสงคราม", "สมุทรสาคร", "สระแก้ว", "สระบุรี",
    "สิงห์บุรี", "สุโขทัย", "สุพรรณบุรี", "สุราษฎร์ธานี", "สุรินทร์", "หนองคาย",
    "หนองบัวลำภู", "อ่างทอง", "อุบลราชธานี", "อุดรธานี", "อุทัยธานี", "อำนาจเจริญ",
}
BKK_ZONE = "กรุงเทพมหานคร"

# ---------------------------------------------------------------- helpers
TH_MAP = {"๐": "0", "๑": "1", "๒": "2", "๓": "3", "๔": "4", "๕": "5",
          "๖": "6", "๗": "7", "๘": "8", "๙": "9"}

def th2en(s):
    for a, b in TH_MAP.items():
        s = s.replace(a, b)
    return s

def norm(s):
    if not s:
        return ""
    s = th2en(str(s))
    s = s.lower()
    s = re.sub(r"[๐-๙]", lambda m: TH_MAP[m.group(0)], s)
    s = re.sub(r"\d", "", s)              # ตัดเลขออก (เลขที่บ้าน/ห้อง)
    s = re.sub(r"[^ก-๛a-z0-9 ]", " ", s)  # ตัดปัจจัย/เครื่องหมาย
    s = re.sub(r"\s+", " ", s).strip()
    return s

def extract_phone(s):
    m = re.search(r"0\d{8,9}", th2en(str(s)))
    return m.group(0) if m else None

def extract_email(s):
    m = re.search(r"[\w.-]+@[\w.-]+\.\w+", str(s))
    return m.group(0).lower() if m else None

def haversine_m(lat1, lng1, lat2, lng2):
    R = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))

def geo_in_th(lat, lng):
    return 5.5 <= lat <= 20.5 and 97.5 <= lng <= 105.7

def extract_province(addr):
    a = norm(addr)
    if not a:
        return ""
    # กทม variants
    for g in ["กรุงเทพ", "กรุงเทพ", "กทม", "กรุงเทพมหานคร", "กทม "]:
        if g in a:
            return BKK_ZONE
    for p in TH_PROVINCES:
        if norm(p) in a or p in a:
            return p
    return ""

# ---------------------------------------------------------------- load
def load():
    with open(SRC, encoding="utf-8-sig") as f:
        r = csv.reader(f)
        header = next(r)
        rows = list(r)
    data = []
    for row in rows:
        while len(row) < 39:
            row.append("")
        lat, lng = "", ""
        try:
            lat = float(row[14])
            lng = float(row[15])
        except (ValueError, TypeError):
            pass
        data.append({
            "invoice": row[8],
            "shipment": row[7],
            "customer_code": row[10],
            "name": row[12],
            "driver": row[5],
            "email": row[13],
            "lat": lat, "lng": lng,
            "addr": row[18],
            "qc": row[33].strip(),
            "issue": row[34].strip(),
            "month": row[21][:7],
            "row": row,
        })
    return data

MONTH_RE = re.compile(r"\b(\d{1,2})/(\d{1,2})/(\d{4})\b")

def parse_month(row):
    m = MONTH_RE.search(row[2])
    if m:
        return f"{m.group(3)}-{int(m.group(2)):02d}"
    return "UNKNOWN"

def build_master(train):
    """สร้าง master reference จากข้อมูล training (unique destinations)"""
    # PERSON master: key = (name, phone, customer_code)
    person_master = defaultdict(lambda: {"count": 0, "name": "", "phone": None, "code": ""})
    # PLACE master: key = (place_key, province)
    place_master = defaultdict(lambda: {"count": 0, "addr": "", "province": ""})
    # GEO master: geo_id → (lat, lng, count); grid cell 0.001
    geo_cells = defaultdict(lambda: {"sl": 0.0, "sg": 0.0, "n": 0})
    for d in train:
        # person
        if d["name"]:
            key = (norm(d["name"]), extract_phone(d["name"]), d["customer_code"])
            p = person_master[key]
            p["count"] += 1
            if p["count"] == 1:
                p["name"], p["phone"], p["code"] = d["name"], extract_phone(d["name"]), d["customer_code"]
        # place
        prov = extract_province(d["addr"])
        if d["addr"]:
            key = (norm(d["addr"]), prov)
            p = place_master[key]
            p["count"] += 1
            if p["count"] == 1:
                p["addr"], p["province"] = d["addr"], prov
        # geo
        if d["lat"] and d["lng"] and geo_in_th(d["lat"], d["lng"]):
            cell = (round(d["lat"], 3), round(d["lng"], 3))
            c = geo_cells[cell]
            c["sl"] += d["lat"]
            c["sg"] += d["lng"]
            c["n"] += 1
    return person_master, place_master, geo_cells

def match_geo(lat, lng, geo_cells):
    if not lat or not lng or not geo_in_th(lat, lng):
        return {"status": "INVALID" if (lat and lng) else "NO_GEO", "dist": -1}
    best, best_dist = None, 1e9
    for (clat, clng), c in geo_cells.items():
        cl, cg = c["sl"] / c["n"], c["sg"] / c["n"]
        dist = haversine_m(lat, lng, cl, cg)
        if dist < best_dist:
            best_dist, best = dist, (cl, cg)
    if best is None:
        return {"status": "NOT_FOUND", "dist": -1}
    d = round(best_dist)
    if d <= GEO_RADIUS_M:
        return {"status": "FOUND", "dist": d, "conf": max(0, min(100, round(100 - (d / GEO_RADIUS_M) * 30)))}
    if d <= NEARBY_YELLOW:
        return {"status": "NEARBY_PENDING", "dist": d, "issue": "YELLOW"}
    if d <= NEARBY_ORANGE:
        return {"status": "NEARBY_PENDING", "dist": d, "issue": "ORANGE"}
    return {"status": "NOT_FOUND", "dist": d}

def match_person(d, person_master):
    name = d["name"]
    if not name or len(norm(name)) < 2:
        return {"status": "LOW_QUALITY"}
    keys = []
    phone = extract_phone(name)
    email = extract_email(name)
    for k, p in person_master.items():
        k_norm, k_phone, k_code = k
        score = 0
        if k_norm and k_norm == norm(name):
            score = 95
            if k_phone and k_phone == phone:
                score = 100
        elif k_norm and k_phone and phone and k_phone == phone:
            score = 90
        elif k_code and k_code == d["customer_code"] and d["customer_code"]:
            score = 80
        if score > 0:
            keys.append((score, k, p))
    if not keys:
        return {"status": "NOT_FOUND", "dist": -1}
    keys.sort(key=lambda t: t[0], reverse=True)
    top, k, p = keys[0]
    if len(keys) > 1 and keys[0][0] == keys[1][0]:
        return {"status": "NEEDS_REVIEW", "score": top}
    if top >= 85:
        return {"status": "FOUND", "score": top}
    if top >= 70:
        return {"status": "NEEDS_REVIEW", "score": top}
    return {"status": "NOT_FOUND", "dist": -1}

def match_place(d, place_master):
    addr = d["addr"]
    if not addr or len(norm(addr)) < 2:
        return {"status": "LOW_QUALITY"}
    prov = extract_province(addr)
    keys = []
    for k, p in place_master.items():
        k_norm, k_prov = k
        score = 0
        if k_norm and k_norm == norm(addr):
            score = 95
            if k_prov and k_prov == prov and prov:
                score = 100
        if score > 0:
            keys.append((score, p))
    if not keys:
        return {"status": "NOT_FOUND", "dist": -1}
    keys.sort(reverse=True)
    top, p = keys[0]
    if top >= 85:
        return {"status": "FOUND", "score": top, "province": p["province"]}
    if top >= 70:
        return {"status": "NEEDS_REVIEW", "score": top}
    return {"status": "NOT_FOUND", "dist": -1}

def decide(has_geo, p_res, pl_res, g_res, src_province=""):
    """Replica of makeMatchDecision (rules 1-8)"""
    # Rule 1: ไม่มีพิกัด
    if not has_geo:
        return {"action": "REVIEW", "reason": "REVIEW_NOGEO", "conf": 0}
    # Rule 2: LOW_QUALITY
    if p_res["status"] == "LOW_QUALITY" or pl_res["status"] == "LOW_QUALITY":
        return {"action": "REVIEW", "reason": "LOW_QUALITY", "conf": 0}
    # Rule 3: จังหวัดข้ามโซน — เทียบ master province กับจังหวัดจากที่อยู่ของ row
    if src_province and g_res["status"] == "FOUND" and pl_res.get("province"):
        if pl_res["province"] and pl_res["province"] != src_province:
            return {"action": "REVIEW", "reason": "PROVINCE_CONFLICT", "conf": 50}
    # Rule 3.5: NEARBY_PENDING
    if g_res["status"] == "NEARBY_PENDING":
        return {"action": "REVIEW", "reason": g_res.get("issue", "GEO_NEARBY"), "conf": 0}
    # Rule 4: ครบทั้ง 3
    if g_res["status"] == "FOUND" and p_res["status"] == "FOUND" and pl_res["status"] == "FOUND":
        return {"action": "AUTO_MATCH", "reason": "FULL_MATCH", "conf": 95}
    # Rule 5: geo + person
    if g_res["status"] == "FOUND" and p_res["status"] == "FOUND":
        conf = 80
        if g_res.get("dist", 0) > 50:
            conf = 75
        if g_res.get("dist", 0) > 1000:
            return {"action": "REVIEW", "reason": "GEO_ANCHOR_FAR", "conf": conf}
        return {"action": "AUTO_MATCH", "reason": "GEO_ANCHOR", "conf": conf}
    # Rule 5b: geo + place only
    if g_res["status"] == "FOUND" and pl_res["status"] == "FOUND":
        return {"action": "REVIEW", "reason": "GEO_PLACE_NO_NAME", "conf": 60}
    # Rule 6: fuzzy
    if p_res["status"] == "NEEDS_REVIEW" or pl_res["status"] == "NEEDS_REVIEW":
        return {"action": "REVIEW", "reason": "FUZZY_NEEDS_REVIEW", "conf": p_res.get("score") or pl_res.get("score") or 70}
    # Rule 7/8: GPS จริง ไม่เจอ master
    return {"action": "CREATE_NEW", "reason": "NEW_DESTINATION", "conf": 0}

def simulate(train, test):
    pm, plm, gc = build_master(train)
    results = []
    for d in test:
        has_geo = bool(d["lat"] and d["lng"] and geo_in_th(d["lat"], d["lng"]))
        p_res = match_person(d, pm)
        pl_res = match_place(d, plm)
        g_res = match_geo(d["lat"], d["lng"], gc) if has_geo else {"status": "NO_GEO", "dist": -1}
        dec = decide(has_geo, p_res, pl_res, g_res, extract_province(d["addr"]))
        results.append({
            "invoice": d["invoice"], "name": d["name"][:40], "addr": d["addr"][:60],
            "lat": d["lat"], "lng": d["lng"], "month": d["month"], "qc": d["qc"],
            "person": p_res["status"], "place": pl_res["status"],
            "geo": g_res["status"], "geo_dist": g_res.get("dist", -1),
            "action": dec["action"], "reason": dec["reason"], "conf": dec["conf"],
        })
    return results, pm, plm, gc

def main():
    random.seed(42)
    data = load()
    for d in data:
        d["month"] = parse_month(d["row"])
    print("total rows:", len(data))
    print("month dist:", Counter(d["month"] for d in data).most_common())

    months_sorted = sorted(m for m in set(d["month"] for d in data) if m != "UNKNOWN")
    print("months:", months_sorted)
    train = [d for d in data if d["month"] in months_sorted[:2]]
    test = [d for d in data if d["month"] not in months_sorted[:2]]
    if len(test) < 500:
        train, test = data[: int(len(data) * 0.8)], data[int(len(data) * 0.8):]
    print("train:", len(train), "test:", len(test))

    results, pm, plm, gc = simulate(train, test)
    actions = Counter(r["action"] for r in results)
    print("\n=== MATCH RESULTS (test set) ===")
    for a, c in actions.most_common():
        print(f"  {a}: {c} ({c/len(results)*100:.1f}%)")
    reasons = Counter(r["reason"] for r in results if r["action"] != "AUTO_MATCH")
    print("\n=== NON-AUTO REASONS ===")
    for a, c in reasons.most_common(10):
        print(f"  {a}: {c}")
    statuses = Counter((r["person"], r["place"], r["geo"]) for r in results)
    print("\n=== TOP (person, place, geo) combos ===")
    for k, c in statuses.most_common(8):
        print(f"  {k}: {c}")

    # month breakdown
    print("\n=== BY MONTH ===")
    bymonth = defaultdict(Counter)
    for r in results:
        bymonth[r["month"]][r["action"]] += 1
    for m in sorted(bymonth):
        tot = sum(bymonth[m].values())
        auto = bymonth[m].get("AUTO_MATCH", 0)
        print(f"  {m}: total={tot}, AUTO={auto} ({auto/tot*100:.0f}%), REVIEW={bymonth[m].get('REVIEW',0)}, CREATE_NEW={bymonth[m].get('CREATE_NEW',0)}")

    # incremental learning: train accumulates เดือนจริง
    print("\n=== INCREMENTAL LEARNING (train months accumulate) ===")
    real_months = [m for m in sorted(set(d["month"] for d in data)) if m != "UNKNOWN"]
    for m in real_months[1:]:
        acc = [d for d in data if d["month"] <= m]
        tst = [d for d in data if d["month"] > m][:600]
        if not tst:
            break
        r2, _, _, _ = simulate(acc, tst)
        auto = sum(1 for x in r2 if x["action"] == "AUTO_MATCH")
        rev = sum(1 for x in r2 if x["action"] == "REVIEW")
        new = sum(1 for x in r2 if x["action"] == "CREATE_NEW")
        print(f"  master upto {m} → later: AUTO={auto/len(r2)*100:.0f}%, REVIEW={rev/len(r2)*100:.0f}%, NEW={new/len(r2)*100:.0f}%")

    # geo coverage
    gc_count = sum(v["n"] for v in gc.values())
    print(f"\nmaster stats: persons={len(pm)}, places={len(plm)}, geo_cells={len(gc)} (rows={gc_count})")

    # save results
    out = "match_result_testset.csv"
    with open(out, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)
    print("saved:", out, len(results), "rows")

if __name__ == "__main__":
    main()
