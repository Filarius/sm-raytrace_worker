SCALE = 1.0 / 20
import bpy
import bmesh
import struct

# sys.path.insert(0, r"D:\FILES\Code\20180527 tf2 tracert\python")

file = open(r"D:\FILES\Code\20180527 tf2 tracert\python\hits.data", "rb")
# file = open(r"D:\FILES\Code\20180527 tf2 tracert\python\server_output.txt","rb")

verts = []

cnt = 0
rec = 110000
mark = [0 * 10000, rec * 10000]
while True:
    #    file.read(12)
    packed = file.read(12)
    if len(packed) != 12:
        break
    cnt += 1
    if mark[0] > cnt:
        continue
    if mark[1] < cnt:
        break

    if not packed:
        break
    unpacked = struct.unpack("<3f", packed)
    lst = list(unpacked)
    for i in range(len(lst)):
        lst[i] = lst[i] * SCALE
    verts.append(lst)
file.close()

file = open(r"D:\FILES\Code\20180527 tf2 tracert\python\faces.data", "rb")
faces = []
print("sd")
while True:
    #    file.read(12)
    packed = file.read(12)
    if not packed:
        break
    if len(packed) != 12:
        break
    unpacked = struct.unpack("<3i", packed)
    faces.append(unpacked)
file.close

mesh = bpy.data.meshes.new("mesh")  # add a new mesh
obj = bpy.data.objects.new("MyObject", mesh)  # add a new object using the mesh

scene = bpy.context.scene
scene.objects.link(obj)  # put the object into the scene (link)

scene.objects.active = obj  # set as the active object in the scene

obj.select = True  # select object

mesh = bpy.context.object.data

bm = bmesh.new()
for i in range(len(verts)):
    verts[i] = bm.verts.new(verts[i])
''''''
for face in faces:
    try:
        bm.faces.new([verts[face[0]], verts[face[1]], verts[face[2]]])
    finally:
        pass
''''''

# make the bmesh the object's mesh
bm.to_mesh(mesh)
bm.free()  # always do this when finished

'''
v2 = bm.verts.new(verts[0]) 
v1 = None

for v in verts:
    v2 = bm.verts.new(v)  # add a new vert
    if v1 == None:
        v1 = v2
    else:
        v3 = bm.verts.new((v[0]+0.1,v[1]+0.1,v[2]+0.1))
        #v3 = bm.verts.new(v)
        bm.faces.new((v1,v2,v3))
        v1 = None

# make the bmesh the object's mesh
bm.to_mesh(mesh)
bm.free()  # always do this when finished
'''

