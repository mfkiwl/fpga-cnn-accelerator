import numpy as np
from PIL import Image
from itertools import islice
from textwrap import wrap

class OutputReader:

    def __init__(self, pox, poy, pof, num_buffers, data_width, base_path):
        self.pox = pox
        self.poy = poy
        self.pof = pof
        self.base_path = base_path
        self.num_buffers = num_buffers
        self.data_width = data_width

        self.fmaps_per_buffer = pof // num_buffers
   
    @staticmethod
    def twos_complement( number, bits=8):
        value = None
        
        if type(number) == str:
            value = int(number,16)
        else:
            value = number

        if value & (1 << (bits-1)):
            value -= 1 << bits
        return value        
    
    def read(self, rows, cols, tile_iterations, pooling=False, save_img=False):
        result = []
        for i in range(self.num_buffers):
            file_path = self.base_path + "output" + str(i+1) + ".txt"
            x = self.read_outbuffer(file_path,tile_iterations)
            result.append(x)
        x = self.outputbrams2fmaps(result, rows, cols, tile_iterations, pooling, save_img)
        return x


    def read_outbuffer(self, file_path, tile_iterations):
        """ Reads a dataflow dump in text-based format. 
            Store the data into the internal BRAM representation
        """
        lines_per_iteration = 0
        with open(file_path, 'r') as f:
            number_of_lines =  sum(1 for _ in f)
            lines_per_iteration = number_of_lines // tile_iterations
        
        iterations = []
        with open(file_path, 'r') as f:
            for i in range(tile_iterations):
                iter_buffer = [[] for fmap in range(self.fmaps_per_buffer)]
                lines_read = 0
                block_index = 0
                while lines_read < lines_per_iteration:
                    next_n_lines = list(islice(f, self.poy))
                    xline = [wrap(item.rstrip('\n').rstrip(' '), self.data_width//4) for item in next_n_lines]
                    iter_buffer[block_index % self.fmaps_per_buffer].extend(xline)
                    block_index += 1
                    lines_read += self.poy
                iterations.append(iter_buffer)
        return iterations

    def outputbrams2fmaps(self, data, rows, cols, tile_iterations, pooling=False, save_img=False):
        iterations = [ [] for _ in range(tile_iterations) ]
        ctr = 0
        for idx, outputfile in enumerate(data):
            for jdx, iteration in enumerate(outputfile):
                for fmap_buffer in iteration:
                    pix = self.outputbram2fmap(fmap_buffer, rows, cols, pooling)
                    if(save_img):
                        temp = np.square(pix) > 1500
                        img = Image.fromarray((temp * 255).astype('uint8'), mode='L')
                        img.save('my{}.png'.format(str(ctr)))
                        ctr += 1
                        # img.show()
                    iterations[jdx].append(pix)
        return iterations

    def outputbram2fmap(self, bram, rows, cols, pooling=False):
        """ Store internal buffer into 2d image representation.
                @cols - number of image cols
                @rows - number of image rows
        """
        # Container to store the relevant pixel data. 
        r = rows
        c = cols

        if pooling:
            r = rows // 2
            c= cols // 2

        pix = np.zeros((r, c))
    
        #Convert the dataflow representation into 2d image map
        for index, buffer_line in enumerate(bram):
            for idx, _ in enumerate(buffer_line):
                try:
                    pix[index % r, index // r * self.pox + idx]  = OutputReader.twos_complement(buffer_line[idx],self.data_width) 
                except:
                    break
        return pix