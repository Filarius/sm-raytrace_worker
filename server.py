from multiprocessing import Process, Queue
import socket
import struct
import math
class Server:
    def __init__(self, address):
        self.queueIn = Queue(100)
        self.queueOut = Queue(100)
        self._runFlag = True
        self._sock = socket.socket()
        self._sock.connect(address)
        self._packetSize = 4096
        self._bufferLimit = 512

        self._procWrite = Process(target=self._socket_write_loop,
                                       args=(self.queueIn,))

        self._procRead = Process(target=self._socket_read_loop,
                                       args=(self.queueOut,))
        self._procRead.start()
        self._procWrite.start()


    def _socket_read_loop(self, queue):
        data = b""
        readpack = b""
        buff = b""
        buff_size = 0
        readInx = 0
        position = 0
        data_size = 0
        packetSize = self._packetSize
        sock = self._sock
        file = open("client_read.txt","wb")
        file2 = open("client_read2.txt","wb")
        while self._runFlag:
            newdata = sock.recv(packetSize)
            if not newdata:
                continue


            # write socket dump
            for i in range(len(newdata)):
                if readInx < 12:
                    file.write(newdata[i:i + 1])
                readInx = readInx + 1
                if readInx == 24:
                    readInx = 0

            hits = []
            i = 0
            while (i < len(newdata)):
                buff = buff + newdata[i:i+1]
                i += 1
                if (len(buff)==24):
                    unpacked = struct.unpack(">6f", buff)
                    buff = b""

                    isWrong = False
                    for val in unpacked:
                        if math.isnan(val) or math.isinf(val):
                            isWrong = True
                            break;
                    if not isWrong:
                        hits.append(unpacked)

            '''
            size = len(data)
            size = size - (size % 24)
            hits = []
            for i in range(0, size, 24):
                packed = data[i:i + 24]
                #writestring = packed
                file2.write(packed[0:12])
                file2.flush()
                #file.write(packed)#+b"000000\r\n")
                unpacked = struct.unpack(">6f", packed)

                haveNAN = False
                for val in unpacked:
                    if math.isnan(val) or math.isinf(val):
                        haveNAN = True
                        break;
                        print("error socket read value {:.2f} {:.2f} {:.2f} {:.2f} {:.2f} {:.2f}".format(*unpacked))
                        #print(''.join('{:02X}'.format(a) for a in packed))
                        print( 1)
                        print([packed[i:i+1] for i in range(len(packed))])

                # print()
                if not haveNAN:
                    hits.append(unpacked)
            #file.flush()
            

            size = len(data)
            if (size % 24) != 0:
                data = data[: -(size % 24) ] # last not encoded data
            else:
                data = b""
            '''

            queue.put(hits)
        file.close()


    def _socket_write_loop(self, queue):
        packed = b""
        writepack = b""
        indxIn = 0
        lst = []
        sock = self._sock
        file = open("client_write.txt", "wb")
        debug = []

        while self._runFlag:
            if not lst: #list is empty
                while True: #take all, but wait at last one
                    lst = []
                    lst.extend(queue.get())
                    if queue.empty():
                        break
            while indxIn < len(lst):
                ray = lst[indxIn]
                indxIn += 1
                lray = [ray['x'], ray['y'], ray['z'], ray['a'], ray['b'], ray['c']]
                for val in lray:
                    if math.isnan(val):
                        #print('error socket write value',lray)
                        print("error socket write value {:.2f} {:.2f} {:.2f} {:.2f} {:.2f} {:.2f}".format(*lray))
                writepack = writepack + struct.pack(">3f", *(ray['x'], ray['y'], ray['z']))

                #file.write(subpacked)#  + b"000000\r\n")
                packed = packed + struct.pack(">6f", *lray)

                #if len(packed) >= self._bufferLimit:
                #    break

            #file.write(packed)
            file.write(writepack)
            file.flush()
            writepack = b""

            sock.sendall(packed)
            packed = b""

            if indxIn == len(lst):
                lst = []
                indxIn = 0


    def add_trace(self, jobs):
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

    def get_points(self):
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

    def delete_points(self, maxId):
        pass
        #statement = 'DELETE FROM `job_done` WHERE `id`<=' + str(maxId) + ';'
        #self._db.query(statement)