"""Section 1C: simplified shapes, editable config and a validated city pack."""
from __future__ import annotations

from bisect import bisect_left
from collections import defaultdict
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3

from build import ROOT, Projection, Shape, coordinates, project_segment, read_csv
from enrich import search_places

DEFAULT_CONFIG = Path(__file__).resolve().parent / "config/arequipa.json"
DEFAULT_ASSETS = ROOT / "assets/city/arequipa"


def canonical(value) -> str:
    return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"),allow_nan=False)


def minute(value: str) -> int:
    if not re.fullmatch(r"(?:[01][0-9]|2[0-3]):[0-5][0-9]",value):
        raise ValueError(f"Invalid clock time: {value}")
    hour,minutes = map(int,value.split(":"))
    return hour*60+minutes


def band_contains(band: dict, value: int) -> bool:
    start,end=minute(band["start"]),minute(band["end"])
    return start<=value<end if start<end else value>=start or value<end


def validate_config(config: dict) -> None:
    if config.get("city_code")!="arequipa" or config.get("timezone")!="America/Lima":
        raise ValueError("This source dataset requires Arequipa and America/Lima")
    if type(config.get("data_version")) is not int or config["data_version"]<1:
        raise ValueError("Data version must be a positive integer")
    positive=[config.get(key) for key in ("geometry_tolerance_m","walking_speed_m_per_min",
                                        "access_max_m","access_fallback_max_m")]
    if any(type(value) not in (int,float) or not math.isfinite(value) or value<=0 for value in positive):
        raise ValueError("Geometry, walking and access settings must be positive numbers")
    if config["access_fallback_max_m"]<config["access_max_m"]:
        raise ValueError("Fallback access radius must not be smaller than the initial radius")
    bands=config["speed_bands"]
    for band in bands:
        if minute(band["start"])==minute(band["end"]):
            raise ValueError("An empty or full-day speed band is ambiguous")
        speed=band["speed_kmh"]
        if speed is not None and (type(speed) not in (int,float) or not math.isfinite(speed) or speed<=0):
            raise ValueError("A service speed must be positive; use null for no service")
    if any(sum(band_contains(band,value) for band in bands)!=1 for value in range(1440)):
        raise ValueError("Speed bands must cover each minute once without gaps or overlaps")
    frequencies=config["frequency_minutes_by_period"]
    if set(frequencies)!={"peak","off_peak","night"} or any(type(v) not in (int,float)
            or not math.isfinite(v) or v<=0 for v in frequencies.values()):
        raise ValueError("Expected positive peak, off_peak and night frequencies")
    frequency_bands=config.get("frequency_bands")
    if frequency_bands is not None:
        for band in frequency_bands:
            if minute(band["start"])==minute(band["end"]) or band["period"] not in (*frequencies,None):
                raise ValueError("Invalid frequency band")
        for value in range(1440):
            active=[band for band in frequency_bands if band_contains(band,value)]
            if len(active)!=1:
                raise ValueError("Frequency bands must cover each minute once")
            speed=next(band["speed_kmh"] for band in bands if band_contains(band,value))
            if (active[0]["period"] is None)!=(speed is None):
                raise ValueError("Frequency and speed service hours disagree")
    fare=config["default_fare"]
    amounts=[fare["amount"],*config["line_fare_overrides"].values()]
    if fare["currency"]!="PEN" or any(type(v) not in (int,float) or not math.isfinite(v) or v<0 for v in amounts):
        raise ValueError("Fares must be finite nonnegative PEN amounts")


def simplify_indices(points: list[tuple[float,float]], tolerance: float) -> list[int]:
    if len(points)<2 or tolerance<=0 or not math.isfinite(tolerance):
        raise ValueError("Simplification requires two points and a positive tolerance")
    kept={0,len(points)-1}
    pending=[(0,len(points)-1)]
    while pending:
        start,end=pending.pop()
        if end-start<2:
            continue
        maximum,index=-1.0,None
        for position in range(start+1,end):
            distance=project_segment(points[position],points[start],points[end])[1]
            if distance>maximum:
                maximum,index=distance,position
        if maximum>tolerance:
            kept.add(index)
            pending.extend(((start,index),(index,end)))
    return sorted(kept)


def maximum_deviation(points,indices) -> float:
    maximum=0.0
    for left,right in zip(indices,indices[1:]):
        for position in range(left+1,right):
            maximum=max(maximum,project_segment(points[position],points[left],points[right])[1])
    return maximum


def build_geometry(directory: Path, document: dict, tolerance: float):
    routes=read_csv(directory/"routes.txt",{"route_id","route_short_name","route_long_name","route_color","agency_id"})
    trips=read_csv(directory/"trips.txt",{"route_id","shape_id"})
    rows=read_csv(directory/"shapes.txt",{"shape_id","shape_pt_sequence","shape_pt_lat","shape_pt_lon"})
    model=document["distance_model"]
    projection=Projection(model["latitude_origin"],model["longitude_origin"])
    raw=defaultdict(dict)
    for row in rows:
        sequence=int(row["shape_pt_sequence"])
        if sequence in raw[row["shape_id"]]:raise ValueError("Duplicate shape sequence")
        raw[row["shape_id"]][sequence]=coordinates(row["shape_pt_lat"],row["shape_pt_lon"])
    route_shapes=defaultdict(set)
    for trip in trips:route_shapes[trip["route_id"]].add(trip["shape_id"])
    shape_records={}
    original_count=simplified_count=0
    largest_deviation=0.0
    for shape_id,points_by_sequence in sorted(raw.items()):
        shape=Shape(shape_id,[points_by_sequence[key] for key in sorted(points_by_sequence)],projection)
        kept=simplify_indices(shape.points,tolerance)
        deviation=maximum_deviation(shape.points,kept)
        if deviation>tolerance+1e-6:raise ValueError("Simplification exceeded its tolerance")
        geometry={"type":"LineString","coordinates":[
            [round(projection.inverse(*shape.points[index])[1],10),
             round(projection.inverse(*shape.points[index])[0],10)] for index in kept]}
        shape_records[shape_id]={"shape_id":shape_id,"geometry":geometry,
            "vertex_distances_m":[round(shape.cumulative[index],6) for index in kept],
            "original_points":len(points_by_sequence),"simplified_points":len(kept),
            "length_m":round(shape.length,6),"max_deviation_m":round(deviation,6)}
        original_count+=len(points_by_sequence);simplified_count+=len(kept)
        largest_deviation=max(largest_deviation,deviation)
    network=json.loads((directory/"network.json").read_text(encoding="utf-8-sig"))
    line_records=[{"line_id":line["id"],"name":line["short_name"],"color":line["color"]} for line in network]
    mapped={direction["route_id"]:(line,direction) for line in network for direction in line["directions"]}
    features=[]
    for route in sorted(routes,key=lambda row:row["route_id"]):
        if len(route_shapes[route["route_id"]])!=1:raise ValueError("A route needs one unambiguous shape")
        shape_id=next(iter(route_shapes[route["route_id"]]))
        if shape_id not in shape_records:raise ValueError("Unknown route shape")
        raw_color=route["route_color"].lstrip("#")
        if not re.fullmatch(r"[0-9A-Fa-f]{6}",raw_color):raise ValueError("Invalid route color")
        mapping=mapped.get(route["route_id"])
        properties={"route_id":route["route_id"],"shape_id":shape_id,
            "route_color":"#"+raw_color.upper(),"short_name":route["route_short_name"],
            "long_name":route["route_long_name"],"agency_id":route["agency_id"],
            "line_id":mapping[0]["id"] if mapping else None,
            "direction":mapping[1]["kind"] if mapping else None,
            "headsign":mapping[1]["headsign"] if mapping else None,
            "pattern_available":mapping is not None}
        features.append({"type":"Feature","id":route["route_id"],"properties":properties,
                         "geometry":shape_records[shape_id]["geometry"]})
    for pattern in document["patterns"]:
        if abs(pattern["length_m"]-shape_records[pattern["shape_id"]]["length_m"])>1e-5:
            raise ValueError("Shape chainage differs from the 1A pattern")
    stats={"shape_count":len(shape_records),"route_features":len(features),
           "original_points":original_count,"simplified_points":simplified_count,
           "max_deviation_m":round(largest_deviation,6),"tolerance_m":tolerance}
    return shape_records,line_records,{"type":"FeatureCollection","features":features},stats


def create_pack_tables(db):
    db.executescript("""
        CREATE TABLE cities(city_code TEXT PRIMARY KEY,name TEXT NOT NULL,timezone TEXT NOT NULL);
        CREATE TABLE config(city_code TEXT NOT NULL REFERENCES cities(city_code),key TEXT NOT NULL,
            value_json TEXT NOT NULL,PRIMARY KEY(city_code,key));
        CREATE TABLE lines(line_id TEXT PRIMARY KEY,name TEXT NOT NULL,color TEXT NOT NULL);
        CREATE TABLE line_fares(line_id TEXT PRIMARY KEY REFERENCES lines(line_id),
            amount REAL NOT NULL CHECK(amount>=0),currency TEXT NOT NULL CHECK(currency='PEN'));
        CREATE TABLE shapes(shape_id TEXT PRIMARY KEY,geometry_json TEXT NOT NULL,
            vertex_distances_json TEXT NOT NULL,original_points INTEGER NOT NULL,
            simplified_points INTEGER NOT NULL,length_m REAL NOT NULL,max_deviation_m REAL NOT NULL);
        CREATE TABLE routes(route_id TEXT PRIMARY KEY,agency_id TEXT NOT NULL,short_name TEXT NOT NULL,
            long_name TEXT NOT NULL,route_color TEXT NOT NULL,shape_id TEXT NOT NULL REFERENCES shapes(shape_id),
            line_id TEXT REFERENCES lines(line_id),direction TEXT,
            pattern_available INTEGER NOT NULL CHECK(pattern_available IN (0,1)));
        CREATE TABLE patterns(pattern_id TEXT PRIMARY KEY,line_id TEXT NOT NULL REFERENCES lines(line_id),
            direction TEXT NOT NULL CHECK(direction IN ('ida','vuelta')),route_id TEXT NOT NULL REFERENCES routes(route_id),
            shape_id TEXT NOT NULL REFERENCES shapes(shape_id),headsign TEXT NOT NULL,length_m REAL NOT NULL,
            derivation TEXT NOT NULL);
        CREATE TABLE pattern_stops(pattern_id TEXT NOT NULL REFERENCES patterns(pattern_id),
            stop_sequence INTEGER NOT NULL CHECK(stop_sequence>=1),stop_id TEXT NOT NULL REFERENCES stops(stop_id),
            distance_m REAL NOT NULL CHECK(distance_m>=0),offset_m REAL NOT NULL CHECK(offset_m<=35.000002),
            shape_latitude REAL NOT NULL,shape_longitude REAL NOT NULL,
            PRIMARY KEY(pattern_id,stop_sequence));
        CREATE INDEX pattern_stops_by_stop ON pattern_stops(stop_id);
    """)


def verify_manifest(directory: Path) -> dict:
    manifest=json.loads((directory/"manifest.json").read_text(encoding="utf-8"))
    if manifest["schema_version"]!=1 or manifest["city_code"]!="arequipa":
        raise ValueError("Unexpected manifest schema or city")
    for name,info in manifest["files"].items():
        path=directory/name
        if path.resolve().parent!=directory.resolve():raise ValueError("Unsafe manifest filename")
        content=path.read_bytes()
        if len(content)!=info["bytes"] or hashlib.sha256(content).hexdigest()!=info["sha256"]:
            raise ValueError("Package hash or size mismatch: "+name)
    if manifest["sha256"]!=manifest["files"]["pack.sqlite"]["sha256"]:
        raise ValueError("Inconsistent pack SHA-256")
    return manifest


def make_city_pack(document: dict, raw_directory: Path, enrichment: Path,
                   config_path: Path=DEFAULT_CONFIG, destination: Path=DEFAULT_ASSETS) -> dict:
    raw_directory,enrichment,config_path,destination=map(Path.resolve,
        (raw_directory,enrichment,config_path,destination))
    if ROOT not in destination.parents or destination==raw_directory or raw_directory in destination.parents:
        raise ValueError("Package output must stay inside the project and outside raw inputs")
    config=json.loads(config_path.read_text(encoding="utf-8-sig"))
    validate_config(config)
    for name,digest in document["source_sha256"].items():
        if hashlib.sha256((raw_directory/name).read_bytes()).hexdigest()!=digest:
            raise ValueError("Raw input changed: "+name)
    shapes,lines,geojson,geometry_stats=build_geometry(raw_directory,document,config["geometry_tolerance_m"])
    known_lines={line["line_id"] for line in lines}
    if set(config["line_fare_overrides"])-known_lines:raise ValueError("Fare override references an unknown line")
    stage=Path(__file__).resolve().parent/"output/package-stage"
    stage.mkdir(parents=True,exist_ok=True)
    pack=stage/"pack.sqlite"
    if pack.exists():pack.unlink()
    with closing(sqlite3.connect(enrichment.as_uri()+"?mode=ro",uri=True)) as source:
        original_provenance=json.loads(source.execute("SELECT value FROM metadata WHERE key='provenance'").fetchone()[0])
        if original_provenance["source_sha256"]!=document["source_sha256"]:
            raise ValueError("Enrichment belongs to different source inputs")
        with closing(sqlite3.connect(pack)) as db:
            source.backup(db)
            db.execute("PRAGMA foreign_keys=ON")
            db.execute("PRAGMA journal_mode=DELETE")
            create_pack_tables(db)
            with db:
                db.execute("INSERT INTO cities VALUES(?,?,?)",(config["city_code"],config["city_name"],config["timezone"]))
                db.executemany("INSERT INTO config VALUES(?,?,?)",[
                    (config["city_code"],key,canonical(value)) for key,value in sorted(config.items())
                    if key!="line_fare_overrides"])
                db.executemany("INSERT INTO lines VALUES(?,?,?)",[
                    (line["line_id"],line["name"],line["color"]) for line in sorted(lines,key=lambda row:row["line_id"])])
                db.executemany("INSERT INTO line_fares VALUES(?,?,?)",[
                    (line_id,value,"PEN") for line_id,value in sorted(config["line_fare_overrides"].items())])
                db.executemany("INSERT INTO shapes VALUES(?,?,?,?,?,?,?)",[
                    (row["shape_id"],canonical(row["geometry"]),canonical(row["vertex_distances_m"]),
                     row["original_points"],row["simplified_points"],row["length_m"],row["max_deviation_m"])
                    for row in shapes.values()])
                db.executemany("INSERT INTO routes VALUES(?,?,?,?,?,?,?,?,?)",[
                    (p["route_id"],p["agency_id"],p["short_name"],p["long_name"],p["route_color"],p["shape_id"],
                     p["line_id"],p["direction"],int(p["pattern_available"])) for p in (f["properties"] for f in geojson["features"])])
                for pattern in document["patterns"]:
                    db.execute("INSERT INTO patterns VALUES(?,?,?,?,?,?,?,?)",(
                        pattern["pattern_id"],pattern["line_id"],pattern["direction"],pattern["route_id"],
                        pattern["shape_id"],pattern["headsign"],pattern["length_m"],pattern["derivation"]))
                    db.executemany("INSERT INTO pattern_stops VALUES(?,?,?,?,?,?,?)",[
                        (pattern["pattern_id"],sequence,row["stop_id"],row["distance_m"],row["offset_m"],
                         row["shape_latitude"],row["shape_longitude"])
                        for sequence,row in enumerate(pattern["stops"],start=1)])
                db.execute("INSERT OR REPLACE INTO metadata VALUES(?,?)",("pack_stage",canonical("1C_city_pack")))
                db.execute("INSERT OR REPLACE INTO metadata VALUES(?,?)",("pack_config_sha256",canonical(hashlib.sha256(config_path.read_bytes()).hexdigest())))
                if db.execute("PRAGMA foreign_key_check").fetchone():raise ValueError("Pack foreign keys are invalid")
                if db.execute("SELECT count(*) FROM patterns").fetchone()[0]!=len(document["patterns"]):
                    raise ValueError("Missing pack patterns")
                if not search_places(db,"tecsup arequipa"):raise ValueError("Pack lost its FTS search")
                db.execute("INSERT INTO places_fts(places_fts,rank) VALUES('integrity-check',1)")
            if db.execute("PRAGMA quick_check").fetchone()[0]!="ok":raise ValueError("Pack SQLite integrity failed")
    (stage/"routes.geojson").write_text(canonical(geojson)+"\n",encoding="utf-8")
    files={name:{"bytes":(stage/name).stat().st_size,
                 "sha256":hashlib.sha256((stage/name).read_bytes()).hexdigest()}
           for name in ("pack.sqlite","routes.geojson")}
    now=datetime.now(timezone.utc)
    manifest={"schema_version":1,"version":config["data_version"],"city_code":config["city_code"],
        "date":now.date().isoformat(),"generated_at":now.isoformat(),"sha256":files["pack.sqlite"]["sha256"],
        "size_bytes":files["pack.sqlite"]["bytes"],"build_id":files["pack.sqlite"]["sha256"][:16],
        "files":files,"geometry":geometry_stats,
        "counts":{"lines":len(lines),"routes_in_source":len(geojson["features"]),"patterns":len(document["patterns"]),
                  "pattern_stop_visits":sum(len(p["stops"]) for p in document["patterns"])},
        "excluded_from_routing":[{"route_id":value,"reason":"missing_from_network_catalog"}
                                 for value in document["summary"]["unmapped_route_ids"]],
        "provenance":original_provenance,"config_sha256":hashlib.sha256(config_path.read_bytes()).hexdigest(),
        "attribution":"OpenStreetMap contributors; ODbL 1.0; https://www.openstreetmap.org/copyright"}
    (stage/"manifest.json").write_text(canonical(manifest)+"\n",encoding="utf-8")
    verify_manifest(stage)
    destination.mkdir(parents=True,exist_ok=True)
    # Payloads are replaced only after validation; manifest is published last.
    for name in ("pack.sqlite","routes.geojson","manifest.json"):
        temporary=destination/(name+".tmp")
        temporary.write_bytes((stage/name).read_bytes())
        temporary.replace(destination/name)
    verify_manifest(destination)
    return manifest
