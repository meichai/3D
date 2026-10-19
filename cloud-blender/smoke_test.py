"""Run inside Blender. Each invocation requires a new empty output directory."""
import bpy
import bmesh
import sys
import json
import platform
import traceback
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
out.mkdir(parents=True, exist_ok=True)
if any(p.name != 'blender.log' for p in out.iterdir()):
    raise RuntimeError('Refusing to overwrite existing output files')
report = {'timestamp_utc': datetime.now(timezone.utc).isoformat(),
          'blender': bpy.app.version_string, 'blender_python': sys.version,
          'os': platform.platform(), 'checks': [], 'exports': {}}

def check(name, passed, **details):
    report['checks'].append(dict(name=name, passed=bool(passed), **details))

def mesh_info(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    bm.normal_update()
    info = dict(vertices=len(bm.verts), edges=len(bm.edges), faces=len(bm.faces),
                closed=all(e.is_manifold for e in bm.edges),
                degenerate_faces=sum(f.calc_area() < 1e-12 for f in bm.faces),
                volume_mm3=abs(bm.calc_volume(signed=True)))
    bm.free()
    return info

try:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    # 1 Blender coordinate = 1 mm. STL/OBJ have no reliable unit metadata.
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.001
    scene.unit_settings.length_unit = 'MILLIMETERS'
    bpy.ops.mesh.primitive_cube_add(size=2)
    cube = bpy.context.object
    cube.name = 'CloudTestCube_50mm'
    cube.dimensions = (50, 50, 50)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    dims = list(cube.dimensions)
    check('source_dimensions_50mm', all(abs(x-50) < 1e-4 for x in dims), dimensions_mm=dims)
    info = mesh_info(cube)
    check('source_mesh_integrity', info['closed'] and info['vertices']==8 and info['faces']==6 and info['degenerate_faces']==0 and abs(info['volume_mm3']-125000)<0.1, **info)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'cube_50mm.blend'))
    bpy.ops.preferences.addon_enable(module='io_scene_fbx')
    for fmt in ('stl', 'obj', 'fbx'):
        path = out / ('cube_50mm.'+fmt)
        try:
            bpy.ops.object.select_all(action='DESELECT')
            cube.select_set(True)
            bpy.context.view_layer.objects.active = cube
            if fmt == 'stl':
                bpy.ops.wm.stl_export(filepath=str(path), export_selected_objects=True, global_scale=1, use_scene_unit=False)
            elif fmt == 'obj':
                bpy.ops.wm.obj_export(filepath=str(path), export_selected_objects=True, global_scale=1)
            else:
                bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={'MESH'}, global_scale=1, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', bake_anim=False)
            check(fmt+'_file', path.is_file() and path.stat().st_size>0)
            before = set(bpy.data.objects)
            if fmt == 'stl':
                bpy.ops.wm.stl_import(filepath=str(path), use_scene_unit=False)
            elif fmt == 'obj':
                bpy.ops.wm.obj_import(filepath=str(path))
            else:
                bpy.ops.import_scene.fbx(filepath=str(path))
            imported = [o for o in set(bpy.data.objects)-before if o.type=='MESH']
            check(fmt+'_roundtrip_count', len(imported)==1)
            for obj in imported:
                # Bake importer object transforms before measuring topology/volume.
                obj.data.transform(obj.matrix_world)
                obj.matrix_world.identity()
                obj.data.update()
                bpy.context.view_layer.update()
                rdims = list(obj.dimensions)
                ri = mesh_info(obj)
                check(fmt+'_roundtrip_dimensions', all(abs(d-50)<0.001 for d in rdims), dimensions_mm=rdims)
                check(fmt+'_roundtrip_integrity', ri['closed'] and ri['degenerate_faces']==0 and abs(ri['volume_mm3']-125000)<1, **ri)
            for obj in set(bpy.data.objects)-before:
                bpy.data.objects.remove(obj, do_unlink=True)
            report['exports'][fmt] = dict(path=path.name, bytes=path.stat().st_size)
        except Exception:
            check(fmt+'_exception', False, error=traceback.format_exc())
except Exception:
    check('fatal_exception', False, error=traceback.format_exc())
finally:
    report['passed'] = bool(report['checks']) and all(c['passed'] for c in report['checks'])
    (out/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (out/'report.txt').write_text('\n'.join([f"Blender {report['blender']}", f"Overall: {'PASS' if report['passed'] else 'FAIL'}"] + [f"{'PASS' if c['passed'] else 'FAIL'} {c['name']}" for c in report['checks']])+'\n', encoding='utf-8')
if not report['passed']:
    raise RuntimeError('Blender smoke test failed; see report.json')
