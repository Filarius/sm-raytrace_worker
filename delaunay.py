import scipy.spatial.kdtree
import struct


#import sys
#sys.setrecursionlimit(10000)
_MAX_DISTANCE = None
_PRECISION = None

class PointTree:
    def __init__(self,data):
        self._kd = scipy.spatial.kdtree.KDTree(data)

def set_precision(p):
    _PRECISION = p
    _MAX_DISTANCE = p*2.5

def load_points(path:str):
    file = open(r"hits.data", "rb")
    cnt = 0
    verts = []
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
    file.close()
    return verts

verts = load_points('hits.data')