"""Build inferred patterns; optional --enrich adds OSM/FTS tooling without changing Flutter assets."""
from __future__ import annotations

import argparse
from bisect import bisect_left
from collections import defaultdict
import csv
from dataclasses import dataclass
import hashlib
import json
import math
import sqlite3
from pathlib import Path
import sys

EARTH_RADIUS_M = 6_371_008.8
MAX_OFFSET_M = 35.0
MIN_SPACING_M = 60.0
MAX_GAP_M = 800.0
VIRTUAL_STEP_M = 400.0
EPSILON_M = 1e-6
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / "tool" / "data" / "raw"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "output" / "patterns.json"


@dataclass(frozen=True)
class Projection:
    """Local equirectangular plane, in metres; not a walking-distance model."""
    latitude: float
    longitude: float

    def forward(self, latitude: float, longitude: float) -> tuple[float, float]:
        return (
            EARTH_RADIUS_M * math.radians(longitude - self.longitude)
            * math.cos(math.radians(self.latitude)),
            EARTH_RADIUS_M * math.radians(latitude - self.latitude),
        )

    def inverse(self, x: float, y: float) -> tuple[float, float]:
        return (
            self.latitude + math.degrees(y / EARTH_RADIUS_M),
            self.longitude + math.degrees(
                x / (EARTH_RADIUS_M * math.cos(math.radians(self.latitude)))
            ),
        )


@dataclass(frozen=True)
class Stop:
    identifier: str
    name: str | None
    latitude: float
    longitude: float
    virtual: bool = False

    def record(self) -> dict:
        return {
            "stop_id": self.identifier, "name": self.name,
            "latitude": self.latitude, "longitude": self.longitude,
            "is_virtual": self.virtual,
        }


@dataclass(frozen=True)
class Hit:
    stop_id: str
    distance_m: float
    offset_m: float
    x: float
    y: float
    segment: int
    virtual: bool = False


class Shape:
    def __init__(self, identifier: str, coordinates: list[tuple[float, float]],
                 projection: Projection):
        self.identifier = identifier
        self.projection = projection
        self.points: list[tuple[float, float]] = []
        self.cumulative = [0.0]
        for latitude, longitude in coordinates:
            point = projection.forward(latitude, longitude)
            if self.points:
                distance = math.dist(self.points[-1], point)
                if distance <= EPSILON_M:
                    continue
                self.cumulative.append(self.cumulative[-1] + distance)
            self.points.append(point)
        if len(self.points) < 2:
            raise ValueError(f"Shape {identifier}: fewer than two distinct points")
        self.length = self.cumulative[-1]

    def at(self, distance_m: float) -> tuple[float, float]:
        distance_m = max(0.0, min(self.length, distance_m))
        segment = min(len(self.points) - 2,
                      max(0, bisect_left(self.cumulative, distance_m) - 1))
        start, end = self.points[segment:segment + 2]
        fraction = ((distance_m - self.cumulative[segment])
                    / (self.cumulative[segment + 1] - self.cumulative[segment]))
        return (start[0] + fraction * (end[0] - start[0]),
                start[1] + fraction * (end[1] - start[1]))


class StopGrid:
    """Index the source stops once; query expanded segment bounding boxes."""
    def __init__(self, stops: list[Stop], projection: Projection,
                 cell_size: float = 100.0):
        self.cell_size = cell_size
        self.cells: dict[tuple[int, int], list[tuple[Stop, float, float]]] = defaultdict(list)
        for stop in sorted(stops, key=lambda value: value.identifier):
            x, y = projection.forward(stop.latitude, stop.longitude)
            self.cells[self.cell(x, y)].append((stop, x, y))

    def cell(self, x: float, y: float) -> tuple[int, int]:
        return (math.floor(x / self.cell_size), math.floor(y / self.cell_size))

    def near_segment(self, start: tuple[float, float], end: tuple[float, float]):
        low = self.cell(min(start[0], end[0]) - MAX_OFFSET_M,
                        min(start[1], end[1]) - MAX_OFFSET_M)
        high = self.cell(max(start[0], end[0]) + MAX_OFFSET_M,
                         max(start[1], end[1]) + MAX_OFFSET_M)
        for cell_x in range(low[0], high[0] + 1):
            for cell_y in range(low[1], high[1] + 1):
                yield from self.cells.get((cell_x, cell_y), ())


def project_segment(point: tuple[float, float], start: tuple[float, float],
                    end: tuple[float, float]) -> tuple[float, float, float, float]:
    dx, dy = end[0] - start[0], end[1] - start[1]
    squared_length = dx * dx + dy * dy
    fraction = 0.0 if squared_length == 0 else max(0.0, min(
        1.0, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy)
        / squared_length))
    x, y = start[0] + fraction * dx, start[1] + fraction * dy
    return fraction, math.hypot(point[0] - x, point[1] - y), x, y


def real_hits(shape: Shape, grid: StopGrid) -> list[Hit]:
    by_stop: dict[str, list[Hit]] = defaultdict(list)
    for index, (start, end) in enumerate(zip(shape.points, shape.points[1:])):
        length = shape.cumulative[index + 1] - shape.cumulative[index]
        for stop, x, y in grid.near_segment(start, end):
            fraction, offset, snapped_x, snapped_y = project_segment((x, y), start, end)
            if offset <= MAX_OFFSET_M + EPSILON_M:
                by_stop[stop.identifier].append(Hit(
                    stop.identifier, shape.cumulative[index] + fraction * length,
                    offset, snapped_x, snapped_y, index,
                ))
    visits = []
    for candidates in by_stop.values():
        # Adjacent segments describe the same visit. A later pass around a loop
        # is retained when both segment continuity and the 60 m window break.
        group: list[Hit] = []
        for candidate in candidates:
            if group and (candidate.segment > group[-1].segment + 1
                          and candidate.distance_m - group[-1].distance_m
                          >= MIN_SPACING_M):
                visits.append(min(group, key=lambda hit: (hit.offset_m, hit.distance_m)))
                group = []
            group.append(candidate)
        if group:
            visits.append(min(group, key=lambda hit: (hit.offset_m, hit.distance_m)))
    visits.sort(key=lambda hit: (hit.distance_m, hit.offset_m, hit.stop_id))
    retained = []
    for visit in visits:
        if not retained or visit.distance_m - retained[-1].distance_m >= MIN_SPACING_M - EPSILON_M:
            retained.append(visit)
    return retained


def gaps(hits: list[Hit], length: float) -> list[tuple[float, float]]:
    positions = [0.0] + [hit.distance_m for hit in hits] + [length]
    return list(zip(positions, positions[1:]))


def complete_pattern(pattern_id: str, shape: Shape,
                     real: list[Hit]) -> tuple[list[Hit], dict[str, Stop], bool, int]:
    sparse = len(real) < 5
    long_gaps = [(a, b) for a, b in gaps(real, shape.length)
                 if b - a > MAX_GAP_M + EPSILON_M]
    candidate_distances: set[float] = set()
    if sparse:
        candidate_distances.update(index * VIRTUAL_STEP_M
                                   for index in range(math.floor(shape.length / VIRTUAL_STEP_M) + 1))
        candidate_distances.add(shape.length)
    else:
        for start, end in long_gaps:
            candidate_distances.update(start + index * VIRTUAL_STEP_M
                                       for index in range(1, math.ceil((end - start) / VIRTUAL_STEP_M))
                                       if start + index * VIRTUAL_STEP_M < end)
            if start == 0:
                candidate_distances.add(0.0)
            if end == shape.length:
                candidate_distances.add(shape.length)
    result = list(real)
    occupied = [hit.distance_m for hit in real]
    virtual_stops = {}
    for distance in sorted(candidate_distances):
        index = bisect_left(occupied, distance)
        neighbours = occupied[max(0, index - 1):index + 1]
        if any(abs(other - distance) < MIN_SPACING_M - EPSILON_M for other in neighbours):
            continue
        x, y = shape.at(distance)
        latitude, longitude = shape.projection.inverse(x, y)
        stop_id = f"virtual:{pattern_id}:{round(distance * 1000)}"
        virtual_stops[stop_id] = Stop(stop_id, None, latitude, longitude, True)
        result.append(Hit(stop_id, distance, 0.0, x, y, -1, True))
        occupied.insert(index, distance)
    result.sort(key=lambda hit: hit.distance_m)
    return result, virtual_stops, sparse, len(long_gaps)


def read_csv(path: Path, fields: set[str]) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not fields.issubset(reader.fieldnames or []):
            raise ValueError(f"{path.name}: missing columns {sorted(fields - set(reader.fieldnames or []))}")
        return list(reader)


def coordinates(latitude: str, longitude: str) -> tuple[float, float]:
    latitude_value, longitude_value = float(latitude), float(longitude)
    if not (math.isfinite(latitude_value) and math.isfinite(longitude_value)
            and -90 <= latitude_value <= 90 and -180 <= longitude_value <= 180):
        raise ValueError("Invalid latitude/longitude in source data")
    return latitude_value, longitude_value


def load_source(directory: Path):
    routes = read_csv(directory / "routes.txt", {"route_id", "route_short_name", "route_color"})
    trips = read_csv(directory / "trips.txt", {"route_id", "shape_id"})
    raw_stops = read_csv(directory / "stops.txt", {"stop_id", "stop_name", "stop_lat", "stop_lon"})
    raw_shapes = read_csv(directory / "shapes.txt", {
        "shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"})
    network = json.loads((directory / "network.json").read_text(encoding="utf-8-sig"))
    route_ids = {route["route_id"] for route in routes}
    if len(route_ids) != len(routes):
        raise ValueError("Duplicate route_id in routes.txt")
    stop_ids = [stop["stop_id"] for stop in raw_stops]
    if len(set(stop_ids)) != len(stop_ids) or any(not value for value in stop_ids):
        raise ValueError("Empty or duplicate stop_id in stops.txt")
    stops = [Stop(stop["stop_id"], stop["stop_name"],
                  *coordinates(stop["stop_lat"], stop["stop_lon"])) for stop in raw_stops]
    shape_points: dict[str, dict[int, tuple[float, float]]] = defaultdict(dict)
    for row in raw_shapes:
        sequence = int(row["shape_pt_sequence"])
        if sequence in shape_points[row["shape_id"]]:
            raise ValueError(f"Duplicate sequence in shape {row['shape_id']}")
        shape_points[row["shape_id"]][sequence] = coordinates(row["shape_pt_lat"], row["shape_pt_lon"])
    route_shapes: dict[str, set[str]] = defaultdict(set)
    for trip in trips:
        if trip["route_id"] not in route_ids or trip["shape_id"] not in shape_points:
            raise ValueError("Trip references an unknown route or shape")
        route_shapes[trip["route_id"]].add(trip["shape_id"])
    entries = []
    seen_lines, seen_patterns, covered_routes = set(), set(), set()
    for line in network:
        if line["id"] in seen_lines:
            raise ValueError(f"Duplicate line ID: {line['id']}")
        seen_lines.add(line["id"])
        if not line["directions"]:
            raise ValueError(f"Line without directions: {line['id']}")
        seen_kinds = set()
        for direction in line["directions"]:
            route_id, kind = direction["route_id"], direction["kind"]
            if kind not in {"ida", "vuelta"} or kind in seen_kinds:
                raise ValueError(f"Unknown or duplicate direction for line {line['id']}")
            seen_kinds.add(kind)
            if route_id not in route_ids or len(route_shapes[route_id]) != 1:
                raise ValueError(f"Route {route_id}: requires exactly one known shape; needs a decision")
            shape_id = next(iter(route_shapes[route_id]))
            pattern_id = f"{line['id']}:{kind}:{route_id}"
            if pattern_id in seen_patterns or route_id in covered_routes:
                raise ValueError(f"Duplicate pattern/route in network: {route_id}")
            seen_patterns.add(pattern_id)
            covered_routes.add(route_id)
            entries.append((line, direction, shape_id, pattern_id))
    if not entries:
        raise ValueError("Empty network catalog")
    relevant = [point for _, _, shape_id, _ in entries for point in shape_points[shape_id].values()]
    projection = Projection(
        (min(p[0] for p in relevant) + max(p[0] for p in relevant)) / 2,
        (min(p[1] for p in relevant) + max(p[1] for p in relevant)) / 2,
    )
    shapes = {shape_id: Shape(shape_id, [points[key] for key in sorted(points)], projection)
              for shape_id, points in shape_points.items()
              if any(shape_id == entry[2] for entry in entries)}
    return stops, shapes, entries, projection, sorted(route_ids - covered_routes)


def validate_pattern(hits: list[Hit], shape: Shape) -> None:
    for index, hit in enumerate(hits):
        if not -EPSILON_M <= hit.distance_m <= shape.length + EPSILON_M:
            raise ValueError("Stop chainage outside its shape")
        if not 0 <= hit.offset_m <= MAX_OFFSET_M + EPSILON_M:
            raise ValueError("Stop farther than 35 m from its shape")
        if index and hit.distance_m - hits[index - 1].distance_m < MIN_SPACING_M - EPSILON_M:
            raise ValueError("Pattern is unordered or has stops less than 60 m apart")
    if max((end - start for start, end in gaps(hits, shape.length)), default=0) > MAX_GAP_M + EPSILON_M:
        raise ValueError("An uncovered gap greater than 800 m remains")


def build_document(directory: Path) -> dict:
    stops, shapes, entries, projection, unmapped = load_source(directory)
    stop_lookup = {stop.identifier: stop for stop in stops}
    grid = StopGrid(stops, projection)
    used_stops, patterns = {}, []
    sparse_count = gap_count = real_visits = virtual_visits = 0
    for line, direction, shape_id, pattern_id in entries:
        shape = shapes[shape_id]
        real = real_hits(shape, grid)
        hits, virtual, sparse, long_gaps = complete_pattern(pattern_id, shape, real)
        validate_pattern(hits, shape)
        rows = []
        for hit in hits:
            stop = virtual[hit.stop_id] if hit.virtual else stop_lookup[hit.stop_id]
            used_stops[stop.identifier] = stop.record()
            latitude, longitude = projection.inverse(hit.x, hit.y)
            rows.append({
                "stop_id": hit.stop_id, "distance_m": round(hit.distance_m, 6),
                "offset_m": round(hit.offset_m, 6),
                "shape_latitude": round(latitude, 10),
                "shape_longitude": round(longitude, 10),
            })
        sparse_count += sparse
        gap_count += long_gaps > 0
        real_visits += len(real)
        virtual_visits += len(virtual)
        patterns.append({
            "pattern_id": pattern_id, "line_id": line["id"],
            "short_name": line["short_name"], "color": line["color"],
            "direction": direction["kind"], "route_id": direction["route_id"],
            "headsign": direction["headsign"], "shape_id": shape_id,
            "length_m": round(shape.length, 6), "derivation": "geometry_proximity",
            "retained_real_visits": len(real), "added_virtual_visits": len(virtual),
            "initially_sparse": sparse, "initial_long_gaps": long_gaps,
            "stops": rows,
        })
    patterns.sort(key=lambda pattern: pattern["pattern_id"])
    files = ["routes.txt", "trips.txt", "stops.txt", "shapes.txt", "network.json"]
    real_count = sum(not stop["is_virtual"] for stop in used_stops.values())
    summary = {
        "line_count": len({pattern["line_id"] for pattern in patterns}),
        "pattern_count": len(patterns), "source_real_stops": len(stops),
        "used_real_stops_unique": real_count,
        "virtual_stops_unique": len(used_stops) - real_count,
        "real_stop_visits": real_visits, "virtual_stop_visits": virtual_visits,
        "initially_sparse_patterns": sparse_count,
        "patterns_with_initial_long_gaps": gap_count,
        "unmapped_route_ids": unmapped,
    }
    return {
        "schema_version": 1, "city_code": "arequipa", "stage": "1A_patterns",
        "distance_model": {"type": "local_equirectangular", "unit": "metre",
                           "earth_radius_m": EARTH_RADIUS_M,
                           "latitude_origin": projection.latitude,
                           "longitude_origin": projection.longitude},
        "rules": {"max_stop_offset_m": MAX_OFFSET_M, "min_spacing_m": MIN_SPACING_M,
                  "max_gap_m": MAX_GAP_M, "virtual_step_m": VIRTUAL_STEP_M},
        "source_sha256": {name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                          for name in files},
        "summary": summary,
        "stops": sorted(used_stops.values(), key=lambda stop: stop["stop_id"]),
        "patterns": patterns,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--enrich", action="store_true", help="Also build the intermediate 1B SQLite database")
    parser.add_argument("--osm-pbf", type=Path, default=ROOT / "tool/.cache/trufi-review/arequipa.osm.pbf")
    parser.add_argument("--pack", action="store_true", help="Build 1A, 1B and the 1C city package")
    parser.add_argument("--config", type=Path, default=ROOT / "tool/build_city_pack/config/arequipa.json")
    parser.add_argument("--assets-dir", type=Path, default=ROOT / "assets/city/arequipa")
    options = parser.parse_args()
    try:
        document = build_document(options.input_dir.resolve())
        output = options.output.resolve()
        if (options.enrich or options.pack) and output == options.osm_pbf.resolve():
            raise ValueError("Pattern output must not overwrite the OSM extract")
        if output == options.input_dir.resolve() or options.input_dir.resolve() in output.parents:
            raise ValueError("Output must not overwrite the source assets directory")
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_suffix(output.suffix + ".tmp")
        temporary.write_text(json.dumps(document, ensure_ascii=False, sort_keys=True,
                                        separators=(",", ":"), allow_nan=False) + "\n", encoding="utf-8")
        temporary.replace(output)
        print(json.dumps(document["summary"], indent=2, ensure_ascii=True))
        print(f"Output: {output}")
        print(f"Bytes: {output.stat().st_size}")
        print(f"SHA256: {hashlib.sha256(output.read_bytes()).hexdigest()}")
        if document["summary"]["unmapped_route_ids"]:
            print("WARNING: source routes outside network.json remain in the source data; "
                  "no line/direction was invented for them.", file=sys.stderr)
        if options.enrich or options.pack:
            from enrich import run_enrichment
            run_enrichment(document, options.input_dir, options.osm_pbf,
                           output.with_name("enrichment.sqlite"))
        if options.pack:
            from city_pack import make_city_pack
            manifest = make_city_pack(document, options.input_dir, output.with_name("enrichment.sqlite"),
                                      options.config, options.assets_dir)
            print(json.dumps({"package":str(options.assets_dir.resolve()),"manifest":manifest},ensure_ascii=True,indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, ImportError, RuntimeError, sqlite3.Error) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
