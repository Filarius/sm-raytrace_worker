class Marks:
    def __init__(self):
        self.data = set()
        #self._nested = dict()
        self.readCount = 0
        self.writeCount = 0
        pass

    def set(self,rd_index,value):
        self.writeCount += 1
        self.data.add(rd_index)
        #self._nested[rd_index] = value

    def get(self,rd_index,default = None):
        self.readCount += 1
        #return self._nested.get(rd_index, default)
        #return False if rd_index in self._nested else default
        return False if set([rd_index]).intersection(self.data) else default
        #return False if set([rd_index]).isdisjoint(self._nested) else default

    '''
    populate Storage with values between points
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
                #print('k ')
                k = i
        if k == -1: #TODO add detecting hit in solid body
            #print(vector)
            #raise AttributeError
            k=1 #x+ vector

        l = (k * 2)

        if vector[k] > 0:
            l += 1
        return l


    def set_ray(self,start,end,value,long=0,vector = None):
        if not vector:
            vector = (end[0]-start[0], end[1]-start[1], end[2]-start[2])

        dir = self._vector_to_dir(vector)
        di = (dir % 2)*2 -1
        k = dir // 2
        inx = list(start)
        inx.append(dir)
        end_point = end[k]
        #di = 1 if (start<end) else -1
        if long > 0:
            if (long < abs(vector[k])):
                end_point = start[k] + long*di
        buff = set()
        for i in range(start[k], end_point, di):
            inx[k] = i
            buff.add(tuple(inx))
            #self.set(tuple(inx), value)
        self.data.update(buff)
