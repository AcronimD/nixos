"""Small functional check: save a .blend, export a cube STL, render on CPU."""
import bpy
import os

output = os.environ.get("THREED_TEST_OUTPUT", "/home/alex/3d-verification")
os.makedirs(output, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4
scene.render.resolution_x = 160
scene.render.resolution_y = 120
scene.render.resolution_percentage = 100
scene.render.filepath = os.path.join(output, "cube-render.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(output, "cube.blend"))
bpy.ops.object.select_all(action="DESELECT")
cube = bpy.data.objects["Cube"]
cube.select_set(True)
bpy.context.view_layer.objects.active = cube
bpy.ops.export_mesh.stl(filepath=os.path.join(output, "cube.stl"), use_selection=True, global_scale=10)
bpy.ops.render.render(write_still=True)
print("BLENDER_FUNCTIONAL_CHECK_OK", bpy.app.version_string, output)
