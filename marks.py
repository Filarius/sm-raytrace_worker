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
    def set_ray(self,start,end,value):
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
