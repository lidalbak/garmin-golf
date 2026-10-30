#!/usr/bin/env python3
"""Check the production import/packaging pipeline against retained source bytes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from map_scene import scene_for, clip

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("acquire", ROOT/"scripts/acquire_courses.py")
acquire=importlib.util.module_from_spec(spec)
spec.loader.exec_module(acquire)

class CourseBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((ROOT/"data/courses.json").read_text())

    def test_source_identity(self):
        for course in self.data["courses"]:
            raw=ROOT/"data"/(course["id"]+"-raw.osm")
            self.assertEqual(hashlib.sha256(raw.read_bytes()).hexdigest(),course["rawSha256"])

    def test_import_is_reproducible_from_original_bytes(self):
        actual={"schemaVersion":1,"courses":[acquire.normalize(*config,False) for config in acquire.CONFIG]}
        self.assertEqual(actual,self.data)

    def test_unique_complete_hole_coverage(self):
        self.assertEqual(len(self.data["courses"]),2)
        for course in self.data["courses"]:
            self.assertEqual([h["number"] for h in course["holes"]],list(range(1,19)))

    def test_green_assignment_and_target_meaning(self):
        for course in self.data["courses"]:
            for hole in course["holes"]:
                self.assertTrue(acquire.inside(hole["center"],hole["green"]))
                self.assertEqual(hole["center"],hole["path"][-1])
                self.assertEqual(hole["tee"],hole["path"][0])
                self.assertEqual(hole["targetKind"],"osm-hole-endpoint")

    def test_ambiguous_indices_stay_unknown(self):
        bogstad=self.data["courses"][0]
        for number in (12,16):
            h=bogstad["holes"][number-1]
            self.assertIsNone(h["strokeIndex"])
            self.assertEqual(h["sourceStrokeIndex"],18)
        valid=[h["strokeIndex"] for h in self.data["courses"][1]["holes"]]
        self.assertEqual(sorted(valid),list(range(1,19)))

    def test_resources_preserve_geometry(self):
        for course in self.data["courses"]:
            for hole in course["holes"]:
                path=ROOT/"resources/courses"/(course["id"]+str(hole["number"])+".json")
                resource=json.loads(path.read_text())
                self.assertEqual(resource["green"],hole["green"])
                self.assertEqual(resource["path"],hole["path"])
                self.assertEqual(resource["hazards"],[{"type":h["type"],"points":h["points"]} for h in hole["hazards"]])

    def test_attribution_and_provenance_retained(self):
        for course in self.data["courses"]:
            self.assertEqual(course["license"],"ODbL-1.0")
            self.assertIn("OpenStreetMap",course["attribution"])
            self.assertTrue(course["sourceUrl"].startswith("https://api.openstreetmap.org/"))

    def test_scene_is_reproducible_and_bounded(self):
        for course in self.data["courses"]:
            for hole in course["holes"]:
                scene=scene_for(course,hole)
                resource=json.loads((ROOT/"resources/courses"/(course["id"]+str(hole["number"])+".json")).read_text())
                self.assertEqual(scene,resource["scene"])
                self.assertLessEqual(len(scene["canopySymbols"]),600)
                self.assertTrue(all(surface["kind"] in ("grass","rough","forest","water","fairway","tee","bunker","green") for surface in scene["surfaces"]))

    def test_polygon_clipping_does_not_invent_a_surface(self):
        outside=[[10,10],[11,10],[11,11],[10,11]]
        self.assertEqual(clip(outside,[0,0,1,1]),[])
        square=[[-1,-1],[2,-1],[2,2],[-1,2]]
        clipped=clip(square,[0,0,1,1])
        self.assertEqual(len(clipped),4)
        self.assertTrue(all(0<=x<=1 and 0<=y<=1 for x,y in clipped))

if __name__=="__main__": unittest.main(verbosity=2)
