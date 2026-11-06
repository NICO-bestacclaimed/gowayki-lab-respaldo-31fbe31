"""Read OSM objects and derive road/intersection names with source IDs."""
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
import math
from pathlib import Path
import unicodedata

from build import Projection, project_segment


def normalized(value: str) -> str:
    return " ".join("".join(c for c in unicodedata.normalize("NFD", value.casefold())
                             if not unicodedata.combining(c)).split())


UNKNOWN_NAMES = {"", "innominada", "sin nombre", "s/n", "sn", "unnamed", "calle sin nombre", "calle s/n"}
HIGHWAY_STREETS = {"motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
                   "secondary", "secondary_link", "tertiary", "tertiary_link", "residential",
                   "unclassified", "service", "living_street", "pedestrian", "track", "path",
                   "footway", "cycleway", "steps", "bridleway", "road"}


def usable_name(value: str) -> bool:
    return normalized(value) not in UNKNOWN_NAMES


def category(tags: dict[str, str]) -> str | None:
    amenity = tags.get("amenity", "")
    categories = {
        "university": "university", "college": "institute", "training": "institute",
        "hospital": "hospital", "clinic": "clinic", "marketplace": "market",
        "bus_station": "terminal", "townhall": "municipality", "school": "school",
        "kindergarten": "school", "place_of_worship": "place_of_worship",
    }
    if amenity in categories:
        return categories[amenity]
    if tags.get("shop") == "mall":
        return "shopping_centre"
    if tags.get("leisure") == "park":
        return "park"
    if tags.get("place") == "square":
        return "square"
    if tags.get("place") in {"neighbourhood", "quarter", "suburb"}:
        return "neighbourhood"
    if tags.get("place") in {"city", "town", "village", "hamlet", "locality"}:
        return "locality"
    if tags.get("highway") in HIGHWAY_STREETS:
        return "street"
    return None


@dataclass(frozen=True)
class Road:
    osm_id: int
    name: str
    nodes: tuple[tuple[int, float, float], ...]  # OSM ID, latitude, longitude


@dataclass
class OsmData:
    roads: list[Road]
    places: list[dict]
    inventory: list[dict]
    counts: dict


def read_osm(path: Path, bbox: tuple[float, float, float, float]) -> OsmData:
    import osmium
    south, west, north, east = bbox
    def inside(lat, lon):
        return south <= lat <= north and west <= lon <= east
    roads, places, inventory = [], {}, []
    counts = {"nodes": 0, "ways": 0, "areas": 0, "incomplete_relevant_ways": 0}
    def add_place(kind, identifier, tags, points, coordinate_source):
        name = tags.get("name", "").strip()
        place_category = category(tags)
        if not usable_name(name) or not place_category or not points or (kind == "node" and place_category == "street"):
            return
        latitude = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
        longitude = (min(p[1] for p in points) + max(p[1] for p in points)) / 2
        if not inside(latitude, longitude):
            return
        key = f"osm:{kind}:{identifier}"
        places[key] = {
            "place_id": key, "name": name, "category": place_category,
            "latitude": latitude, "longitude": longitude, "osm_type": kind,
            "osm_id": identifier, "coordinate_source": coordinate_source,
            "tags": tags,
        }
    processor = osmium.FileProcessor(str(path)).with_locations().with_areas()
    for item in processor:
        if item.is_node():
            counts["nodes"] += 1
            if not item.location.valid():
                continue
            latitude, longitude = item.location.lat, item.location.lon
            if not inside(latitude, longitude):
                continue
            tags = dict(item.tags)
            add_place("node", item.id, tags, [(latitude, longitude)], "osm_node")
            is_bus_stop = tags.get("highway") == "bus_stop" or (
                tags.get("public_transport") in {"platform", "stop_position"}
                and tags.get("bus") == "yes")
            if is_bus_stop:
                inventory.append({"osm_type": "node", "osm_id": item.id,
                                  "latitude": latitude, "longitude": longitude,
                                  "tags": tags})
        elif item.is_way():
            counts["ways"] += 1
            tags = dict(item.tags)
            if not usable_name(tags.get("name", "")) or not category(tags):
                continue
            if any(not node.location.valid() for node in item.nodes):
                counts["incomplete_relevant_ways"] += 1
                continue
            nodes = tuple((node.ref, node.lat, node.lon) for node in item.nodes)
            points = [(node[1], node[2]) for node in nodes]
            if not points:
                continue
            intersects = (min(p[0] for p in points) <= north and max(p[0] for p in points) >= south
                          and min(p[1] for p in points) <= east and max(p[1] for p in points) >= west)
            if not intersects:
                continue
            if tags.get("highway") in HIGHWAY_STREETS and len(nodes) >= 2:
                roads.append(Road(item.id, tags["name"].strip(), nodes))
            add_place("way", item.id, tags, points, "way_bbox_center")
        elif item.is_area():
            counts["areas"] += 1
            tags = dict(item.tags)
            if not usable_name(tags.get("name", "")) or not category(tags):
                continue
            points = [(node.lat, node.lon) for ring in item.outer_rings()
                      for node in ring if node.location.valid()]
            kind = "way" if item.from_way() else "relation"
            add_place(kind, item.orig_id(), tags, points, "area_bbox_center")
    if not roads:
        raise ValueError("The extract has no named roads in the requested area")
    return OsmData(sorted(roads, key=lambda road: road.osm_id),
                   sorted(places.values(), key=lambda place: place["place_id"]),
                   sorted(inventory, key=lambda point: point["osm_id"]), counts)


class RoadIndex:
    def __init__(self, roads: list[Road], projection: Projection, cell_size=200.0):
        if not roads or cell_size <= 0:
            raise ValueError("Road index requires roads and a positive cell size")
        self.roads = {road.osm_id: road for road in roads}
        self.projection, self.cell_size = projection, cell_size
        self.parents = {road.osm_id: road.osm_id for road in roads}
        node_roads, named_nodes, coordinates = defaultdict(set), {}, {}
        self.cells, self.segments = defaultdict(list), []
        for road in roads:
            name = normalized(road.name)
            for node_id, latitude, longitude in road.nodes:
                coordinates[node_id] = projection.forward(latitude, longitude)
                node_roads[node_id].add(road.osm_id)
                key = name, node_id
                if key in named_nodes:
                    self.union(road.osm_id, named_nodes[key])
                else:
                    named_nodes[key] = road.osm_id
            for start_node, end_node in zip(road.nodes, road.nodes[1:]):
                start, end = coordinates[start_node[0]], coordinates[end_node[0]]
                if math.dist(start, end) < 1e-8:
                    continue
                identifier = len(self.segments)
                self.segments.append((road.osm_id, start, end))
                low = self.cell(min(start[0], end[0]), min(start[1], end[1]))
                high = self.cell(max(start[0], end[0]), max(start[1], end[1]))
                for x in range(low[0], high[0] + 1):
                    for y in range(low[1], high[1] + 1):
                        self.cells[x, y].append(identifier)
        if not self.segments:
            raise ValueError("Named roads have no valid segments")
        self.junctions = defaultdict(list)
        for node_id, road_ids in node_roads.items():
            by_name = {}
            for road_id in sorted(road_ids):
                by_name.setdefault(normalized(self.roads[road_id].name), road_id)
            if len(by_name) < 2:
                continue
            for road_id in sorted(road_ids):
                own_name = normalized(self.roads[road_id].name)
                for other_name, other_id in sorted(by_name.items()):
                    if other_name != own_name:
                        self.junctions[self.find(road_id)].append((
                            coordinates[node_id], node_id, other_id))
        self.min_x = min(c[0] for c in self.cells)
        self.max_x = max(c[0] for c in self.cells)
        self.min_y = min(c[1] for c in self.cells)
        self.max_y = max(c[1] for c in self.cells)

    def cell(self, x, y):
        return math.floor(x / self.cell_size), math.floor(y / self.cell_size)

    def find(self, value):
        while self.parents[value] != value:
            self.parents[value] = self.parents[self.parents[value]]
            value = self.parents[value]
        return value

    def union(self, left, right):
        left, right = self.find(left), self.find(right)
        if left != right:
            self.parents[max(left, right)] = min(left, right)

    def nearest(self, latitude, longitude):
        point = self.projection.forward(latitude, longitude)
        cx, cy = self.cell(*point)
        limit = max(abs(cx - self.min_x), abs(cx - self.max_x),
                    abs(cy - self.min_y), abs(cy - self.max_y))
        best, seen = None, set()
        for radius in range(limit + 1):
            for x in range(cx - radius, cx + radius + 1):
                for y in range(cy - radius, cy + radius + 1):
                    if radius and abs(x - cx) != radius and abs(y - cy) != radius:
                        continue
                    for identifier in self.cells.get((x, y), ()):
                        if identifier in seen:
                            continue
                        seen.add(identifier)
                        road_id, start, end = self.segments[identifier]
                        _, distance, _, _ = project_segment(point, start, end)
                        candidate = distance, road_id, identifier
                        if best is None or candidate < best:
                            best = candidate
            boundary_distance = min(
                point[0] - (cx - radius) * self.cell_size,
                (cx + radius + 1) * self.cell_size - point[0],
                point[1] - (cy - radius) * self.cell_size,
                (cy + radius + 1) * self.cell_size - point[1],
            )
            if best is not None and best[0] < boundary_distance - 1e-8:
                return best[1], best[0]
        if best is None:
            raise ValueError("No nearest named road was found")
        return best[1], best[0]

    def name_for(self, latitude, longitude, max_road_m=50.0, max_intersection_m=200.0):
        road_id, road_distance = self.nearest(latitude, longitude)
        road = self.roads[road_id]
        if road_distance > max_road_m + 1e-6:
            return None, {"reason": "nearest_named_road_too_far", "road_osm_id": road_id,
                          "road_name": road.name, "road_distance_m": round(road_distance, 6)}
        junctions = self.junctions.get(self.find(road_id), [])
        if not junctions:
            return None, {"reason": "nearest_named_road_has_no_named_intersection",
                          "road_osm_id": road_id, "road_name": road.name,
                          "road_distance_m": round(road_distance, 6)}
        point = self.projection.forward(latitude, longitude)
        junction = min(junctions, key=lambda item: (math.dist(point, item[0]), item[1], item[2]))
        cross_road = self.roads[junction[2]]
        evidence = {
            "road_osm_id": road_id, "road_name": road.name,
            "intersection_node_osm_id": junction[1], "cross_road_osm_id": cross_road.osm_id,
            "cross_road_name": cross_road.name,
            "road_distance_m": round(road_distance, 6),
            "intersection_distance_m": round(math.dist(point, junction[0]), 6),
        }
        if math.dist(point, junction[0]) > max_intersection_m + 1e-6:
            return None, {**evidence, "reason": "nearest_named_intersection_too_far"}
        return f"{road.name} / {cross_road.name}", evidence
