from server import Server
from marks import Marks
from time import sleep, time
import struct
import math

# populate angle_tree map
# direction -> angles
# order :  -x +x -y +y -z +z
ANGLE_TREE = {
                0: {'a': 0,   'b': 180, 'c': 0},
                1: {'a': 0,   'b': 0,   'c': 0},
                2: {'a': 0,   'b': -90, 'c': 0},
                3: {'a': 0,   'b': 90,  'c': 0},
                4: {'a': 90,  'b': 0,   'c': 0},
                5: {'a': -90, 'b': 0,   'c': 0},
            }


def ray_set_direction(ray, dir, precision):
        ray = dict(ray)
        angle = ANGLE_TREE[dir]
        # convert zoom maping to real coordinates
        ray['x'] *= precision
        ray['y'] *= precision
        ray['z'] *= precision
        ray['a'] = angle['a']
        ray['b'] = angle['b']
        ray['c'] = angle['c']

        return ray


class Grabber:
    def __init__(self, addr_list, precision=100 ):
        if not isinstance(addr_list, list):
            raise AttributeError

        self._servers = []
        self._servers = [Server(address) for address in addr_list]
        self._servIndex = 0

        self._precision = precision

        self.ray_map_marks = Marks()
        self.hits = dict()  # point coords and distance to nearest grid node
        self.jobDone = False
        self.doneCount = 0
        self.raysCount = 0
        self.timeDelta = 0

        # populate directions tree
        self._directionTree = {
                (-1, 0, 0): 0,
                (1, 0, 0): 1,
                (0, -1, 0): 2,
                (0, 1, 0): 3,
                (0, 0, -1): 4,
                (0, 0, 1): 5
        }

        #debug
        self.min = precision


        self._hitFile = open("hits.data","wb")

    # distance between points

    def _set_next_server(self):
        self._servIndex += 1
        if self._servIndex == len(self._servers):
            self._servIndex = 0

    def _create_ray(self, x, y, z, a, b, c):
        ray = dict(
            x=x,
            y=y,
            z=z,
            a=a,
            b=b,
            c=c,
        )
        return ray

    # create ray from reference ray in given direction from infinity or not


    '''
    def _ray_get_direction(self,vector):
        #normalize
        a = vector[0]
        b = vector[1]
        c = vector[2]
        r = math.sqrt(a*a+b*b+c*c)
        a = a / r
        b = b / r
        c = c / r
        z = 0.8
        if a < -z:
            return
    '''

    def _make_ray_tree(self, ray, todo=[0 for x in range(3 * 3 * 3 * 6)], vector=None):
        '''
        def _1(ray, dx, dy, dz):
            return

        # def _2(todo,t,i):
        def _2(todo, t, i, dx, dy, dz):

            # todo.append((t[0], t[1], t[2], i)
            # todo.add((t[0], t[1], t[2], i))
            todo[(dx + 1) * 6 * 3 * 3 + (dy + 1) * 6 * 3 + (dz + 1) * 6 + i] = (t[0], t[1], t[2], i)
        '''

        # _ = []

        # prepare index shift for directed ray
        # create ray in same direction after hit
        # todo = []
        # todo = set()
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                for dz in [-1, 0, 1]:
                    # if (dx == 0) and (dy == 0) and (dz == 0):
                    #    continue
                    '''r = dict()
                    r['x'] = ray['x'] + dx
                    r['y'] = ray['y'] + dy
                    r['z'] = ray['z'] + dz
                    '''
                    t = (ray['x'] + dx,ray['y'] + dy,ray['z'] + dz)
                    #t = _1(ray, dx, dy, dz)

                    # tbl = (sign+dir,r['x'],r['y'],r['z'])
                    '''
                    i=0
                    for sign in ['-', '+']:
                        for dir in ['x', 'y', 'z']:
                            ti = (r['x'], r['y'], r['z'],i)
                            val = self._ray_map_marks.get(ti,True)
                            if val:  # no rays from this point
                                new_ray = self._raySetDirection(r, sign + dir, inf=False)
                                _.append(new_ray)
                                self._ray_map_marks.set(ti, False)
                            i += 1
                    '''
                    # i = 0
                    for i in range(6):
                        # _2(todo,t,i,dx,dy,dz)
                        todo[(dx + 1) * 6 * 3 * 3 + (dy + 1) * 6 * 3 + (dz + 1) * 6 + i] = (t[0], t[1], t[2], i)
                        # ti = (t[0], t[1], t[2], i)
                        # todo.append(ti)

                        # ti = (ray['x']+dx, ray['y']+dy, ray['z']+ dz, i)
                        # ti = (r['x'], r['y'], r['z'], i)

                        # new_ray = self._raySetDirection(r, i, inf=False)
                        # _.append(new_ray)

                        # val = self._ray_map_marks.get(ti, True)
                        # if val:  # no rays from this point

                        #    self._ray_map_marks.set(ti, False)
                        # i += 1
        for r in todo:
            if abs(ray['x']-r[0])>2:
                print('кавабанга')
            if abs(ray['y']-r[1])>2:
                print('кавабанга')
            if abs(ray['z']-r[2])>2:
                print('кавабанга')

        return todo

    def init(self):
        ray = self._create_ray(0, 0, 0, 0, 0, 0)
        ray_tree = self._make_ray_tree(ray)
        jobs = []
        for ray in ray_tree:  # ray = (x,y,z,dir)
            new_ray = list(ray)[:3]
            new_ray.extend([0, 0, 0])
            new_ray = self._create_ray(*new_ray)
            jobs.append(ray_set_direction(new_ray, ray[3], self._precision))
        # self.tf2.addTrace(ray_tree)
        # self.addJobs(ray_tree)
        self.add_jobs(jobs)

    def _distance(self, pnt, ri):
        distX = abs(pnt[0] - ri[0])
        distY = abs(pnt[1] - ri[1])
        distZ = abs(pnt[2] - ri[2])
        dist = distX if distX > distY else distY
        if distZ > dist:
            dist = distZ
        return dist

    def _chunkIt(self, seq, num):
        avg = len(seq) / float(num)

        last = 0.0

        while last < len(seq):
            yield seq[int(last):int(last + avg)]
            last += avg

    def add_jobs(self, rays):
        if isinstance(rays, list):
            for sub_rays, server in zip(self._chunkIt(rays, len(self._servers)), self._servers):
                server.queueIn.put(sub_rays)

    '''
    def chunks(l, n):
        """ Yield n successive chunks from l.
        """
        newn = int(len(l) / n)
        for i in xrange(0, n - 1):
            yield l[i * newn:i * newn + newn]
        yield l[n * newn - newn:]
        '''

    def _vector_to_dir(self, vector):
        # 0 = -x
        # 1 = +x
        # 2 = -y
        # 3 = +y
        # 4 = -z
        # 5 = +z
        max = 0.0
        k = -1

        #print("len vector", len(vector))
        #print("vector", vector)
        #print("range", list(range(len(vector))))
        for i in range(len(vector)):
            if max < abs(vector[i]):
                max = abs(vector[i])
                print('k ')
                k = i
        if k == -1:
            print(vector)
            raise AttributeError

        l = (k * 2)

        if vector[k] > 0:
            l += 1
        '''
        s = ['+','-'][0 if vector[k]>0 else 1]
        s = s + ['x','y','z'][k]
        norm_vector = [0,0,0]
        norm_vector[k] = 1 if vector[k]>0 else -1
        '''
        return l

    def process(self):
        self.timeDelta = 0

        # if self._tf2.queueOut.empty(): #no data to get right now
        #    return

        # print("mark1")
        rays = []
        for server in self._servers:
            if not server.queueOut.empty():
                # rays.extend(self.tf2.getPoints())
                rays.extend(server.get_points())

        # rays = self.tf2.getPoints()
        dt = time()

        self.doneCount = 0
        step = self._precision

        # print("mark2")


        # mark job done
        # dict_keys = ['x','y','z','hx','hy','hz']

        f = lambda x: int(round(x / step))
        fToReal = lambda x: x * step

        todo = set()
        for ray in rays:

            vector = (
                -(ray['x'] - ray['hx']),
                -(ray['y'] - ray['hy']),
                -(ray['z'] - ray['hz']),
            )


            '''
            m = 40000
            if abs(ray['hx']) > m:
                continue
            if abs(ray['hy']) > m:
                continue
            if abs(ray['hz']) > m:
                continue
            '''


            m = self._precision * 2
            
            if abs(vector[0]) > m:
                continue
            if abs(vector[1]) > m:
                continue
            if abs(vector[2]) > m:
                continue





            #ignore hit from inside of solid body
            lng = abs(vector[0]) + abs(vector[1]) + abs(vector[2])
            if lng == 0.0:
                continue

            # detect fully traced trace paths
            # "10" by 2 times is me1 if (abs(vector[0] - 10) < 1) else 0
            # then 100 is direction marker
            d1 = 1 if (abs(vector[0] - 10) < 0.1) else 0
            d2 = 1 if (abs(vector[1] - 10) < 0.1) else 0
            d3 = 1 if (abs(vector[2] - 10) < 0.1) else 0





            d = d1 + d2 + d3

            # generate new rays

            if d <= 1:  # ray hit something

                x = f(ray['x'])
                y = f(ray['y'])
                z = f(ray['z'])
                ri = (x, y, z)

                '''
                xr = fToReal(ray['x'])
                yr = fToReal(ray['y'])
                zr = fToReal(ray['z'])
                node = (xr, yr, zr)
                '''

                node = (ray['x'], ray['y'], ray['z'])

                hit = (ray['hx'], ray['hy'], ray['hz'])
                hi = (f(hit[0]), f(hit[1]), f(hit[2]))

                #self.ray_map_marks.set_ray(ri,hi,None,3)



                # add or update hits
                """
                last = self.hits.get(hi, None)
                if last == None:
                    self.hits[hi] = (hit, distance(hit, node))
                    string_hit = struct.pack("<3f", *hit)
                    self._hitFile.write(string_hit)
                # update point to nearest to grid node
                else:
                    dist = distance(hit, node)
                    if self.hits[hi][1] > dist:
                        self.hits[hi] = (hit, dist)
                """

                '''
                last = self.hits.get(ri, None)
                if last == None:
                    self.hits[hi] = node
                    string_hit = struct.pack("<3f", *node)
                    self._hitFile.write(string_hit)
                '''

                if not hi in self.hits:
                    self.hits[hi] = hit
                    #string_hit = struct.pack("<3f", *hit)
                    string_hit = struct.pack("<6f", *hit,*node)
                    self._hitFile.write(string_hit)

                todo_temp = [0 for x in range(3 * 3 * 3 * 6)]  # speedup buffer ?
                new_set = self._make_ray_tree(self._create_ray(x, y, z, 0, 0, 0), todo_temp)
                todo.update(new_set)

                # new_ray = self._createRay(x, y, z, 0, 0, 0)
                # rays_todo.extend(self._makeRayTree(new_ray, vector))
                self.doneCount += 1

        self._hitFile.flush()

        t = self.ray_map_marks.data.intersection(todo)
        # t = todo.intersection(self._ray_map_marks.nested)
        todo.difference_update(t)
        # todo.difference_update(self._ray_map_marks.nested)
        self.ray_map_marks.data.update(todo)
        rays_todo = []
        for data in todo:
            ray = self._create_ray(data[0], data[1], data[2], 0, 0, 0)
            direction = data[3]
            rays_todo.append(ray_set_direction(ray, direction, self._precision))

        if len(rays_todo) > 0:
            self.add_jobs(rays_todo)

        self.timeDelta = time() - dt