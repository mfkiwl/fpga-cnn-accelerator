from bramtool import BramConverter
from PIL import Image
import numpy as np
import math

KBRAM_PATH = '../../vhdl/src/simulation/input/kernels.txt'
SIM_BRAM_PATH = '../../vhdl/src/simulation/input/bram.txt'
OUTPUT_PREFIX_PATH = '../../vhdl/src/simulation/output/'

X_DIM = 8
Y_DIM = 8
X_PARALLELISM = 4
Y_PARALLELISM = 4
F_PARALLELISM = 3
KERNEL_DIM    = 3
NUM_OUTPUT_BUFFERS  = 3
# TILE_ITERATIONS = 1
DATA_WIDTH = 16
WEIGHT_WIDTH = 8

IN_BUFFER = ["./input1.txt"]

FC_DATA_FLATDIM = 7*7*4
FC_DATA_TILE_NUMLINES = math.ceil(FC_DATA_FLATDIM / (X_PARALLELISM * Y_PARALLELISM))
FC_KERNELS_FLATDIM = FC_DATA_FLATDIM
FC_KERNELS_TILE_NUMLINES = math.ceil(FC_KERNELS_FLATDIM / (KERNEL_DIM*KERNEL_DIM))
NUM_KERNELS = 3

indata = np.random.randint(0, 255, size=(FC_DATA_FLATDIM))
converter = BramConverter(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, KERNEL_DIM, WEIGHT_WIDTH, NUM_OUTPUT_BUFFERS, DATA_WIDTH)
# converter.convert_fclayer(FC_DATA_FLATDIM, FC_DATA_TILE_NUMLINES, indata, SIM_BRAM_PATH)
converter.convert_convolution(IN_BUFFER, SIM_BRAM_PATH, 'text', 'dec')

# kernels = np.random.randint(0, 255, size=(FC_KERNELS_FLATDIM, NUM_KERNELS))
# converter.write_fc_kernels(kernels, NUM_KERNELS, FC_KERNELS_TILE_NUMLINES, KBRAM_PATH)


# converter.read_outbuffers(OUTPUT_PREFIX_PATH, TILE_ITERATIONS)
# fmaps = converter.outputbrams2fmaps(rows=X_DIM,cols=Y_DIM, tile_iterations=TILE_ITERATIONS, save_img=False)
# print(fmaps)
# pool = converter.pooling(fmaps[1], 6, 6)
# print(fmaps[1][1])
# print(pool[1])
