from time import sleep, time
from grabber import Grabber

SCALE = 0.003

if __name__ == '__main__':

        servers = []
        servers.append(('192.168.1.110', 40000))
        #servers.append(('192.168.1.110', 40001))
        #servers.append(('192.168.1.110', 40002))
        grab = Grabber(addr_list=servers, precision=10)

        grab.init()
        #sleep(1)

        try: # do while CTRL + C  not pressed
            i = 0
            gtime = time()
            startTime = time()
            cnt = 0
            timeStep = 1
            import os
            #while i <= 1000:
            while startTime > time()-120*100000000: # limit execution time to 60 seconds
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
                        print('i= ', i, ' , hits=  ', len(grab.hits))
                        gtime = time()
                        timeStep = 1
                        cnt = 0
                        '''
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
                        '''

                    else:
                        timeStep += 1
                        print('nothing i ',i)

            print('hits count', len(grab.hits))
            print("Storage size", len(grab.ray_map_marks.data))
            print("read count", grab.ray_map_marks.readCount)
            print("write count", grab.ray_map_marks.writeCount)

        except KeyboardInterrupt:
            pass

        print('!')


        # trying to interact with blender
        verts = []
        for p in grab.hits.values():
            p = p[0]
            p = (p[0] * SCALE, p[1] * SCALE, p[2] * SCALE)
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

