"""Functional tests for OSM naming, spatial transfers, SQLite and FTS5."""
from contextlib import closing
import hashlib
import json
import math
from pathlib import Path
import random
import sqlite3
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(TOOL))
import build
import enrich
from osm_source import OsmData,Road,RoadIndex,category,read_osm,usable_name

PLANE = build.Projection(0,0)


def node(identifier,x,y=0):
    return (identifier,*PLANE.inverse(x,y))


def source_stop(identifier,x,y=0,name=None,virtual=False):
    return build.Stop(identifier,name,*PLANE.inverse(x,y),virtual)


def roads():
    return [Road(10,"Avenida Alegría",(node(1,0),node(2,100))),
            Road(11,"Calle Sol",(node(2,100),node(3,100,200))),
            Road(12,"AVENIDA ALEGRIA",(node(4,-100),node(1,0)))]


def place(identifier="fixture-tecsup"):
    return {"place_id":identifier,"name":"TECSUP Arequípa","category":"institute",
            "latitude":0.0,"longitude":0.0,"osm_type":"node","osm_id":100,
            "coordinate_source":"osm_node","tags":{"name":"TECSUP Arequípa"}}


class NamingTests(unittest.TestCase):
    def setUp(self):
        self.index=RoadIndex(roads(),PLANE)

    def test_connected_intersection_retains_osm_ids(self):
        name,evidence=self.index.name_for(*PLANE.inverse(50,10))
        self.assertEqual(name,"Avenida Alegría / Calle Sol")
        self.assertEqual(evidence['intersection_node_osm_id'],2)
        self.assertEqual(evidence['cross_road_osm_id'],11)
        self.assertAlmostEqual(evidence['road_distance_m'],10)

    def test_unnamed_street_is_not_treated_as_a_real_name(self):
        for value in ('','Innominada','S/N','Sin nombre','Calle sin nombre'):
            self.assertFalse(usable_name(value))
        self.assertTrue(usable_name('Avenida Ejército'))

    def test_geometric_crossing_without_shared_node_is_not_an_intersection(self):
        index=RoadIndex([Road(1,'Uno',(node(1,0),node(2,100))),
                         Road(2,'Dos',(node(3,50,-50),node(4,50,50)))],PLANE)
        name,evidence=index.name_for(*PLANE.inverse(50,0))
        self.assertIsNone(name)
        self.assertEqual(evidence['reason'],'nearest_named_road_has_no_named_intersection')

    def test_same_name_connected_fragments_share_their_real_intersection(self):
        name,evidence=self.index.name_for(*PLANE.inverse(-80,0))
        self.assertEqual(name,'AVENIDA ALEGRIA / Calle Sol')
        self.assertEqual(evidence['intersection_node_osm_id'],2)
        self.assertAlmostEqual(evidence['intersection_distance_m'],180)

    def test_distant_same_name_fragment_is_not_joined_by_name_alone(self):
        extra=Road(13,'Avenida Alegría',(node(20,1000),node(21,1100)))
        index=RoadIndex(roads()+[extra],PLANE)
        name,evidence=index.name_for(*PLANE.inverse(1050,0))
        self.assertIsNone(name)
        self.assertEqual(evidence['reason'],'nearest_named_road_has_no_named_intersection')

    def test_road_and_intersection_distance_limits_are_inclusive(self):
        self.assertIsNotNone(self.index.name_for(*PLANE.inverse(0,50))[0])
        self.assertIsNone(self.index.name_for(*PLANE.inverse(0,50.001))[0])
        self.assertIsNotNone(self.index.name_for(*PLANE.inverse(-100,0))[0])
        name,evidence=self.index.name_for(*PLANE.inverse(-100.001,0))
        self.assertIsNone(name)
        self.assertEqual(evidence['reason'],'nearest_named_intersection_too_far')

    def test_nearest_grid_matches_brute_force_on_negative_coordinates(self):
        for x,y in [(-199,-199),(0,0),(50,-30),(250,250),(-120,100)]:
            actual=self.index.nearest(*PLANE.inverse(x,y))
            expected=min((build.project_segment((x,y),a,b)[1],road_id,segment)
                         for segment,(road_id,a,b) in enumerate(self.index.segments))
            self.assertEqual(actual[0],expected[1])
            self.assertAlmostEqual(actual[1],expected[0])

    def test_source_name_is_preserved_without_claiming_official_verification(self):
        row=enrich.enrich_stop(source_stop('s',0,name='Nombre original'),self.index,True)
        self.assertEqual(row['name'],'Nombre original')
        self.assertEqual(row['name_source'],'gtfs_source')
        self.assertEqual(row['source_kind'],'gtfs_candidate')
        self.assertFalse(row['official_name_verified'])
        self.assertTrue(row['used_in_patterns'])

    def test_nearby_street_without_nearby_crossing_is_marked_estimated(self):
        row=enrich.enrich_stop(source_stop('s',-110,name='Innominada'),self.index,False)
        self.assertEqual(row['name_source'],'osm_road')
        self.assertIn('punto estimado',row['name'])
        self.assertTrue(row['needs_review'])
        self.assertEqual(row['original_name'],'Innominada')

    def test_no_close_named_road_uses_explicit_id_instead_of_distant_address(self):
        row=enrich.enrich_stop(source_stop('source-123',0,100,name='Innominada'),self.index,True)
        self.assertEqual(row['name'],'Punto de subida estimado source-123')
        self.assertEqual(row['name_source'],'estimated_id')
        self.assertTrue(row['needs_review'])

    def test_added_virtuals_remain_distinct_from_existing_source_candidates(self):
        row=enrich.enrich_stop(source_stop('v',0,0,virtual=True),self.index,True)
        self.assertEqual(row['source_kind'],'generated_virtual')
        self.assertFalse(row['official_name_verified'])
        self.assertEqual(row['name_source'],'osm_road_intersection')

    def test_bus_stop_and_signal_tags_are_not_street_categories(self):
        self.assertIsNone(category({'highway':'bus_stop','name':'Tecsup'}))
        self.assertIsNone(category({'highway':'traffic_signals','name':'Cruce'}))
        self.assertEqual(category({'highway':'residential'}),'street')
        self.assertEqual(category({'amenity':'college'}),'institute')


class TransferTests(unittest.TestCase):
    def rows(self,points):
        return [{'stop_id':str(i),'latitude':PLANE.inverse(x,y)[0],
                 'longitude':PLANE.inverse(x,y)[1]} for i,(x,y) in enumerate(points)]

    def test_400_m_boundary_and_13_factor(self):
        points=self.rows([(0,0),(400,0),(400.001,0)])
        pairs=list(enrich.transfer_pairs(points,PLANE))
        values={(a,b):(distance,walking) for a,b,distance,walking in pairs}
        self.assertIn(('0','1'),values)
        self.assertEqual(values['0','1'],(400.0,520.0))
        self.assertNotIn(('0','2'),values)
        self.assertAlmostEqual(values['1','2'][0],.001,places=6)

    def test_equal_coordinates_are_allowed_but_not_self_edges_or_duplicate_pairs(self):
        pairs=list(enrich.transfer_pairs(self.rows([(0,0),(0,0),(300,0)]),PLANE))
        self.assertEqual(len(pairs),3)
        self.assertIn(('0','1',0.0,0.0),pairs)
        self.assertTrue(all(a<b for a,b,_,_ in pairs))

    def test_grid_results_match_brute_force_with_negative_cells(self):
        rng=random.Random(42)
        coords=[(rng.uniform(-1200,1200),rng.uniform(-1200,1200)) for _ in range(50)]
        rows=self.rows(coords)
        actual={(a,b) for a,b,_,_ in enrich.transfer_pairs(rows,PLANE)}
        expected={tuple(sorted((str(i),str(j)))) for i in range(len(coords)) for j in range(i)
                  if math.dist(coords[i],coords[j])<=400}
        self.assertEqual(actual,expected)

    def test_sparse_input_does_not_run_all_pairs(self):
        statistics={}
        pairs=list(enrich.transfer_pairs(self.rows([(i*2000,0) for i in range(500)]),PLANE,statistics))
        self.assertEqual(pairs,[])
        self.assertEqual(statistics['distance_evaluations'],0)
        self.assertEqual(statistics['all_possible_pairs'],124750)

    def test_invalid_parameters_and_duplicate_ids_are_rejected(self):
        for radius,factor in [(0,1.3),(math.inf,1.3),(400,.9),(400,math.inf)]:
            with self.subTest(radius=radius,factor=factor),self.assertRaises(ValueError):
                list(enrich.transfer_pairs(self.rows([(0,0)]),PLANE,radius_m=radius,walk_factor=factor))
        row=self.rows([(0,0)])[0]
        with self.assertRaises(ValueError):
            list(enrich.transfer_pairs([row,row],PLANE))


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        work=TOOL/'output/test-work'
        work.mkdir(parents=True,exist_ok=True)
        self.directory=tempfile.TemporaryDirectory(dir=work)
        self.addCleanup(self.directory.cleanup)
        self.path=Path(self.directory.name)/'enrichment.sqlite'
        index=RoadIndex(roads(),PLANE)
        self.stops=[enrich.enrich_stop(source_stop('a',0,name='A'),index,True),
                    enrich.enrich_stop(source_stop('b',300,name='B'),index,True)]
        self.data=OsmData(roads(),[place()],[],{'test_fixture':True})

    def test_saved_database_has_complete_names_and_both_transfer_directions(self):
        summary=enrich.save_database(self.path,self.stops,self.data,PLANE,{'test_fixture':True})
        self.assertEqual(summary['validation']['unnamed_stops'],0)
        with closing(sqlite3.connect(self.path)) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM stops').fetchone()[0],2)
            self.assertEqual(db.execute('SELECT count(*) FROM transfers').fetchone()[0],1)
            self.assertEqual(db.execute('SELECT count(*) FROM transfer_edges').fetchone()[0],2)
            self.assertEqual(db.execute('SELECT to_stop_id FROM transfer_edges WHERE from_stop_id=?',('b',)).fetchone()[0],'a')
            self.assertEqual(db.execute('SELECT walk_distance_m FROM transfers').fetchone()[0],390)
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])

    def test_fts_search_is_accent_insensitive_prefix_aware_and_safe_for_punctuation(self):
        enrich.save_database(self.path,self.stops,self.data,PLANE,{})
        with closing(sqlite3.connect(self.path)) as db:
            self.assertEqual(enrich.search_places(db,'tecsup arequipa')[0]['name'],'TECSUP Arequípa')
            self.assertEqual(enrich.search_places(db,'TECS arequí')[0]['place_id'],'fixture-tecsup')
            self.assertEqual(enrich.search_places(db,'--- !!!'),[])
            self.assertEqual(enrich.search_places(db,'" OR 1=1; DROP TABLE places;'),[])
            self.assertEqual(db.execute('SELECT count(*) FROM places').fetchone()[0],1)
            with self.assertRaises(ValueError):enrich.search_places(db,'tecsup',0)

    def test_failed_validation_preserves_the_last_successful_database(self):
        enrich.save_database(self.path,self.stops,self.data,PLANE,{})
        previous=self.path.read_bytes()
        with self.assertRaisesRegex(ValueError,'TECSUP'):
            enrich.save_database(self.path,self.stops,OsmData(roads(),[],[],{}),PLANE,{})
        self.assertEqual(self.path.read_bytes(),previous)
        self.assertFalse(self.path.with_suffix('.sqlite.tmp').exists())

    def test_cli_rejects_pattern_output_that_would_overwrite_the_osm_extract(self):
        pbf=Path(self.directory.name)/'source.osm.pbf'
        original=b'original source bytes'
        pbf.write_bytes(original)
        result=subprocess.run([sys.executable,'-B',str(TOOL/'build.py'),'--enrich',
                               '--osm-pbf',str(pbf),'--output',str(pbf)],
                              capture_output=True,text=True)
        self.assertEqual(result.returncode,1)
        self.assertIn('must not overwrite the OSM extract',result.stderr)
        self.assertEqual(pbf.read_bytes(),original)

    def test_hash_and_metadata_describe_the_database_without_official_stop_claims(self):
        summary=enrich.save_database(self.path,self.stops,self.data,PLANE,{'test_fixture':True})
        self.assertEqual(summary['database_sha256'],hashlib.sha256(self.path.read_bytes()).hexdigest())
        with closing(sqlite3.connect(self.path)) as db:
            metadata=dict(db.execute('SELECT key,value FROM metadata'))
            self.assertIn('OpenStreetMap',json.loads(metadata['attribution']))
            self.assertEqual(db.execute('SELECT sum(official_name_verified) FROM stops').fetchone()[0],0)


class ReaderTests(unittest.TestCase):
    def test_osm_reader_retains_named_roads_but_does_not_turn_bus_stops_into_streets(self):
        work=TOOL/'output/test-work';work.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as directory:
            xml=Path(directory)/'sample.osm'
            xml.write_text('''<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="unit-test">
<node id="1" version="1" lat="0" lon="0"/>
<node id="2" version="1" lat="0" lon="0.001"/>
<node id="3" version="1" lat="0.001" lon="0.001"/>
<node id="4" version="1" lat="0.0002" lon="0.0002"><tag k="amenity" v="college"/><tag k="name" v="TECSUP Arequipa"/></node>
<node id="5" version="1" lat="0.0003" lon="0.0003"><tag k="highway" v="bus_stop"/><tag k="name" v="Parada"/></node>
<way id="10" version="1"><nd ref="1"/><nd ref="2"/><tag k="highway" v="residential"/><tag k="name" v="Calle Uno"/></way>
<way id="11" version="1"><nd ref="2"/><nd ref="3"/><tag k="highway" v="residential"/><tag k="name" v="S/N"/></way>
</osm>''',encoding='utf-8')
            data=read_osm(xml,(-1,-1,1,1))
            self.assertEqual([road.name for road in data.roads],['Calle Uno'])
            self.assertTrue(any(p['name']=='TECSUP Arequipa' for p in data.places))
            self.assertFalse(any(p['name']=='Parada' for p in data.places))
            self.assertEqual(len(data.inventory),1)


class ActualEnrichmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path=TOOL/'output/enrichment.sqlite'
        if not cls.path.is_file():
            raise RuntimeError('Generate the actual 1B database with build.py --enrich before this suite')

    def test_all_original_candidates_have_a_nonempty_name_and_preserved_coordinates(self):
        source,_,_,_,_=build.load_source(build.DEFAULT_INPUT)
        with closing(sqlite3.connect(self.path)) as db:
            rows={row[0]:row[1:] for row in db.execute(
                'SELECT stop_id,name,latitude,longitude,source_kind,official_name_verified FROM stops')}
            for stop in source:
                row=rows[stop.identifier]
                self.assertTrue(usable_name(row[0]))
                self.assertEqual((row[1],row[2]),(stop.latitude,stop.longitude))
                self.assertEqual(row[3:],('gtfs_candidate',0))

    def test_all_derived_names_respect_distance_limits_and_estimated_labels_are_explicit(self):
        with closing(sqlite3.connect(self.path)) as db:
            for stop_id,name,kind,review,evidence in db.execute(
                    'SELECT stop_id,name,name_source,needs_review,name_evidence_json FROM stops'):
                evidence=json.loads(evidence)
                if kind=='osm_road_intersection':
                    self.assertLessEqual(evidence['road_distance_m'],50+1e-6)
                    self.assertLessEqual(evidence['intersection_distance_m'],200+1e-6)
                    self.assertIn('intersection_node_osm_id',evidence)
                elif kind=='osm_road':
                    self.assertLessEqual(evidence['road_distance_m'],50+1e-6)
                    self.assertIn('punto estimado',name)
                    self.assertEqual(review,1)
                elif kind=='estimated_id':
                    self.assertEqual(name,'Punto de subida estimado '+stop_id)
                    self.assertEqual(review,1)

    def test_transfer_distances_and_indexing_are_valid_for_every_pair(self):
        with closing(sqlite3.connect(self.path)) as db:
            metadata=dict(db.execute('SELECT key,value FROM metadata'))
            model=json.loads(metadata['distance_model'])
            projection=build.Projection(model['latitude_origin'],model['longitude_origin'])
            coordinates={identifier:projection.forward(lat,lon)
                         for identifier,lat,lon in db.execute('SELECT stop_id,latitude,longitude FROM stops')}
            for a,b,direct,walking in db.execute('SELECT * FROM transfers'):
                self.assertLess(a,b)
                actual=math.dist(coordinates[a],coordinates[b])
                self.assertLessEqual(actual,400+1e-6)
                self.assertAlmostEqual(direct,actual,delta=1e-6)
                self.assertAlmostEqual(walking,actual*1.3,delta=1e-6)
            stats=json.loads(metadata['summary'])['transfers']
            self.assertLess(stats['distance_evaluations'],stats['all_possible_pairs'])
            self.assertTrue(any(row[1]=='transfers_to' for row in db.execute('PRAGMA index_list(transfers)')))
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])

    def test_tecsup_is_a_real_osm_institute_in_the_accent_insensitive_search(self):
        with closing(sqlite3.connect(self.path)) as db:
            found=enrich.search_places(db,'tecsup arequipa')
            self.assertTrue(any(p['category']=='institute' and p['osm_type']=='way'
                                and p['osm_id']==409177970 for p in found))
            self.assertEqual(enrich.search_places(db,'tecsup arequípa'),found)
            categories={r[0] for r in db.execute('SELECT DISTINCT category FROM places')}
            self.assertTrue({'university','institute','hospital','market','shopping_centre','square',
                             'terminal','municipality','school','park','place_of_worship','street',
                             'neighbourhood'}.issubset(categories))
            db.execute("INSERT INTO places_fts(places_fts,rank) VALUES('integrity-check',1)")


if __name__=='__main__':unittest.main()
