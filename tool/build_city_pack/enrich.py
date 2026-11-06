"""Section 1B: honest stop labels, spatial transfers and offline FTS places."""
from __future__ import annotations

from collections import Counter, defaultdict
from contextlib import closing
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3

from build import DEFAULT_INPUT, EPSILON_M, Projection, Stop, load_source
from osm_source import OsmData, RoadIndex, read_osm, usable_name

DEFAULT_PBF = Path(__file__).resolve().parents[1] / ".cache/trufi-review/arequipa.osm.pbf"
DEFAULT_DATABASE = Path(__file__).resolve().parent / "output/enrichment.sqlite"
PINNED_PBF_SHA256 = "5d9a5e4295e87dd238b15588c211f4927abe59f98a801ab7d91b30ec58ddd1b2"
SOURCE_REVISION = "9b60aa5cc46e6b8f2dad63079770279c6cb1feb7"
ROAD_LIMIT_M = 50.0
INTERSECTION_LIMIT_M = 200.0
TRANSFER_RADIUS_M = 400.0
WALK_FACTOR = 1.3


def enrich_stop(stop: Stop, index: RoadIndex, used_in_patterns: bool) -> dict:
    row = stop.record()
    row.update({"original_name": stop.name, "used_in_patterns": used_in_patterns,
                "source_kind": "generated_virtual" if stop.virtual else "gtfs_candidate",
                "official_name_verified": False})
    if usable_name(stop.name or "") and not stop.virtual:
        row.update({"name_source": "gtfs_source", "needs_review": False, "name_evidence": {}})
        return row
    name, evidence = index.name_for(stop.latitude, stop.longitude,
                                    ROAD_LIMIT_M, INTERSECTION_LIMIT_M)
    if name:
        source, needs_review = "osm_road_intersection", False
    elif evidence["road_distance_m"] <= ROAD_LIMIT_M + EPSILON_M:
        name = f"Cerca de {evidence['road_name']} (punto estimado)"
        source, needs_review = "osm_road", True
    else:
        name = f"Punto de subida estimado {stop.identifier}"
        source, needs_review = "estimated_id", True
    row.update({"name": name, "name_source": source, "needs_review": needs_review,
                "name_evidence": evidence})
    return row


def transfer_pairs(stops: list[dict], projection: Projection, statistics: dict | None = None,
                   radius_m: float = TRANSFER_RADIUS_M, walk_factor: float = WALK_FACTOR):
    if radius_m <= 0 or not math.isfinite(radius_m) or walk_factor < 1 or not math.isfinite(walk_factor):
        raise ValueError("Invalid transfer radius or walking factor")
    identifiers = [stop["stop_id"] for stop in stops]
    if len(set(identifiers)) != len(identifiers):
        raise ValueError("Duplicate stop IDs in transfer input")
    stats = statistics if statistics is not None else {}
    stats.update({"distance_evaluations": 0, "pair_count": 0,
                  "all_possible_pairs": len(stops) * (len(stops) - 1) // 2})
    grid = defaultdict(list)
    for stop in sorted(stops, key=lambda value: value["stop_id"]):
        x, y = projection.forward(stop["latitude"], stop["longitude"])
        cell_x, cell_y = math.floor(x / radius_m), math.floor(y / radius_m)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for other_id, other_x, other_y in grid.get((cell_x + dx, cell_y + dy), ()):
                    stats["distance_evaluations"] += 1
                    distance = math.hypot(x - other_x, y - other_y)
                    if distance <= radius_m + EPSILON_M:
                        stats["pair_count"] += 1
                        yield (other_id, stop["stop_id"], round(distance, 6),
                               round(distance * walk_factor, 6))
        grid[cell_x, cell_y].append((stop["stop_id"], x, y))


def search_places(connection: sqlite3.Connection, text: str, limit: int = 20) -> list[dict]:
    if not 1 <= limit <= 100:
        raise ValueError("Search limit must be between 1 and 100")
    tokens = re.findall(r"[^\W_]+", text, flags=re.UNICODE)[:12]
    if not tokens:
        return []
    expression = " AND ".join('"' + token + '"*' for token in tokens)
    cursor = connection.execute("""
        SELECT p.place_id,p.name,p.category,p.latitude,p.longitude,p.osm_type,p.osm_id
        FROM places_fts JOIN places p ON p.id=places_fts.rowid
        WHERE places_fts MATCH ? ORDER BY bm25(places_fts),p.place_id LIMIT ?
        """, (expression, limit))
    names = [column[0] for column in cursor.description]
    return [dict(zip(names, row)) for row in cursor]


def create_schema(db: sqlite3.Connection) -> None:
    db.executescript("""
        PRAGMA foreign_keys=ON;
        PRAGMA user_version=1;
        CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE stops(
            stop_id TEXT PRIMARY KEY,name TEXT NOT NULL CHECK(length(trim(name))>0),
            original_name TEXT,latitude REAL NOT NULL,longitude REAL NOT NULL,
            source_kind TEXT NOT NULL CHECK(source_kind IN ('gtfs_candidate','generated_virtual')),
            used_in_patterns INTEGER NOT NULL CHECK(used_in_patterns IN (0,1)),
            official_name_verified INTEGER NOT NULL CHECK(official_name_verified=0),
            name_source TEXT NOT NULL CHECK(name_source IN ('gtfs_source','osm_road_intersection','osm_road','estimated_id')),
            needs_review INTEGER NOT NULL CHECK(needs_review IN (0,1)),
            name_evidence_json TEXT NOT NULL
        );
        CREATE TABLE transfers(
            stop_a TEXT NOT NULL REFERENCES stops(stop_id),
            stop_b TEXT NOT NULL REFERENCES stops(stop_id),
            direct_distance_m REAL NOT NULL CHECK(direct_distance_m>=0 AND direct_distance_m<=400.000002),
            walk_distance_m REAL NOT NULL CHECK(walk_distance_m>=0 AND walk_distance_m<=520.000002),
            PRIMARY KEY(stop_a,stop_b),CHECK(stop_a<stop_b)
        ) WITHOUT ROWID;
        CREATE INDEX transfers_to ON transfers(stop_b);
        CREATE VIEW transfer_edges AS
            SELECT stop_a AS from_stop_id,stop_b AS to_stop_id,direct_distance_m,walk_distance_m FROM transfers
            UNION ALL
            SELECT stop_b,stop_a,direct_distance_m,walk_distance_m FROM transfers;
        CREATE TABLE places(
            id INTEGER PRIMARY KEY,place_id TEXT UNIQUE NOT NULL,name TEXT NOT NULL,
            category TEXT NOT NULL,latitude REAL NOT NULL,longitude REAL NOT NULL,
            osm_type TEXT NOT NULL,osm_id INTEGER NOT NULL,coordinate_source TEXT NOT NULL,
            aliases TEXT NOT NULL,address TEXT NOT NULL,tags_json TEXT NOT NULL
        );
        CREATE VIRTUAL TABLE places_fts USING fts5(name,aliases,address,
            content='places',content_rowid='id',tokenize='unicode61 remove_diacritics 2');
    """)


def validate_database(db: sqlite3.Connection, expected_stops: int) -> dict:
    if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
        raise ValueError("SQLite integrity check failed")
    if db.execute("PRAGMA foreign_key_check").fetchone() is not None:
        raise ValueError("Broken transfer reference")
    rows = db.execute("SELECT name FROM stops").fetchall()
    if len(rows) != expected_stops or any(not usable_name(row[0]) for row in rows):
        raise ValueError("There are missing, empty or unnamed stops")
    db.execute("INSERT INTO places_fts(places_fts,rank) VALUES('integrity-check',1)")
    tecsup = search_places(db, "tecsup")
    if not any(row["category"] == "institute" for row in tecsup):
        raise ValueError("The OSM extract does not provide a searchable TECSUP institute")
    return {"unnamed_stops": 0, "quick_check": "ok", "foreign_key_check": "ok",
            "fts_integrity": "ok", "tecsup_results": tecsup}


def save_database(output: Path, stops: list[dict], data: OsmData,
                  projection: Projection, provenance: dict) -> dict:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    stats = {}
    try:
        with closing(sqlite3.connect(temporary)) as db:
            create_schema(db)
            with db:
                db.executemany("INSERT INTO stops VALUES(?,?,?,?,?,?,?,?,?,?,?)", [
                    (s["stop_id"],s["name"],s["original_name"],s["latitude"],s["longitude"],
                     s["source_kind"],int(s["used_in_patterns"]),0,s["name_source"],
                     int(s["needs_review"]),json.dumps(s["name_evidence"],ensure_ascii=False,sort_keys=True))
                    for s in stops])
                # Table has eleven columns; exact parameter count is checked by SQLite.
                db.executemany("INSERT INTO transfers VALUES(?,?,?,?)",
                               transfer_pairs(stops, projection, stats))
                for position, place in enumerate(data.places, start=1):
                    tags = place["tags"]
                    aliases = " ; ".join(dict.fromkeys(tags[key] for key in
                        ("alt_name","short_name","official_name","name:es","name:en") if tags.get(key)))
                    address = " ".join(tags[key] for key in
                        ("addr:street","addr:housenumber","addr:suburb","addr:city") if tags.get(key))
                    db.execute("INSERT INTO places VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", (
                        position,place["place_id"],place["name"],place["category"],place["latitude"],
                        place["longitude"],place["osm_type"],place["osm_id"],place["coordinate_source"],
                        aliases,address,json.dumps(tags,ensure_ascii=False,sort_keys=True)))
                db.execute("INSERT INTO places_fts(places_fts) VALUES('rebuild')")
                validation = validate_database(db, len(stops))
                summary = {
                    "stage": "1B_enrichment", "stop_count": len(stops),
                    "source_kinds": dict(sorted(Counter(s["source_kind"] for s in stops).items())),
                    "naming": dict(sorted(Counter(s["name_source"] for s in stops).items())),
                    "stops_needing_review": sum(s["needs_review"] for s in stops),
                    "places": len(data.places),
                    "place_categories": dict(sorted(Counter(p["category"] for p in data.places).items())),
                    "transfers": stats, "osm_processing": data.counts,
                    "osm_named_roads": len(data.roads), "osm_tagged_stop_nodes": len(data.inventory),
                    "validation": validation,
                }
                metadata = {"schema_version": 1, "provenance": provenance, "summary": summary,
                            "distance_model": {"type": "local_equirectangular",
                                "latitude_origin":projection.latitude,"longitude_origin":projection.longitude},
                            "naming_limits_m": {"road":ROAD_LIMIT_M,"intersection":INTERSECTION_LIMIT_M},
                            "transfer_model": {"radius_m":TRANSFER_RADIUS_M,"walk_factor":WALK_FACTOR},
                            "attribution": "OpenStreetMap contributors; ODbL 1.0; https://www.openstreetmap.org/copyright"}
                db.executemany("INSERT INTO metadata VALUES(?,?)", [
                    (key,json.dumps(value,ensure_ascii=False,sort_keys=True)) for key,value in metadata.items()])
        temporary.replace(output)
        summary["database_bytes"] = output.stat().st_size
        summary["database_sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
        return summary
    except Exception:
        if temporary.exists():
            temporary.unlink()
        raise


def run_enrichment(document: dict, input_directory: Path = DEFAULT_INPUT,
                   pbf: Path = DEFAULT_PBF, output: Path = DEFAULT_DATABASE) -> dict:
    input_directory, pbf, output = input_directory.resolve(), pbf.resolve(), output.resolve()
    if input_directory in output.parents or output == pbf:
        raise ValueError("Enrichment output must not overwrite input data")
    if not pbf.is_file():
        raise ValueError(f"Missing OSM extract: {pbf}; no data will be invented")
    digest = hashlib.sha256(pbf.read_bytes()).hexdigest()
    if pbf == DEFAULT_PBF.resolve() and digest != PINNED_PBF_SHA256:
        raise ValueError("The cached OSM extract no longer matches the pinned source")
    for name, expected in document["source_sha256"].items():
        if hashlib.sha256((input_directory / name).read_bytes()).hexdigest() != expected:
            raise ValueError("Input changed since pattern generation: " + name)
    stops, shapes, _, projection, _ = load_source(input_directory)
    used = {row["stop_id"] for pattern in document["patterns"] for row in pattern["stops"]}
    lookup = {stop.identifier: stop for stop in stops}
    for row in document["stops"]:
        if row["is_virtual"]:
            lookup[row["stop_id"]] = Stop(row["stop_id"],None,row["latitude"],row["longitude"],True)
    all_stops = sorted(lookup.values(), key=lambda stop: stop.identifier)
    points = [(s.latitude,s.longitude) for s in all_stops]
    points.extend(projection.inverse(*point) for shape in shapes.values() for point in shape.points)
    bbox = (min(p[0] for p in points)-.01,min(p[1] for p in points)-.01,
            max(p[0] for p in points)+.01,max(p[1] for p in points)+.01)
    print("Reading OSM extract and checking named roads...", flush=True)
    data = read_osm(pbf, bbox)
    index = RoadIndex(data.roads, projection)
    named = [enrich_stop(stop,index,stop.identifier in used) for stop in all_stops]
    provenance = {"osm_pbf_sha256":digest,"source_sha256":document["source_sha256"],"bbox":bbox,
                  "point_semantics":"GTFS candidates and generated virtuals; not physically verified stops"}
    if digest == PINNED_PBF_SHA256:
        provenance["osm_source"] = {
            "repository":"trufi-association/trufi-arequipa","revision":SOURCE_REVISION,
            "path":"Backend-Services/otp/data/arequipa.osm.pbf",
            "extract_date_declared_by_upstream_commit":"2026-10-18"}
    for name, expected in document["source_sha256"].items():
        if hashlib.sha256((input_directory / name).read_bytes()).hexdigest() != expected:
            raise ValueError("Input changed during enrichment: " + name)
    print("Building spatial transfers and SQLite FTS5...", flush=True)
    summary = save_database(output,named,data,projection,provenance)
    report = output.with_suffix(".report.json")
    temporary_report = report.with_suffix(report.suffix + ".tmp")
    temporary_report.write_text(json.dumps(summary,ensure_ascii=True,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    temporary_report.replace(report)
    print(json.dumps(summary,ensure_ascii=True,indent=2), flush=True)
    return summary
