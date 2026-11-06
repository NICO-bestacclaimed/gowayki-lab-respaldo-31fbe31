"""1C geometry, editable configuration and published pack contract tests."""
from contextlib import closing
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

TOOL=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(TOOL))
import build
import city_pack
from enrich import search_places


class SimplificationTests(unittest.TestCase):
    def test_straight_shape_keeps_endpoints(self):
        points=[(0,0),(25,0),(50,0),(100,0)]
        self.assertEqual(city_pack.simplify_indices(points,8),[0,3])

    def test_eight_metre_boundary_is_inclusive(self):
        self.assertEqual(city_pack.simplify_indices([(0,0),(50,8),(100,0)],8),[0,2])
        self.assertEqual(city_pack.simplify_indices([(0,0),(50,8.01),(100,0)],8),[0,1,2])

    def test_closed_loop_preserves_shape_instead_of_collapsing(self):
        points=[(0,0),(100,0),(100,100),(0,100),(0,0)]
        kept=city_pack.simplify_indices(points,8)
        self.assertEqual(kept,[0,1,2,3,4])
        self.assertLessEqual(city_pack.maximum_deviation(points,kept),8)

    def test_deviation_bound_is_checked_between_each_pair_of_kept_vertices(self):
        points=[(i,math.sin(i/12)*20) for i in range(600)]
        kept=city_pack.simplify_indices(points,8)
        self.assertEqual(kept,sorted(set(kept)))
        self.assertLess(len(kept),len(points))
        self.assertLessEqual(city_pack.maximum_deviation(points,kept),8)

    def test_large_nearly_straight_input_uses_no_recursive_stack(self):
        points=[(i,math.sin(i/100)) for i in range(10000)]
        self.assertEqual(city_pack.simplify_indices(points,8),[0,9999])

    def test_invalid_inputs_are_rejected(self):
        for points,tolerance in [([],8),([(0,0)],8),([(0,0),(1,0)],0),([(0,0),(1,0)],math.inf)]:
            with self.subTest(points=points,tolerance=tolerance),self.assertRaises(ValueError):
                city_pack.simplify_indices(points,tolerance)


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.config=json.loads(city_pack.DEFAULT_CONFIG.read_text(encoding='utf-8'))

    def test_default_values_match_the_requested_model(self):
        city_pack.validate_config(self.config)
        self.assertEqual([band['speed_kmh'] for band in self.config['speed_bands']],
                         [22,14,18,15,18,13,22,None])
        self.assertEqual(self.config['frequency_minutes_by_period'],{'peak':6,'off_peak':10,'night':15})
        self.assertEqual(self.config['walking_speed_m_per_min'],75)
        self.assertEqual((self.config['access_max_m'],self.config['access_fallback_max_m']),(800,1500))
        self.assertEqual(self.config['default_fare'],{'currency':'PEN','amount':1})

    def test_each_minute_has_one_band_and_midnight_is_no_service(self):
        bands=self.config['speed_bands']
        for minute in range(1440):
            self.assertEqual(sum(city_pack.band_contains(band,minute) for band in bands),1)
        for clock,speed in [('00:00',None),('04:59',None),('05:00',22),('07:00',14),
                            ('12:00',15),('17:00',13),('22:59',22),('23:00',None)]:
            band=next(b for b in bands if city_pack.band_contains(b,city_pack.minute(clock)))
            self.assertEqual(band['speed_kmh'],speed)

    def test_overlapping_and_missing_bands_are_rejected(self):
        for change in ('overlap','gap'):
            config=deepcopy(self.config)
            if change=='overlap':config['speed_bands'][1]['start']='06:00'
            else:config['speed_bands'].pop()
            with self.subTest(change=change),self.assertRaises(ValueError):city_pack.validate_config(config)

    def test_bad_fares_versions_and_access_are_rejected(self):
        mutations=[('data_version',0),('data_version',True),('walking_speed_m_per_min',0),
                   ('access_fallback_max_m',100),('geometry_tolerance_m',math.nan)]
        for key,value in mutations:
            config=deepcopy(self.config);config[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):city_pack.validate_config(config)
        config=deepcopy(self.config);config['default_fare']['amount']=-1
        with self.assertRaises(ValueError):city_pack.validate_config(config)

    def test_invalid_clock_values_are_rejected(self):
        for clock in ('24:00','05:60','5:00','-1:00'):
            with self.subTest(clock=clock),self.assertRaises(ValueError):city_pack.minute(clock)


class ActualPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory=city_pack.DEFAULT_ASSETS
        cls.manifest=city_pack.verify_manifest(cls.directory)
        cls.document=json.loads(build.DEFAULT_OUTPUT.read_text(encoding='utf-8'))
        cls.source,cls.shapes,_,cls.projection,_=build.load_source(build.DEFAULT_INPUT)

    def test_manifest_checks_hashes_sizes_version_and_geometry(self):
        self.assertEqual(self.manifest['version'],1)
        self.assertEqual(self.manifest['schema_version'],1)
        self.assertEqual(self.manifest['size_bytes'],(self.directory/'pack.sqlite').stat().st_size)
        self.assertEqual(self.manifest['sha256'],hashlib.sha256((self.directory/'pack.sqlite').read_bytes()).hexdigest())
        self.assertLessEqual(self.manifest['geometry']['max_deviation_m'],8+1e-6)
        self.assertLess(self.manifest['geometry']['simplified_points'],self.manifest['geometry']['original_points'])

    def test_all_catalog_lines_patterns_and_stop_visits_are_packaged(self):
        with closing(sqlite3.connect((self.directory/'pack.sqlite').as_uri()+'?mode=ro',uri=True)) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM lines').fetchone()[0],98)
            self.assertEqual(db.execute('SELECT count(*) FROM patterns').fetchone()[0],len(self.document['patterns']))
            self.assertEqual(db.execute('SELECT count(*) FROM pattern_stops').fetchone()[0],
                             sum(len(p['stops']) for p in self.document['patterns']))
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])
            self.assertEqual(db.execute('PRAGMA quick_check').fetchone()[0],'ok')
            for pattern in self.document['patterns']:
                actual=db.execute('SELECT stop_id,distance_m FROM pattern_stops WHERE pattern_id=? ORDER BY stop_sequence',
                                  (pattern['pattern_id'],)).fetchall()
                self.assertEqual(actual,[(r['stop_id'],r['distance_m']) for r in pattern['stops']])

    def test_uncatalogued_route_is_preserved_but_not_invented_as_a_pattern(self):
        with closing(sqlite3.connect((self.directory/'pack.sqlite').as_uri()+'?mode=ro',uri=True)) as db:
            row=db.execute('SELECT line_id,direction,pattern_available FROM routes WHERE route_id=?',('17684887',)).fetchone()
            self.assertEqual(row,(None,None,0))
            self.assertEqual(db.execute('SELECT count(*) FROM patterns WHERE route_id=?',('17684887',)).fetchone()[0],0)
            self.assertEqual(db.execute('SELECT count(*) FROM routes').fetchone()[0],192)
        self.assertEqual(self.manifest['excluded_from_routing'],[
            {'route_id':'17684887','reason':'missing_from_network_catalog'}])

    def test_geojson_preserves_source_colors_and_lon_lat_order(self):
        data=json.loads((self.directory/'routes.geojson').read_text(encoding='utf-8'))
        source=build.read_csv(build.DEFAULT_INPUT/'routes.txt',{'route_id','route_color'})
        colors={row['route_id']:'#'+row['route_color'].lstrip('#').upper() for row in source}
        self.assertEqual(len(data['features']),len(source))
        for feature in data['features']:
            self.assertEqual(feature['properties']['route_color'],colors[feature['id']])
            self.assertEqual(feature['geometry']['type'],'LineString')
            self.assertGreaterEqual(len(feature['geometry']['coordinates']),2)
            for longitude,latitude in feature['geometry']['coordinates']:
                self.assertTrue(-72<longitude<-71)
                self.assertTrue(-17<latitude<-16)

    def test_vertex_chainages_keep_original_distances_for_future_leg_clipping(self):
        with closing(sqlite3.connect((self.directory/'pack.sqlite').as_uri()+'?mode=ro',uri=True)) as db:
            for shape_id,geojson,distances_json,length in db.execute(
                    'SELECT shape_id,geometry_json,vertex_distances_json,length_m FROM shapes'):
                if shape_id not in self.shapes:continue
                original=self.shapes[shape_id]
                coordinates=json.loads(geojson)['coordinates'];distances=json.loads(distances_json)
                self.assertEqual(len(coordinates),len(distances))
                self.assertEqual(distances[0],0)
                self.assertAlmostEqual(distances[-1],original.length,delta=1e-6)
                self.assertEqual(distances,sorted(distances))
                self.assertAlmostEqual(length,original.length,delta=1e-6)
                for (lon,lat),distance in zip(coordinates,distances):
                    self.assertLessEqual(math.dist(original.at(distance),self.projection.forward(lat,lon)),.00003)

    def test_pack_keeps_enrichment_and_search_without_tildes(self):
        with closing(sqlite3.connect((self.directory/'pack.sqlite').as_uri()+'?mode=ro',uri=True)) as db:
            self.assertTrue(any(row['osm_id']==409177970 for row in search_places(db,'tecsup arequipa')))
            self.assertEqual(search_places(db,'tecsup arequipa'),search_places(db,'tecsup arequípa'))
            self.assertEqual(db.execute('SELECT count(*) FROM transfers').fetchone()[0],85154)
            self.assertEqual(db.execute('SELECT count(*) FROM stops WHERE name IS NULL OR trim(name)=? ',('',)).fetchone()[0],0)
            self.assertEqual(db.execute('SELECT sum(official_name_verified) FROM stops').fetchone()[0],0)

    def test_config_is_editable_and_a_line_fare_can_override_the_city_fare(self):
        work=TOOL/'output/test-work';work.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as directory:
            with closing(sqlite3.connect((self.directory/'pack.sqlite').as_uri()+'?mode=ro',uri=True)) as source:
                with closing(sqlite3.connect(Path(directory)/'editable.sqlite')) as db:
                    source.backup(db)
                    default=json.loads(db.execute("SELECT value_json FROM config WHERE key='default_fare'").fetchone()[0])
                    self.assertEqual(default,{'amount':1.0,'currency':'PEN'})
                    line=db.execute('SELECT line_id FROM lines ORDER BY line_id LIMIT 1').fetchone()[0]
                    db.execute('INSERT INTO line_fares VALUES(?,?,?)',(line,1.5,'PEN'))
                    self.assertEqual(db.execute('SELECT amount FROM line_fares WHERE line_id=?',(line,)).fetchone()[0],1.5)
                    db.execute("UPDATE config SET value_json=? WHERE key='walking_speed_m_per_min'",('80',))
                    self.assertEqual(json.loads(db.execute("SELECT value_json FROM config WHERE key='walking_speed_m_per_min'").fetchone()[0]),80)

    def test_manifest_detects_tampered_files(self):
        work=TOOL/'output/test-work';work.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as directory:
            target=Path(directory)
            (target/'manifest.json').write_bytes((self.directory/'manifest.json').read_bytes())
            (target/'pack.sqlite').write_bytes(b'corrupt test fixture')
            (target/'routes.geojson').write_bytes((self.directory/'routes.geojson').read_bytes())
            with self.assertRaisesRegex(ValueError,'mismatch'):city_pack.verify_manifest(target)


if __name__=='__main__':unittest.main()
