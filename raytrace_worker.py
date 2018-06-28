#import dataset
#import operator
# import pymesh
#import numpy as np
#import valve.rcon
import socket
from multiprocessing import Process,Queue

from time import sleep, time
import struct



scale = 0.003




'''
sock = socket.socket()
sock.connect(('192.168.1.110', 40000))
sock.send(b'\00'+ b'1234')

data = sock.recv(1024)
sock.close()

print(data)


'''
'''
def save(data):
    output = open('data.pkl', 'wb')
    pickle.dump(data, output)
    output.close()

def load():
    input = open('data.pkl', 'rb')
    data = pickle.load(input)
    input.close()
    return data
'''

INFINITY = 1000.0


class Storage:
    def __init__(self):
        self._nested = set()
        #self._nested = dict()
        self.nested = self._nested
        self.readCount = 0
        self.writeCount = 0
        pass

    def set(self,rd_index,value):
        self.writeCount += 1
        self._nested.add(rd_index)
        #self._nested[rd_index] = value

        '''
        root = self._nested
        for i in range(len(rd_index)-1):
            leaf = root.get(rd_index[i], None)
            if leaf == None:
                leaf = dict()
                root[rd_index[i]] = leaf
            root = leaf
        i += 1
        root[rd_index[i]] = value
        '''


    def get(self,rd_index,default = None):
        self.readCount += 1
        #return self._nested.get(rd_index, default)
        #return False if rd_index in self._nested else default
        return False if set([rd_index]).intersection(self._nested)  else default
        #return False if set([rd_index]).isdisjoint(self._nested) else default


        '''
        root = self._nested
        for i in range(len(rd_index)):
            leaf = root.get(rd_index[i], None)
            if leaf == None:
                return None
        return leaf
        '''

    #populate Storage in indexes differs only in one dimersin
    def setRay(self,start,end,value):
        set()
        flag = False
        k = -1
        for i in range(len(start)):
            if start[i] != end[i]:
                if flag:
                    raise AttributeError
                flag = True
                k=i
        inx = list(start)
        for i in range(start[k], end[k]):
            inx[k] = i
            self.set(tuple(inx), value)



    def iterate(self, root=None):
        if root is None:
            root = self._nested
        if isinstance(root[0], dict):
            for leaf in root:
                self.iterate(leaf)
        else:
            for leaf in root:
                yield leaf



class TF2_DB:
    def __init__(self, address):
        #self._db = dataset.connect(url)
        #self._rcon = valve.rcon.RCON(("192.168.1.110", 27015), "pass")
        #self._rcon.connect();
        #self._rcon.authenticate();
        self.queueIn = Queue(1000)
        self.queueOut = Queue(1000)
        self._runFlag = True
        self._sock = socket.socket()
        self._sock.connect(address)
        self._packetSize = 100000
        self._bufferLimit = 4096 - 24

        self._procOut = Process(target=self._ProcLoopOut,
                                       args=(self.queueIn, self.queueOut))

        self._procIn = Process(target=self._ProcLoopIn,
                                       args=(self.queueIn, self.queueOut))
        self._procIn.start()
        self._procOut.start()


    def _ProcLoopIn(self, inp, outp):
        data = b""
        packetSize = self._packetSize
        sock = self._sock
        while self._runFlag:
            while (len(data) < (24)):
                newdata = sock.recv(packetSize * 6 * 4)
                if newdata:
                    data += newdata

            size = len(data)
            size = size - (size % 24)
            hits = []
            for i in range(0, size, 24):
                encoded = data[i:i + 24]
                hit = struct.unpack("<6f", encoded)
                # print("{:.2f} {:.2f} {:.2f} {:.2f} {:.2f} {:.2f}".format(*hit))
                hits.append(hit)

            size = len(data)
            if (size % 24) != 0:
                data = data[: -(size % 24) ] # last not encoded data
            else:
                data = b""
            outp.put(hits)


    def _ProcLoopOut(self, inp, outp):
        context = self
        hits = []
        data = b""
        inpS = b""
        indxIn = 0
        lst = []
        sock = self._sock
        packetSize = self._packetSize

        while self._runFlag:
           # if not inp.empty():
                if not lst: #list empty
                    while True: #take all, but wait at last one
                        lst = []
                        lst.extend(inp.get())
                        if inp.empty():
                            break;
                    #print("list got!")
                while indxIn < len(lst):
                    ray = lst[indxIn]
                    #print("ray")
                    #print(ray)
                    indxIn += 1
                    lray = [ray['x'], ray['y'], ray['z'], ray['a'], ray['b'], ray['c']]
                    inpS += struct.pack(">6f", *lray)
                    #print(inpS)
                    if len(inpS) >= self._bufferLimit:
                        break

                sock.sendall(inpS)
                inpS = b""


                if indxIn == len(lst):
                    lst = []
                    indxIn = 0


    def addTrace(self, jobs):
        #l = len(jobs)
        self.queueIn.put(jobs)

        '''
        t = time()
        self._jobsToRcon(jobs)
        print('speed ', l / (time()-t) )
        '''

        '''
        if isinstance(jobs, list):
            self._db['job_query'].insert_many(jobs, chunk_size=1000, ensure=False)
        else:
            self._db['job_query'].insert(jobs)
        '''

    def getPoints(self):
        lst = []
        while True: # get at last 1 time
            rays = self.queueOut.get()
            if self.queueOut.empty():
                break;
        for ray in rays:
            r=dict()
            r['x'] = ray[0]
            r['y'] = ray[1]
            r['z'] = ray[2]
            r['hx'] = ray[3]
            r['hy'] = ray[4]
            r['hz'] = ray[5]
            lst.append(r)
        return lst

    def deletePoints(self, maxId):
        pass
        #statement = 'DELETE FROM `job_done` WHERE `id`<=' + str(maxId) + ';'
        #self._db.query(statement)


class Grabber:
    def __init__(self, addr_list, precision=100,):
        #self._tf2 = TF2_DB('mysql+pymysql://mysql:mysql@localhost/tf2')
        #self._tf2 = TF2_DB('mysql+mysqlconnector://mysql:mysql@localhost/tf2')
        #self._tf2 = TF2_DB('mysql+cymysql://mysql:mysql@localhost/tf2')
        #self._tf2 = TF2_DB('mysql+mysqldb://mysql:mysql@localhost/tf2') #fastest ?

        if not isinstance(addr_list,list):
            raise AttributeError

        self._servers = []
        for address in addr_list:
            server = TF2_DB(address)
            self._servers.append(server)
        self._servIndex = 0

        #self.tf2 = TF2_DB(('192.168.1.110', 40000)) #fastest ?
        self._precision = precision
        # ray maps are maps of
        #self._ray_map_marks = dict()
        self._ray_map_marks = Storage()
        self.ray_map_marks = self._ray_map_marks
        self.hits = dict()  # point coords and distance to nearest grid node
        self.jobDone = False
        self.doneCount = 0
        self.raysCount = 0
        self.timeDelta = 0

        #populate angle_tree map
        self._angleTree = []
        for i in range(6):
            val = dict()
            if i == 0:
                val['a'] = 0
                val['b'] = 180
                val['c'] = 0
            if i == 1:
                val['a'] = 0
                val['b'] = 0
                val['c'] = 0
            if i == 2:
                val['a'] = 0
                val['b'] = -90
                val['c'] = 0
            if i == 3:
                val['a'] = 0
                val['b'] = 90
                val['c'] = 0
            if i == 4:
                val['a'] = 90
                val['b'] = 0
                val['c'] = 0
            if i == 5:
                val['a'] = -90
                val['b'] = 0
                val['c'] = 0
            self._angleTree.append(val)



    # distance between points

    def _setNextServer(self):
        self._servIndex += 1
        if self._servIndex == len(self._servers):
            self._servIndex = 0


    def _createRay(self, x, y, z, a, b, c):
        ray = dict(
            x=x,
            y=y,
            z=z,
            a=a,
            b=b,
            c=c,
        )
        return ray

    createRay = _createRay

    # create ray from reference ray in given direction from infinity or not
    def _raySetDirection(self, ray, dir, inf=True):
        ray = dict(ray)
        angle = self._angleTree[dir]
        '''
        if dir == '+x':
            ray['a'] = 0
            ray['b'] = 0
            ray['c'] = 0
        if dir == '-x':
            ray['a'] = 0
            ray['b'] = 180
            ray['c'] = 0
        if dir == '+y':
            ray['a'] = 0
            ray['b'] = 90
            ray['c'] = 0
        if dir == '-y':
            ray['a'] = 0
            ray['b'] = -90
            ray['c'] = 0
        if dir == '+z':
            ray['a'] = -90
            ray['b'] = 0
            ray['c'] = 0
        if dir == '-z':
            ray['a'] = 90
            ray['b'] = 0
            ray['c'] = 0

        
        x = dir[1]
        y = dir[0] == '+'
        z = self._precision if y else -self._precision
        ray[x] += z
        '''
        # convert zoom maping to real coordinates
        ray['x'] *= self._precision
        ray['y'] *= self._precision
        ray['z'] *= self._precision
        ray['a'] = angle['a']
        ray['b'] = angle['b']
        ray['c'] = angle['c']

        # if infinity - shift ray start position based on direction
        #if inf:
        #    ray[dir[1]] = -INFINITY if (dir[0] == '+') else +INFINITY
            # pass

        return ray

    def _makeRayTree(self, ray, vector=None):
        #_ = []

        # prepare index shift for directed ray
        # create ray in same direction after hit
        todo = []
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                for dz in [-1, 0, 1]:
                    #if (dx == 0) and (dy == 0) and (dz == 0):
                    #    continue
                    #r = dict()
                    # r['x'] = ray['x'] + dx
                    # r['y'] = ray['y'] + dy
                    # r['z'] = ray['z'] + dz
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
                    i = 0
                    for i in range(6):
                            ti = (ray['x']+dx, ray['y']+dy, ray['z']+ dz, i)
                            todo.append(ti)
                            #new_ray = self._raySetDirection(r, i, inf=False)
                            #_.append(new_ray)

                            #val = self._ray_map_marks.get(ti, True)
                            #if val:  # no rays from this point

                            #    self._ray_map_marks.set(ti, False)
                            #i += 1




        return (todo)

    def init(self):
        ray = self._createRay(0, 0, 0, 0, 0, 0)
        ray_tree = self._makeRayTree(ray)
        jobs = []
        for ray in ray_tree: # ray = (x,y,z,dir)
            new_ray = list(ray)[:3]
            new_ray.extend([0,0,0])
            new_ray = self._createRay(*new_ray)
            jobs.append(self._raySetDirection(new_ray,ray[3]))
        # self.tf2.addTrace(ray_tree)
        #self.addJobs(ray_tree)
        self.addJobs(jobs)


    def _distance(self,pnt, ri):
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

    def addJobs(self, rays):
        if isinstance(rays,list):
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
    def _vectorToDir(self, vector):
        # 0 = -x
        # 1 = +x
        # 2 = -y
        # 3 = +y
        # 4 = -z
        # 5 = +z
        max = 0.0
        k=-1

        print("len vector", len(vector))
        print("vector", vector)
        print("range",list(range(len(vector))))
        for i in range(len(vector)):
            if max < abs(vector[i]):
                max = abs(vector[i])
                print('k ')
                k=i
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

        #print("mark1")
        rays=[]
        for server in self._servers:
            if not server.queueOut.empty():
                #rays.extend(self.tf2.getPoints())
                rays.extend(server.getPoints())

        #rays = self.tf2.getPoints()
        dt = time()
        distance = self._distance
        self.doneCount = 0
        step = self._precision

        #print("mark2")
        rays_todo = []
        db_id = 0
        # mark job done
        # dict_keys = ['x','y','z','hx','hy','hz']

        f = lambda x: int(round(x / step))
        fToReal = lambda x: x * step

        #print("mark3")
        #print(len(rays))
        todo = set()
        for ray in rays:
            #if db_id < ray['id']:
            #    db_id = ray['id']

            vector = (
                -(ray['x'] - ray['hx']),
                -(ray['y'] - ray['hy']),
                -(ray['z'] - ray['hz']),
            )

            '''
            m = self._precision * 3
            if abs(vector[0]) > m:
                continue
            if abs(vector[1]) > m:
                continue
            if abs(vector[2]) > m:
                continue
            '''

            # detect fully traced trace paths
            # "10" by 2 times is means raytrace hit nothing
            # then 100 is direction marker
            d1 = 1 if (abs(vector[0] - 10) < 1) else 0
            d2 = 1 if (abs(vector[1] - 10) < 1) else 0
            d3 = 1 if (abs(vector[2] - 10) < 1) else 0

            d = d1 + d2 + d3

            # generate new rays
            if d <= 1:  # ray hit something
                x = f(ray['x'])
                y = f(ray['y'])
                z = f(ray['z'])
                ri = (x, y, z)


                xr = fToReal(ray['x'])
                yr = fToReal(ray['y'])
                zr = fToReal(ray['z'])
                node = (xr, yr, zr)

                hit = (ray['hx'], ray['hy'], ray['hz'])
                hi = (f(hit[0]), f(hit[1]), f(hit[2]))

                #dir = self._vectorToDir(vector)

                '''
                self._ray_map_marks.setRay((x, y, z, dir),
                                           (hi[0], hi[1], hi[2], dir),
                                           True
                                          )
                '''


                # add or update hits
                last = self.hits.get(hi, None)
                if last == None:
                    self.hits[hi] = (hit, distance(hit, node))
                # update point to nearest to grid node
                else:
                    dist = distance(hit, node)
                    if self.hits[hi][1] > dist:
                        self.hits[hi] = (hit, dist)

                # self.toStepCoords(ray)
                new_set = self._makeRayTree(self.createRay(x,y,z,0,0,0))
                todo.update(new_set)

                #new_ray = self._createRay(x, y, z, 0, 0, 0)
                #rays_todo.extend(self._makeRayTree(new_ray, vector))
                self.doneCount += 1

        t = self._ray_map_marks.nested.intersection(todo)
        #t = todo.intersection(self._ray_map_marks.nested)
        todo.difference_update(t)
        # todo.difference_update(self._ray_map_marks.nested)
        self._ray_map_marks.nested.update(todo)
        rays_todo = []
        for data in todo:
            ray = self._createRay(data[0],data[1],data[2],0,0,0)
            dir = data[3]
            rays_todo.append(self._raySetDirection(ray,dir))



                # remove existed rays
                # for ray in rays_todo:
        if len(rays_todo) > 0:
            # sub_rays = list(self.chunkIt(rays_todo, len(self._servers)))
            # servers = self._servers
            # for sub_rays, server in zip(self.chunkIt(rays_todo, len(self._servers)), self._servers):
            #     server.queueIn.put(sub_rays)
            self.addJobs(rays_todo)
            '''
            self._servers[self._servIndex]
            self._servIndex += 1
            if self._servIndex == len(self._servers):
                self._servIndex = 0
            '''


            # self._tf2.addTrace(rays_todo)
        # cleanup in DB
        if db_id > 0:
            self._tf2.deletePoints(db_id)
        #print("mark end")
        self.timeDelta = time() - dt


# import csv
# file = open('data.csv','w',newline='')
# writer = csv.writer(file,delimiter=',')



if __name__ == '__main__':

        servers = []
        servers.append(('192.168.1.110', 40000))
        #servers.append(('192.168.1.110', 40001))
        #servers.append(('192.168.1.110', 40002))
        grab = Grabber(addr_list=servers, precision=10)

        grab.init()
        #sleep(1)
        '''
        try:
            grab.hits = load()
            print('loaded')
        except:
            pass
        '''
        try: # do while CTRL + C  not pressed
            i = 0
            gtime = time()
            startTime = time()
            cnt = 0
            timeStep = 1
            import os
            #while i <= 1000:
            while startTime > time()-60:
               # print(i)
                i += 1
                #sleep(0.1)

                grab.process()
                cnt += grab.doneCount

                if time() > (gtime+timeStep):
                    if cnt > 0:
                        print("")
                        print('g speed ', cnt / (time() - gtime))
                        print('g count ', cnt)
                        gtime = time()
                        timeStep = 1
                        cnt = 0
                        try:
                            if grab.doneCount == 0:
                                continue
                            speed = grab.doneCount / grab.timeDelta
                            print('speed: ', speed)
                            print('i= ',i,' , hits=  ', len(grab.hits))
                            print('time: ', grab.timeDelta)
                            print('count: ', grab.doneCount)

                        except ZeroDivisionError:
                            pass

                    else:
                        timeStep += 1
                        print('nothing i ',i)




                # grab.hitsRemoveNearest()
                '''
                try:
                    if grab.doneCount == 0:
                        continue
                    speed = grab.doneCount / grab.timeDelta
                    os.system('cls' if os.name=='nt' else 'clear')
                    print('speed: ', speed)
                    print(i, '  ', len(grab.hits))
                    print('time: ', grab.timeDelta)
                    print('count: ', grab.doneCount )
                    print("")
                except ZeroDivisionError:
                    pass
                
                '''
            print('hits count',len(grab.hits))
            print("Storage size", len(grab.ray_map_marks.nested))
            print("read count", grab.ray_map_marks.readCount)
            print("write count", grab.ray_map_marks.writeCount)


        except KeyboardInterrupt:
            pass

        # save(grab.hits)

        print('!')


        # trying to interact with blender
        if (1 == 1):
            verts = []
            for p in grab.hits.values():
                p = p[0]
                p = (p[0] * scale, p[1] * scale, p[2] * scale)
                verts.append(p)

            import bpy
            import bmesh

            #verts = list(zip(*grab.hits.values()))[0]  # magic to get only coordinates


            mesh = bpy.data.meshes.new("mesh")  # add a new mesh
            obj = bpy.data.objects.new("MyObject", mesh)  # add a new object using the mesh

            scene = bpy.context.scene
            scene.objects.link(obj)  # put the object into the scene (link)

            scene.objects.active = obj  # set as the active object in the scene
            obj.select = True  # select object
            mesh = bpy.context.object.data
            bm = bmesh.new()

            for v in verts:
                bm.verts.new(v)  # add a new vert

            # make the bmesh the object's mesh
            bm.to_mesh(mesh)
            bm.free()  # always do this when finished

        else:

            # from mpl_toolkits.mplot3d import Axes3D
            import matplotlib.pyplot as plt

            print(len(grab.hits))
            if (len(grab.hits) > 0):
                # x = [a[0] for a in grab.hits if (abs(a[0])< 900) ]
                # y = [a[1] for a in grab.hits if (abs(a[1])< 900) ]
                # z = [a[2] for a in grab.hits if (abs(a[2])< 900) ]

                # x = [a[0] for a in grab.hits ]
                # y = [a[1] for a in grab.hits ]
                # z = [a[2] for a in grab.hits ]
                # max = 900
                x = []
                y = []
                z = []
                for p in grab.hits.values():
                    p = p[0]
                    '''
                    if (abs(p[0]) < max):
                        if (abs(p[1]) < max):
                            if (abs(p[2]) < max):
                                x.append(p[0])
                                y.append(p[1])
                                z.append(p[2])
                    '''
                    # '''
                    x.append(p[0])
                    y.append(p[1])
                    z.append(p[2])
                    # '''

                threedee = plt.figure().gca(projection='3d')
                # threedee = plt.figure().gca()
                # threedee.set_aspect('equal',adjustable='box')

                threedee.set_xlabel('x')
                threedee.set_ylabel('y')
                threedee.set_zlabel('z')
                threedee.scatter(x, y, z, marker='.')
                # threedee.axis('equal')
                plt.show()
                # ax.scatter(x, y, z, c='g', marker='o')
                # plt.show()

