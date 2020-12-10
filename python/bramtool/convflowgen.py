import numpy as np
import math
from PIL import Image

class Convflowgen:
    def __init__(self, pox, poy, pof, data_width, weight_width, data_path, kernel_path):
        self.pox = pox
        self.poy = poy
        self.pof = pof
        self.data_width = data_width
        self.weight_width = weight_width
        self.path_dbram = data_path
        self.path_kbram = kernel_path

    def convert(self, inputs, kernel_size, stride, padding_size, itype='array', otype='dec'):
        dflow = []
        if itype == 'text':
            for txt_path in inputs: 
                pixels = np.loadtxt(txt_path)
                dflow.extend(self.generate_dataflow(pixels, kernel_size, stride, padding_size))
        elif itype == 'array':
            for pixels in inputs: 
                dflow.extend(self.generate_dataflow(pixels, kernel_size, stride, padding_size))
        elif itype == 'image':
            for img_path in inputs: 
                im = Image.open(img_path).convert("L")
                pixels = np.array(im)
                dflow.extend(self.generate_dataflow(pixels, kernel_size, stride, padding_size))
        else:
            raise TypeError
        self.write_dataflow(dflow, otype)    

    @staticmethod
    def add_margin(pix, top_padding, down_padding):
        result = np.zeros((pix.shape[0]+top_padding+down_padding, pix.shape[1]))
        if top_padding == 0 and down_padding == 0:
            result[:, :] = pix
        else:
            result[top_padding:-down_padding, :] = pix
        return result          

    def write_dataflow(self, data, mode='hex'):
        """ Dump data from internal BRAM representation into file.
        """
        to_hex = lambda x : hex(x & 0xff)[2:]
        with open(self.path_dbram,'w') as f:
            f.truncate(0)

            for d in data:
                temp  = np.concatenate(d, axis=1)
                if mode=='hex':
                    temp = np.array([[to_hex(int(e)).zfill(self.data_width // 4) for e in d] for d in temp])
                    np.savetxt(f, temp, fmt="%s", delimiter='')
                else:
                    temp = np.array([[int(e) for e in d] for d in temp])
                    np.savetxt(f, temp, fmt="%3s", delimiter=' ')
                    f.write("\n")

    def get_dfsubindexing(self, stride, strided_rows, ordinary_rows, length_limit):
        indizes = []
        
        for s in range(strided_rows):
            temp = []
            for ydx in range(self.poy):
                temp.append(s + ydx*stride)
            indizes.append(temp)

        for o in range(ordinary_rows):
            temp = []
            for ydx in range(self.poy):
                index = self.poy*(strided_rows+o) + ydx
                if index > length_limit:
                    temp.append(-1)
                else: 
                    temp.append(index)
            indizes.append(temp)

        return indizes
  
    def generate_dataflow(self, pix, kernel_size, stride, padding_size):
        """ Converts an image to a BRAM dataflow representation. 
            Store result inside an internal array-based buffer.
                @img_path - path to the .jpg file to convert
        """
        # Add padding to the input. Get input dimensions.
        rows    = pix.shape[0]
        columns = pix.shape[1]
        pix     = Convflowgen.add_margin(pix, padding_size, padding_size)

        # Rows and columns are processed in parallel.
        # Calculate number of data accesses. Divide total rows, cols by parallelism.
        num_loads_y = math.floor(rows / (self.poy*stride))
        num_loads_x = math.floor(columns / (self.pox*stride))
        x_pos = 0
        y_pos = 0

        # Calculate the number of rows and columns needed to be exctracted from fmap.
        # Based on stride and kernel_size
        
        if kernel_size - stride >= 0:
            ord_rows = kernel_size - stride
            strided_rows = stride
        else:
            ord_rows = 0
            strided_rows = kernel_size

        num_dfrows = self.poy*stride + ord_rows
        num_dfcols = self.pox + kernel_size - 1

        per_write_rows = math.ceil(num_dfcols / self.pox)
        per_write_cols = self.pox
        
        # Iterate over the fmap macro-boxes
        # Jumps in x and y directions result from parallelism Pox and Poy
        result = []
        for x_load in range(num_loads_x):
            for y_load in range(num_loads_y):

                # Calculate y_pos, x_pos of current macro-box
                y_pos = y_load * self.poy * stride
                if x_load > 0: 
                    x_pos = x_load * (self.pox ) * stride - padding_size*stride
                else:
                    x_pos = x_load * self.pox * stride

                # Extract current part of fmap and fill void positions with zeros
                buffer = np.zeros((num_dfrows, num_dfcols))
                frame = pix[y_pos:y_pos+num_dfrows, x_pos:x_pos+num_dfcols]
                for idx, row in enumerate(frame):
                    for jdx, elem in enumerate(row):
                        buffer[idx, jdx] = elem

                # Get indizes for buffer subindexing to obtain a valid represenetation of the dataflow
                indizes = self.get_dfsubindexing(stride, strided_rows, math.ceil(ord_rows/self.poy), len(buffer))
                indizes = np.reshape(indizes, (strided_rows + math.ceil(ord_rows/self.poy), self.poy))

                buffer = [np.resize(row, (per_write_rows, self.pox)) for row in buffer]
                buffer.append(np.zeros((per_write_rows, self.pox))) # Append zero buffer at the end do make subindexing easy
                buffer = np.array(buffer)
                
                dflow = buffer[indizes]

                result.extend(dflow)

        return result

    def write_conv_kernels(self, kernels):
        num_kernels, num_fmaps, kernel_height, kernel_width = kernels.shape

        kernels = kernels.reshape((num_kernels//self.pof, self.pof, kernel_height*kernel_width*num_fmaps))
        kernels = np.array([np.hstack(kernels)])
        kernels = np.transpose(kernels,(0,2,1))

        to_hex = lambda x : hex(x & 0xff)[2:] # Remove the leading 0x
        with open(self.path_kbram,'ab') as f:
            f.truncate(0)
            for k in kernels:
                temp = np.array([[to_hex(e).zfill(self.weight_width // 4) for e in r] for r in k])
                np.savetxt(f, temp, fmt="%s", delimiter='')