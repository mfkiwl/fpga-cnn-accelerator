import numpy as np
from ps import *
from bramtool import convflowgen
from bramtool import fcflowgen
from bramtool import outreader
from cnn.utils import load_mnist, load_cifar10
from cnn.layers import *
from cnn.nnet import CNN

# --------------------------------------
# Configuration Variables and Constants
# --------------------------------------
# Paths
DATA_BRAM_PATH = '../vhdl/src/simulation/input/bram.txt'
KERNEL_BRAM_PATH = "../vhdl/src/simulation/input/kernels.txt"
OUTPUT_PREFIX_PATH = '../vhdl/src/simulation/output/'

# OPMODE
# Mode of operation:
#   - **00 - convolution
#   - **01 - convolution + pooling
#   - **10 - fclayer
#   - *1** - ReLU active
#   - 1*** - BatchNormalization active
OPMODE = "\"0010\""

# Convolution Type
#   - x"0001" - 1x1, Padding 0,
#   - x"0002" - 3x3, Padding 1,
CONV_TYPE = "x\"0002\""

# Input and Kernel Dimensions 
X_DIM = 64
Y_DIM = 64
STRIDE = 1
PADDING = 1
KERNEL_DIM = 3

# BRAM settings
DATA_WIDTH = 32
DATA_RAM_DEPTH = 1024
WEIGHT_WIDTH = 8
WEIGHT_RAM_DEPTH = 1024

# Parallelisation
X_PARALLELISM = 32
Y_PARALLELISM = 16
F_PARALLELISM = 32
NUM_OUTPUT_BUFFERS = 32

# Number of in/out iterations
NUM_FILTERS = 32
IN_FMAPS = 1
TILE_ITERATIONS = NUM_FILTERS // F_PARALLELISM

# Dataflow parameters for current configuration
NUM_CONVBLOCK_BUFLINES = 4
NUM_IN_FMAP_BUFLINES   = 64

# Fully-Connected Layer configurations
FC_DATA_FLATDIM = 1024
FC_DATA_TILE_NUMLINES = math.ceil(FC_DATA_FLATDIM / (X_PARALLELISM * Y_PARALLELISM))
FC_KERNELS_TILE_NUMLINES = FC_DATA_FLATDIM

# Batchnorm Parametrs
BATCHNORM_ALPHA = 2
BATCHNORM_BETA  = -4

# --------------------------------------
# Generate random input data 
# --------------------------------------
inputs = np.random.randint(0, 255, size=(1, IN_FMAPS, Y_DIM, X_DIM)) # Data for conv based operations
inputs = np.random.randint(0, 255, size=(1, FC_DATA_FLATDIM)) # Data for FC layer

# --------------------------------------
# Create and configure class representing the PS in hardware
# --------------------------------------
conv_fgen  = convflowgen.Convflowgen(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, DATA_WIDTH, WEIGHT_WIDTH, DATA_BRAM_PATH, KERNEL_BRAM_PATH)
fc_fgen    = fcflowgen.Fcflowgen(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, DATA_WIDTH, WEIGHT_WIDTH, DATA_BRAM_PATH, KERNEL_BRAM_PATH)
out_reader = outreader.OutputReader(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, NUM_OUTPUT_BUFFERS, DATA_WIDTH, OUTPUT_PREFIX_PATH) 


ps = ProcessingSystem("../vhdl/src/simulation/testbenches/accelerator_tb.vhd")
ps.initialize(  xpar=X_PARALLELISM, ypar=Y_PARALLELISM, fpar=F_PARALLELISM, outbufs=NUM_OUTPUT_BUFFERS, 
                data_wdt=DATA_WIDTH, dramdepth=DATA_RAM_DEPTH, kernelsize=int(math.pow(KERNEL_DIM,2)), 
                weight_wdt=WEIGHT_WIDTH, kramdepth=WEIGHT_RAM_DEPTH)

# Setup Runtime Registers on the PL by the PS
# OpMode                 
ps.set_opMode(OPMODE)
ps.set_ConvType(CONV_TYPE)

# Input dimensions and padding
ps.set_Xdim(X_DIM)
ps.set_Ydim(Y_DIM)
ps.set_PaddingWidth(2)
# Set number of input fmaps and iterations
ps.set_NumInFmaps(IN_FMAPS)
ps.set_TileIterations(TILE_ITERATIONS)
# FC layer conf
ps.set_fclFlatdim(FC_DATA_FLATDIM)
ps.set_fclDataBufNumLines(FC_DATA_TILE_NUMLINES)
ps.set_fclKernelBufNumLines(FC_KERNELS_TILE_NUMLINES)
# Dataflow parameters
ps.set_NumConvblockBuflines(NUM_CONVBLOCK_BUFLINES)
ps.set_InFmapBuflines(NUM_IN_FMAP_BUFLINES)

# Dataflow parameters
ps.set_batchNormAlpha(BATCHNORM_ALPHA)
ps.set_batchNormBeta(BATCHNORM_BETA)

print("--- Configuration completed! ")

# --------------------------------------
# Prepare Input BRAM and Kernel Data
# --------------------------------------
cnn_layers = []
if OPMODE[3] == '1': 
    #FC layer
    flat = Flatten()
    fc = FullyConnected(FC_DATA_FLATDIM, NUM_FILTERS)
    cnn_layers.append(flat)
    cnn_layers.append(fc)
    if OPMODE[2] == '1':
        cnn_layers.append(ReLU())    
    fc_fgen.convert(inputs, FC_DATA_FLATDIM, FC_DATA_TILE_NUMLINES)
    fc_fgen.write_fc_kernels(kernels=fc.W, num_kernels=NUM_FILTERS, kernel_flatdim=FC_KERNELS_TILE_NUMLINES)
elif OPMODE[4] == '0': 
    #Convolution
    conv = Conv((IN_FMAPS, Y_DIM, X_DIM), n_filter=NUM_FILTERS, h_filter=KERNEL_DIM, w_filter=KERNEL_DIM, stride=STRIDE, padding=PADDING)
    cnn_layers.append(conv)
    if OPMODE[2] == '1':
        cnn_layers.append(ReLU())  
    if OPMODE[1] == '1':
        cnn_layers.append(Batchnorm((NUM_FILTERS, IN_FMAPS, Y_DIM, X_DIM), BATCHNORM_ALPHA, BATCHNORM_BETA))                 
    conv_fgen.write_conv_kernels(conv.W)
    conv_fgen.convert(inputs[0], kernel_size=KERNEL_DIM, stride=STRIDE, padding_size=PADDING, itype='array', otype='hex')
elif OPMODE[4] == '1':
    #Convolution + pooling
    conv = Conv((IN_FMAPS, Y_DIM, X_DIM), n_filter=NUM_FILTERS, h_filter=KERNEL_DIM, w_filter=KERNEL_DIM, stride=STRIDE, padding=PADDING)
    pool = Maxpool(conv.out_dim, size=2, stride=2)
    cnn_layers.append(conv)
    if OPMODE[2] == '1':
        cnn_layers.append(ReLU())    
    if OPMODE[1] == '1':
        cnn_layers.append(Batchnorm((NUM_FILTERS, IN_FMAPS, Y_DIM, X_DIM), BATCHNORM_ALPHA, BATCHNORM_BETA))        
    cnn_layers.append(pool)
    conv_fgen.write_conv_kernels(conv.W)
    conv_fgen.convert(inputs[0], kernel_size=KERNEL_DIM, stride=STRIDE, padding_size=PADDING, itype='array', otype='hex')


cnn = CNN(cnn_layers)
result_numpy = cnn.forward(inputs)

#--------------------------------------------------------------------------------
# Wait for simulator - wait end by user input
#--------------------------------------------------------------------------------
input("--- Press a button if simulation terminated.")

result_sim = None 
if OPMODE[3] == '1':
    # Fully Connected Layer
    x = out_reader.read(rows=1, cols=1, tile_iterations=TILE_ITERATIONS, pooling=False, save_img=False)
    result_sim = np.squeeze(x)
    result_sim = np.reshape(result_sim, NUM_FILTERS)
elif OPMODE[4] == '0': 
    # Convolution
    result_sim = out_reader.read(rows=Y_DIM,cols=X_DIM, tile_iterations=TILE_ITERATIONS, pooling=False, save_img=False)
    result_sim = np.reshape(result_sim, (1, NUM_FILTERS, Y_DIM, X_DIM))
elif OPMODE[4] == '1': 
    # Convolution + Pooling
    result_sim = out_reader.read(rows=Y_DIM,cols=X_DIM, tile_iterations=TILE_ITERATIONS, pooling=True, save_img=False)
    result_sim = np.reshape(result_sim, (1, NUM_FILTERS, Y_DIM//2, X_DIM//2))


print(result_numpy)
print("--------------------")
print(result_sim)
np.set_printoptions(suppress=True)

equal_arrays = np.equal(result_numpy, result_sim).all()
print("Equall: ")
print(equal_arrays)