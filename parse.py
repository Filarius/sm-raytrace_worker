import struct
import lzma

HEADER_LUMPS = 64
HEADER_LUMP_SIZE = 16

LUMP_ENTITIES = 0
LUMP_PLANES = 1
LUMP_TEXDATA = 2
LUMP_VERTEXES = 3
LUMP_VISIBILITY = 4
LUMP_NODES = 5
LUMP_TEXINFO = 6
LUMP_FACES = 7
LUMP_LIGHTING = 8
LUMP_OCCLUSION = 9
LUMP_LEAFS = 10
LUMP_FACEIDS = 11
LUMP_EDGES = 12
LUMP_SURFEDGES = 13
LUMP_MODELS = 14
LUMP_WORLDLIGHTS = 15
LUMP_LEAFFACES = 16
LUMP_LEAFBRUSHES = 17
LUMP_BRUSHES = 18
LUMP_BRUSHSIDES = 19
LUMP_AREAS = 20
LUMP_AREAPORTALS = 21
LUMP_UNUSED0 = 22
LUMP_UNUSED1 = 23
LUMP_UNUSED2 = 24
LUMP_UNUSED3 = 25
LUMP_DISPINFO = 26
LUMP_ORIGINALFACES = 27
LUMP_PHYSDISP = 28
LUMP_PHYSCOLLIDE = 29
LUMP_VERTNORMALS = 30
LUMP_VERTNORMALINDICES = 31
LUMP_DISP_LIGHTMAP_ALPHAS = 32
LUMP_DISP_VERTS = 33
LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS = 34
LUMP_GAME_LUMP = 35
LUMP_LEAFWATERDATA = 36
LUMP_PRIMITIVES = 37
LUMP_PRIMVERTS = 38
LUMP_PRIMINDICES = 39
LUMP_PAKFILE = 40
LUMP_CLIPPORTALVERTS = 41
LUMP_CUBEMAPS = 42
LUMP_TEXDATA_STRING_DATA = 43
LUMP_TEXDATA_STRING_TABLE = 44
LUMP_OVERLAYS = 45
LUMP_LEAFMINDISTTOWATER = 46
LUMP_FACE_MACRO_TEXTURE_INFO = 47
LUMP_DISP_TRIS = 48
LUMP_PHYSCOLLIDESURFACE = 49
LUMP_WATEROVERLAYS = 50
LUMP_LEAF_AMBIENT_INDEX_HDR = 51
LUMP_LEAF_AMBIENT_INDEX = 52
LUMP_LIGHTING_HDR = 53
LUMP_WORLDLIGHTS_HDR = 54
LUMP_LEAF_AMBIENT_LIGHTING_HDR = 55
LUMP_LEAF_AMBIENT_LIGHTING = 56
LUMP_XZIPPAKFILE = 57
LUMP_FACES_HDR = 58
LUMP_MAP_FLAGS = 59
LUMP_OVERLAY_FADES = 60


class lump_t: #size 16
    def __init__(self,s:bytes,big_s):
        data = struct.unpack('3i 4s',s)
        self.fileofs = data[0]
        self.filelen = data[1]
        self.version = data[2]
        self.fourcc = data[3]
        self.data = big_s[self.fileofs:self.fileofs+self.filelen]

    def __len__(self):
        return HEADER_LUMP_SIZE


class dheader_t:# size = 1036
    def __init__(self,s:bytes):
        data = s[0:1036]
        data = struct.unpack("2i {0}s i".format(HEADER_LUMPS*HEADER_LUMP_SIZE), data)
        self.ident = data[0]
        self.version = data[1]
        lumps = []
        for i in range(HEADER_LUMPS):
            l = i*HEADER_LUMP_SIZE
            r = l + HEADER_LUMP_SIZE
            lump_data = data[2][l:r]
            lump = lump_t(lump_data,s)
            lumps.append(lump)
        self.lumps_h = lumps
        self.lumps = {i:None for i in range(64)}
        self.lumps[LUMP_PLANES] = self._read_lump(LUMP_PLANES,lumpPlanes,s)
        self.lumps[LUMP_VERTEXES] = self._read_lump(LUMP_VERTEXES, lumpVertexes, s)
        self.map_revision = data[3]

    def _read_lump(self, lump_id, t_class, data:bytes):
        lump = self.lumps_h[lump_id]
        data = data[lump.fileofs:lump.fileofs+lump.filelen]
        if data.find(b"LZMA")==0:
            f = open('data',"wb")
            f.write(data)
            f.close()
            zip = lzma_hh(data)
            #data = data[4:]
            #data = lzma.decompress(data)
        return t_class(data)

class lzma_hh:# size = 17
    def __init__(self, s:bytes):
        data = struct.unpack("<4s I I 5s", s[:17])
        dic_size = struct.unpack("<I",s[12+1:12+1+4])
        dic_size = dic_size[0]
        d = struct.unpack("B", s[12:12+1])
        d = d[0]
        lc = d % 9
        d = d // 9
        pb = d // 5
        lp = d % 5
        filter_1 = lzma._decode_filter_properties(lzma.FILTER_LZMA1, data[3])
        filter_2 = {
         "id":lzma.FILTER_LZMA1,
         "pb":pb,
         "lp":lp,
         "lc":lc,
         "dict_size": dic_size
        }
        data = lzma.decompress(s[17:], lzma.FORMAT_RAW, filters=[filter_2])
        a=1


class lumpVertexes:
    def __init__(self, s:bytes):
        assert( (len(s) % 4*3)==0)
        #vertex is 3 floats coordinates
        f = struct.unpack("{0}f".format(len(s)/4))
        self.vertexes = [ [ f[i*3], f[i*3+1], f[i*3+2] ] for i in range(len(s) / 3)]

class lumpPlanes:
    def __init__(self, s:bytes):
        #assert ((len(s) % 20) == 0)
        i = 0
        while i < len(s):
            plane = dplane_t()
            data = s[i:i+len(plane)]
            data = struct.unpack("3f f I", data)
            plane.normal = data[0:3]
            plane.distance = data[3]
            plane.type = data[4]
            i = i + len(plane)

class dplane_t:# size=20
    def __init__(self):
        self.normal = (0,0,0)
        self.distance = 0.0
        self.type = 0

    def __len__(self):
        return 20

class cplane_t:# size=20
    def __init__(self):
        self.normal = [0]*3
        self.distance = 0.0
        self.type = 0
        self.sign_bits = 0
        self.pad = [0]*2

class dedge_t:
    pass





file = open('ctf_2fort.bsp','rb')
s = file.read()
file.close()

header = dheader_t(s)

