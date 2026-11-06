"""Geometry fixtures and integration checks for the 1A source dataset."""
from bisect import bisect_left
import csv
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import build as builder

PLANE = builder.Projection(0.0, 0.0)


def stop(identifier, x, y=0):
    return builder.Stop(identifier, identifier, *PLANE.inverse(x, y))


def shape(points, identifier="fixture"):
    return builder.Shape(identifier, [PLANE.inverse(x, y) for x, y in points], PLANE)


def hit(identifier, distance):
    return builder.Hit(identifier, distance, 0.0, distance, 0.0, 0)


class GeometryTests(unittest.TestCase):
    def test_projection_has_metric_scale_and_round_trips(self):
        # One degree along the equator on the chosen sphere is 111195.080234 m.
        self.assertAlmostEqual(PLANE.forward(0, 1)[0], 111195.0802335329, places=6)
        local = builder.Projection(-16.4, -71.5)
        latitude, longitude = local.inverse(*local.forward(-16.42, -71.56))
        self.assertAlmostEqual(latitude, -16.42, places=10)
        self.assertAlmostEqual(longitude, -71.56, places=10)

    def test_projection_onto_segment_has_hand_calculated_result(self):
        fraction, offset, x, y = builder.project_segment((50, 20), (0, 0), (100, 0))
        self.assertEqual((fraction, offset, x, y), (0.5, 20.0, 50.0, 0.0))

    def test_projection_clamps_to_endpoints(self):
        self.assertEqual(builder.project_segment((-3, 4), (0, 0), (100, 0)),
                         (0.0, 5.0, 0.0, 0.0))
        self.assertEqual(builder.project_segment((103, 4), (0, 0), (100, 0)),
                         (1.0, 5.0, 100.0, 0.0))

    def test_degenerate_segment_and_shape(self):
        self.assertEqual(builder.project_segment((3, 4), (0, 0), (0, 0)),
                         (0.0, 5.0, 0.0, 0.0))
        with self.assertRaises(ValueError):
            shape([(0, 0), (0, 0)])

    def test_shape_chainage_uses_all_segments_and_removes_repeated_vertices(self):
        trace = shape([(0, 0), (0, 0), (300, 0), (300, 400)])
        self.assertAlmostEqual(trace.length, 700)
        self.assertAlmostEqual(trace.at(500)[0], 300)
        self.assertAlmostEqual(trace.at(500)[1], 200)
        self.assertEqual(trace.at(-1), trace.points[0])
        self.assertEqual(trace.at(1000), trace.points[-1])

    def test_35_m_boundary_is_included_and_outside_stop_is_rejected(self):
        trace = shape([(0, 0), (1000, 0)])
        source = [stop("inside", 100, 34.999), stop("boundary", 300, 35),
                  stop("outside", 500, 35.001), stop("negative", 700, -35)]
        visits = builder.real_hits(trace, builder.StopGrid(source, PLANE))
        self.assertEqual([value.stop_id for value in visits], ["inside", "boundary", "negative"])
        self.assertTrue(all(value.offset_m <= 35 + 1e-6 for value in visits))

    def test_duplicate_threshold_is_strictly_less_than_60_m(self):
        trace = shape([(0, 0), (1000, 0)])
        source = [stop("a", 0), stop("b", 59.9), stop("c", 60), stop("d", 120)]
        visits = builder.real_hits(trace, builder.StopGrid(source, PLANE))
        self.assertEqual([value.stop_id for value in visits], ["a", "c", "d"])

    def test_corner_is_one_visit_and_has_deterministic_projection(self):
        trace = shape([(0, 0), (500, 0), (500, 500)])
        visits = builder.real_hits(trace, builder.StopGrid([stop("corner", 480, 20)], PLANE))
        self.assertEqual(len(visits), 1)
        self.assertAlmostEqual(visits[0].distance_m, 480)
        self.assertAlmostEqual(visits[0].offset_m, 20)

    def test_loop_keeps_two_separate_visits_to_the_same_real_stop(self):
        trace = shape([(0, 0), (300, 0), (300, 300), (0, 300), (0, 0)])
        visits = builder.real_hits(trace, builder.StopGrid([stop("terminal", 0)], PLANE))
        self.assertEqual([value.stop_id for value in visits], ["terminal", "terminal"])
        self.assertAlmostEqual(visits[0].distance_m, 0)
        self.assertAlmostEqual(visits[1].distance_m, 1200)

    def test_grid_handles_long_diagonal_and_negative_cells(self):
        trace = shape([(-1000, -1000), (1000, 1000)])
        visits = builder.real_hits(trace, builder.StopGrid([stop("centre", 0)], PLANE))
        self.assertEqual(len(visits), 1)
        self.assertAlmostEqual(visits[0].distance_m, math.sqrt(2) * 1000)


class VirtualStopTests(unittest.TestCase):
    def test_sparse_pattern_is_filled_at_400_m_and_includes_endpoints(self):
        trace = shape([(0, 0), (1700, 0)])
        visits, virtual, sparse, initial_gaps = builder.complete_pattern("p", trace, [])
        self.assertEqual([round(v.distance_m) for v in visits], [0, 400, 800, 1200, 1600, 1700])
        self.assertTrue(sparse)
        self.assertEqual(initial_gaps, 1)
        self.assertEqual(len(virtual), 6)
        self.assertTrue(all(v.virtual for v in visits))
        self.assertTrue(all(v.name is None for v in virtual.values()))
        builder.validate_pattern(visits, trace)

    def test_long_gap_is_filled_even_with_at_least_five_real_stops(self):
        trace = shape([(0, 0), (3000, 0)])
        real = [hit(str(i), x) for i, x in enumerate([0, 100, 200, 300, 2800, 2900, 3000])]
        visits, virtual, sparse, initial_gaps = builder.complete_pattern("p", trace, real)
        self.assertFalse(sparse)
        self.assertEqual(initial_gaps, 1)
        self.assertEqual(len(virtual), 6)
        self.assertEqual([v.distance_m for v in visits if v.virtual],
                         [700, 1100, 1500, 1900, 2300, 2700])
        builder.validate_pattern(visits, trace)

    def test_gap_of_exactly_800_m_does_not_create_virtual_stops(self):
        trace = shape([(0, 0), (3200, 0)])
        real = [hit(str(i), x) for i, x in enumerate([0, 800, 1600, 2400, 3200])]
        visits, virtual, sparse, initial_gaps = builder.complete_pattern("p", trace, real)
        self.assertFalse(sparse)
        self.assertEqual((len(virtual), initial_gaps), (0, 0))
        builder.validate_pattern(visits, trace)

    def test_gap_over_800_m_is_filled_without_virtual_next_to_real_stop(self):
        trace = shape([(0, 0), (1101, 0)])
        real = [hit(str(i), x) for i, x in enumerate([0, 100, 901, 1001, 1101])]
        visits, virtual, _, _ = builder.complete_pattern("p", trace, real)
        self.assertEqual(len(virtual), 1)
        self.assertEqual([v.distance_m for v in visits if v.virtual], [500])
        builder.validate_pattern(visits, trace)

    def test_existing_real_stop_takes_priority_over_regular_virtual_grid(self):
        trace = shape([(0, 0), (1700, 0)])
        real = [hit("real", 405)]
        visits, virtual, _, _ = builder.complete_pattern("p", trace, real)
        self.assertIn(real[0], visits)
        self.assertNotIn(400, [round(v.distance_m) for v in visits if v.virtual])
        self.assertTrue(all(abs(v.distance_m - 405) >= 60 for v in visits if v.virtual))
        builder.validate_pattern(visits, trace)

    def test_short_shape_does_not_invent_extra_stops_to_force_a_count_of_five(self):
        trace = shape([(0, 0), (200, 0)])
        visits, virtual, sparse, _ = builder.complete_pattern("short", trace, [])
        self.assertTrue(sparse)
        self.assertEqual(len(virtual), 2)
        self.assertEqual([round(v.distance_m) for v in visits], [0, 200])
        builder.validate_pattern(visits, trace)

    def test_leading_and_trailing_gaps_are_covered(self):
        trace = shape([(0, 0), (4000, 0)])
        real = [hit(str(i), x) for i, x in enumerate([1000, 1100, 1200, 1300, 1400])]
        visits, _, sparse, initial_gaps = builder.complete_pattern("p", trace, real)
        self.assertFalse(sparse)
        self.assertEqual(initial_gaps, 2)
        self.assertAlmostEqual(visits[0].distance_m, 0)
        self.assertAlmostEqual(visits[-1].distance_m, 4000)
        builder.validate_pattern(visits, trace)

    def test_virtual_ids_and_output_are_reproducible(self):
        trace = shape([(0, 0), (1700, 0)])
        self.assertEqual(builder.complete_pattern("p", trace, []),
                         builder.complete_pattern("p", trace, []))

    def test_validation_rejects_out_of_range_unordered_and_distant_stops(self):
        trace = shape([(0, 0), (1000, 0)])
        for invalid in ([hit("a", -1)], [hit("a", 300), hit("b", 200)],
                        [builder.Hit("a", 100, 36, 100, 0, 0)],
                        [hit("a", 0), hit("b", 1000)]):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                builder.validate_pattern(invalid, trace)


class InputTests(unittest.TestCase):
    def setUp(self):
        scratch = TOOL / "output" / "test-work"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name)
        self.write_csv("routes", ["route_id", "route_short_name", "route_color"],
                       [["a", "A", "FF0000"], ["b", "A", "FF0000"]])
        self.write_csv("trips", ["trip_id", "route_id", "shape_id"],
                       [["ta", "a", "sa"], ["tb", "b", "sb"]])
        self.write_csv("stops", ["stop_id", "stop_name", "stop_lat", "stop_lon"],
                       [[str(i), "Source " + str(i), *PLANE.inverse(i * 250, 0)] for i in range(5)])
        points = []
        for name, direction in [("sa", [0, 1000]), ("sb", [1000, 0])]:
            for sequence, x in reversed(list(enumerate(direction))):
                points.append([name, *PLANE.inverse(x, 0), sequence])
        self.write_csv("shapes", ["shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"], points)
        self.network = [{"id": "line-a", "short_name": "A", "color": "#FF0000", "directions": [
            {"kind": "ida", "route_id": "a", "headsign": "East"},
            {"kind": "vuelta", "route_id": "b", "headsign": "West"},
        ]}]
        self.write_network()

    def write_csv(self, name, header, rows):
        with (self.source / (name + ".txt")).open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(header)
            writer.writerows(rows)

    def write_network(self):
        (self.source / "network.json").write_text(json.dumps(self.network), encoding="utf-8")

    def test_both_directions_use_original_shape_sequence_not_csv_row_order(self):
        document = builder.build_document(self.source)
        self.assertEqual(document["summary"]["pattern_count"], 2)
        ida, vuelta = document["patterns"]
        self.assertEqual([s["stop_id"] for s in ida["stops"]], ["0", "1", "2", "3", "4"])
        self.assertEqual([s["stop_id"] for s in vuelta["stops"]], ["4", "3", "2", "1", "0"])
        self.assertEqual(document["summary"]["virtual_stops_unique"], 0)

    def test_unknown_route_and_ambiguous_shape_fail_instead_of_inventing_a_mapping(self):
        self.network[0]["directions"][0]["route_id"] = "missing"
        self.write_network()
        with self.assertRaisesRegex(ValueError, "requires exactly one known shape"):
            builder.build_document(self.source)
        self.network[0]["directions"][0]["route_id"] = "a"
        self.write_network()
        self.write_csv("trips", ["trip_id", "route_id", "shape_id"],
                       [["ta", "a", "sa"], ["extra", "a", "sb"], ["tb", "b", "sb"]])
        with self.assertRaisesRegex(ValueError, "requires exactly one known shape"):
            builder.build_document(self.source)

    def test_empty_or_duplicate_direction_is_rejected(self):
        for directions in ([], [self.network[0]["directions"][0]] * 2):
            self.network[0]["directions"] = directions
            self.write_network()
            with self.assertRaises(ValueError):
                builder.build_document(self.source)

    def test_missing_input_leaves_previous_output_untouched(self):
        output = self.source / "previous.json"
        output.write_text("previous valid output", encoding="utf-8")
        (self.source / "stops.txt").unlink()
        run = subprocess.run([sys.executable, "-B", str(TOOL / "build.py"),
                              "--input-dir", str(self.source), "--output", str(output)],
                             capture_output=True, text=True)
        self.assertEqual(run.returncode, 1)
        self.assertIn("ERROR", run.stderr)
        self.assertEqual(output.read_text(encoding="utf-8"), "previous valid output")

    def test_source_directory_is_protected_from_generated_output(self):
        original = (self.source / "network.json").read_bytes()
        run = subprocess.run([sys.executable, "-B", str(TOOL / "build.py"),
                              "--input-dir", str(self.source),
                              "--output", str(self.source / "network.json")],
                             capture_output=True, text=True)
        self.assertEqual(run.returncode, 1)
        self.assertEqual((self.source / "network.json").read_bytes(), original)

    def test_invalid_coordinates_are_rejected(self):
        for latitude, longitude in [("nan", "0"), ("91", "0"), ("0", "181")]:
            with self.subTest(latitude=latitude, longitude=longitude), self.assertRaises(ValueError):
                builder.coordinates(latitude, longitude)


class ActualArequipaDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = builder.build_document(builder.DEFAULT_INPUT)
        cls.stops, cls.shapes, cls.entries, cls.projection, cls.unmapped = builder.load_source(builder.DEFAULT_INPUT)
        cls.stop_lookup = {stop["stop_id"]: stop for stop in cls.document["stops"]}

    def test_every_catalogued_line_and_direction_has_exactly_one_pattern(self):
        with (builder.DEFAULT_INPUT / "network.json").open(encoding="utf-8-sig") as stream:
            network = json.load(stream)
        expected = {(line["id"], direction["kind"], direction["route_id"])
                    for line in network for direction in line["directions"]}
        actual = {(p["line_id"], p["direction"], p["route_id"]) for p in self.document["patterns"]}
        self.assertEqual(actual, expected)
        self.assertEqual(len(actual), len(self.document["patterns"]))
        self.assertEqual(self.document["summary"]["unmapped_route_ids"], self.unmapped)

    def test_all_actual_patterns_are_ordered_separated_and_have_no_uncovered_large_gaps(self):
        for pattern in self.document["patterns"]:
            with self.subTest(pattern=pattern["pattern_id"]):
                distances = [row["distance_m"] for row in pattern["stops"]]
                self.assertEqual(distances, sorted(distances))
                self.assertGreaterEqual(distances[0], 0)
                self.assertLessEqual(distances[-1], pattern["length_m"] + 1e-6)
                self.assertTrue(all(b - a >= 60 - 2e-6 for a, b in zip(distances, distances[1:])))
                anchors = [0] + distances + [pattern["length_m"]]
                self.assertLessEqual(max(b - a for a, b in zip(anchors, anchors[1:])), 800 + 2e-6)

    def test_source_stop_coordinates_are_within_35_m_of_a_point_on_the_original_shape(self):
        for pattern in self.document["patterns"]:
            trace = self.shapes[pattern["shape_id"]]
            for row in pattern["stops"]:
                source = self.stop_lookup[row["stop_id"]]
                px, py = self.projection.forward(source["latitude"], source["longitude"])
                sx, sy = self.projection.forward(row["shape_latitude"], row["shape_longitude"])
                distance = math.hypot(px - sx, py - sy)
                self.assertLessEqual(distance, 35 + 1e-4, row["stop_id"])
                self.assertAlmostEqual(distance, row["offset_m"], delta=1e-4)
                # Independently find the raw segment containing this chainage,
                # then check collinearity and inclusion using cross/dot products.
                index = min(len(trace.points) - 2,
                            max(0, bisect_left(trace.cumulative, row["distance_m"]) - 1))
                ax, ay = trace.points[index]
                bx, by = trace.points[index + 1]
                dx, dy = bx - ax, by - ay
                segment_length = math.hypot(dx, dy)
                cross_distance = abs((sx - ax) * dy - (sy - ay) * dx) / segment_length
                along = ((sx - ax) * dx + (sy - ay) * dy) / segment_length
                self.assertLessEqual(cross_distance, 1e-4)
                self.assertGreaterEqual(along, -1e-4)
                self.assertLessEqual(along, segment_length + 1e-4)

    def test_regeneration_is_deterministic_and_source_hashes_match(self):
        regenerated = builder.build_document(builder.DEFAULT_INPUT)
        self.assertEqual(json.dumps(self.document, sort_keys=True),
                         json.dumps(regenerated, sort_keys=True))
        import hashlib
        for name, expected in self.document["source_sha256"].items():
            self.assertEqual(expected, hashlib.sha256((builder.DEFAULT_INPUT / name).read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
