import numpy as np
import math
from PIL import Image

class Fcflowgen:
    def __init__(self, pox, poy, pof, data_width, weight_width, path_data, path_kernels):
        self.pox = pox
        self.poy = poy
        self.pof = pof
        self.data_width = data_width
        self.weight_width = weight_width
        self.path_dbram = path_data
        self.path_kbram = path_kernels

    def convert(self, i_data, flatdim, tilelines):
        data = np.resize(i_data, (tilelines, self.pox*self.poy))
        to_hex = lambda x : hex(x & 0xff)[2:]
        with open(self.path_dbram,'ab') as f:
            f.truncate(0)
            temp = np.array([[to_hex(e).zfill(self.data_width // 4) for e in d] for d in data])
            np.savetxt(f, temp, fmt="%s", delimiter='')        

    def write_fc_kernels(self, kernels, num_kernels, kernel_flatdim):

        
        # kernels = np.transpose(kernels)
        # print(kernels)

        kernels = np.array(np.hsplit(kernels, num_kernels/self.pof))

        kernels = kernels.reshape((num_kernels//self.pof *  kernel_flatdim, self.pof))
       
        print(kernels)
        
        to_hex = lambda x : hex(x & 0xff)[2:]
        with open(self.path_kbram,'ab') as f:
            f.truncate(0)
            temp = np.array([[to_hex(e).zfill(self.weight_width // 4) for e in r] for r in kernels])
            np.savetxt(f, temp, fmt="%s", delimiter='')
                
                   