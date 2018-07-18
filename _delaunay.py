import numpy as np
import itertools as it
import struct
import itertools
import math
import numpy
import scipy.spatial
from time import time
now = time()
file = open(r"hits.data","rb")
cnt = 0
verts = []
print("load")
while True:
    #    file.read(12)
    packed = file.read(12)

    if not packed:
        break

    if len(packed) != 12:
        break

    if cnt > 1000:
        break

    cnt += 1
    unpacked = struct.unpack("<3f", packed)
    verts.append(unpacked)
    #tri.AddPoint(de.Point(*unpacked))
print("loaded")
array = numpy.array(verts)
tri = scipy.spatial.Delaunay(array, qhull_options="Qt Qbb Qc Qz Qx")
tetras = tri.simplices

def distance(a,b):
    s = 0
    for x,y in zip(a,b):
        s+= (x-y)*(x-y)
    return math.sqrt(s)

def take_triangles(tetras,max_dist):
    tris = set()
    for tetra in tetras:
        #tetra = [verts[i] for i in tetra]
        bad_edges = []
        flag = False
        for a,b in itertools.combinations( tetra,  2): #iterating by 3 verts
            if distance(verts[a],verts[b]) > max_dist:
                #bad_edges.append((a,b))
                flag = True
                break
        if flag:
            #continue
            pass
        '''
        for a, b, c in itertools.combinations(tetra, 3):
            if (a,b) in bad_edges:
                continue
            if (a,c) in bad_edges:
                continue
            if (b,c) in bad_edges:
                continue
        '''
        for x, y, z in itertools.combinations(tetra, 3):
            if x > y:
                t = x
                x = y
                y = t
            if y > z:
                t = y
                y = z
                z = t
            if x > y:
                t = x
                x = y
                y = t
            tris.add((x,y,z))
            '''
            flag = True
            for x,y,z in itertools.permutations([a,b,c],3):
                if (x,y,z) in tris:
                    flag = False
                    break
            if flag:
                tris.extend((a,b,c))
            '''
    return tris




print("before")
tris = take_triangles(tetras,20*2)
print("after")
file = open(r"faces.data","wb")
for tri in tris:
    file.write(struct.pack('<3i', *tri))
file.close()
print("done")
print(time() - now)


