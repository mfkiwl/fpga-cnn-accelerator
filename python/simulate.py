from cnn.utils import load_mnist, load_cifar10
from cnn.layers import *
from cnn.nnet import CNN
from modelsim import * 
from ps import *
from bramtool import convflowgen
from bramtool import fcflowgen
from bramtool import outreader

# --------------------------------------
# VHDL files needed to run the simulator
# --------------------------------------
files = ( 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/testbenches/accelerator_tb.vhd",
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/accelerator.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/accumulator.vhd",  
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/controller.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/conv_control.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/conv_engine.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/convolver.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/conv_router.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/core_unit.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/counter.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/data_grabber.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/fclayer_router.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/fclayer.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/fifo.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/mac_array.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/mac.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/max_pool_array.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/max_pool.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/p2s.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/pooler_addr_gen.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/pooler_registers.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/pooling_unit.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/processing_element.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/ram.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/reg_array.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/reg.vhd", 
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/shifter.vhd",
    "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/ReLU.vhd"
)


# --------------------------------------
# Configuration Variables and Constants
# --------------------------------------
# Paths
DATA_BRAM_PATH = '../vhdl/src/simulation/input/bram.txt'
KERNEL_BRAM_PATH = "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/input/kernels.txt"
OUTPUT_PREFIX_PATH = '../vhdl/src/simulation/output/'
IN_BUFFER = ["./bramtool/car.jpg"]
# IN_BUFFER = ["input1.txt"]
# IN_BUFFER = ["input0.txt", "input1.txt"]
# OPMODE
OPMODE = "\"101\""
# Innput and Kernel Dimensions 
X_DIM = 32
Y_DIM = 24
KERNEL_DIM = 3 
# BRAM settings
DATA_WIDTH = 32
DATA_RAM_DEPTH = 256000
WEIGHT_WIDTH = 8
WEIGHT_RAM_DEPTH = 32000
# Parallelisation
X_PARALLELISM = 4
Y_PARALLELISM = 4
F_PARALLELISM = 3
NUM_OUTPUT_BUFFERS = 3
# Number of in/out iterations
NUM_FILTERS = 15
IN_FMAPS = 4
TILE_ITERATIONS = NUM_FILTERS // F_PARALLELISM
# TILE_ITERATIONS = NUM_FILTERS

#FCLAYER
FC_DATA_FLATDIM = 7*7*8
FC_DATA_TILE_NUMLINES = math.ceil(FC_DATA_FLATDIM / (X_PARALLELISM * Y_PARALLELISM))
FC_KERNELS_TILE_NUMLINES = math.ceil(FC_DATA_FLATDIM / (KERNEL_DIM*KERNEL_DIM))

inputs = np.random.randint(0, 255, size=(1, IN_FMAPS, Y_DIM, X_DIM))
# inputs = np.random.randint(0, 255, size=(1, FC_DATA_FLATDIM))

# --------------------------------------
# Create and configure class representing the PS in hardware
# --------------------------------------
conv_fgen = convflowgen.Convflowgen(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, DATA_WIDTH, WEIGHT_WIDTH, DATA_BRAM_PATH, KERNEL_BRAM_PATH)
fc_fgen = fcflowgen.Fcflowgen(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, DATA_WIDTH, WEIGHT_WIDTH, DATA_BRAM_PATH, KERNEL_BRAM_PATH)
out_reader = outreader.OutputReader(X_PARALLELISM, Y_PARALLELISM, F_PARALLELISM, NUM_OUTPUT_BUFFERS, DATA_WIDTH, OUTPUT_PREFIX_PATH) 


ps = ProcessingSystem("/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/testbenches/accelerator_tb.vhd")
ps.initialize(  xpar=X_PARALLELISM, ypar=Y_PARALLELISM, fpar=F_PARALLELISM, outbufs=NUM_OUTPUT_BUFFERS, 
                data_wdt=DATA_WIDTH, dramdepth=DATA_RAM_DEPTH, kernelsize=int(math.pow(KERNEL_DIM,2)), 
                weight_wdt=WEIGHT_WIDTH, kramdepth=WEIGHT_RAM_DEPTH)

# Setup Runtime Registers on the PL by the PS
# OpMode                 
ps.set_opMode(OPMODE)
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

# --------------------------------------
# Prepare Input BRAM and Kernel Data
# --------------------------------------
cnn_layers = []

if OPMODE == "\"000\"" or OPMODE == "\"100\"": # Conv
    conv = Conv((IN_FMAPS, Y_DIM, X_DIM), n_filter=NUM_FILTERS, h_filter=KERNEL_DIM, w_filter=KERNEL_DIM, stride=1, padding=1)
    cnn_layers.append(conv)
    if OPMODE == "\"100\"":
        cnn_layers.append(ReLU())
    conv_fgen.write_conv_kernels(conv.W)
    conv_fgen.convert(inputs[0], kernel_size=3, stride=1, padding_size=1, itype='array', otype='hex')
elif OPMODE == "\"001\"" or  OPMODE == "\"101\"": # Conv + Pool
    conv = Conv((IN_FMAPS, Y_DIM, X_DIM), n_filter=NUM_FILTERS, h_filter=KERNEL_DIM, w_filter=KERNEL_DIM, stride=1, padding=1)
    pool = Maxpool(conv.out_dim, size=2, stride=2)
    cnn_layers.append(conv)
    if OPMODE == "\"101\"":
        cnn_layers.append(ReLU())    
    cnn_layers.append(pool)
    conv_fgen.write_conv_kernels(conv.W)
    conv_fgen.convert(inputs[0], kernel_size=3, stride=1, padding_size=1, itype='array', otype='hex')
else: #FC layer
    flat = Flatten()
    fc = FullyConnected(FC_DATA_FLATDIM, NUM_FILTERS)
    cnn_layers.append(flat)
    cnn_layers.append(fc)
    if OPMODE == "\"110\"":
        cnn_layers.append(ReLU())  
    fc_fgen.convert(inputs, FC_DATA_FLATDIM, FC_DATA_TILE_NUMLINES)
    fc_fgen.write_fc_kernels(kernels=fc.W, num_kernels=NUM_FILTERS, kernel_lines=FC_KERNELS_TILE_NUMLINES, kernel_dim=KERNEL_DIM)

cnn = CNN(cnn_layers)
result_numpy = cnn.forward(inputs)

print("Start")
with simulate("accelerator_tb", *files) as simulator:
    flag = 0
    while not flag:
        print("IterX: ")
        print(simulator.examine('accelerator_tb/accel/core/conv/ctrl/iX'))
        simulator.run(100000)
        flag = simulator.examine('/accelerator_tb/test_completed_s')

result_sim = None 
if OPMODE == "\"000\"" or OPMODE == "\"100\"":
    # result_sim = ps.converter.outputbrams2fmaps(rows=Y_DIM,cols=X_DIM, tile_iterations=TILE_ITERATIONS, pooling=False, save_img=False)
    result_sim = out_reader.read(rows=Y_DIM,cols=X_DIM, tile_iterations=TILE_ITERATIONS, pooling=False, save_img=False)
    result_sim = np.reshape(result_sim, (1, NUM_FILTERS, Y_DIM, X_DIM))
elif OPMODE == "\"001\"" or  OPMODE == "\"101\"": 
    result_sim = out_reader.read(rows=Y_DIM,cols=X_DIM, tile_iterations=TILE_ITERATIONS, pooling=True, save_img=False)
    result_sim = np.reshape(result_sim, (1, NUM_FILTERS, Y_DIM//2, X_DIM//2))
else:
    x = out_reader.read(rows=1, cols=1, tile_iterations=TILE_ITERATIONS, pooling=False, save_img=False)
    result_sim = np.squeeze(x)
    result_sim = np.reshape(result_sim, NUM_FILTERS)

# temp = np.square(pool[0]) > 1500
# img = Image.fromarray((( np.square(fmaps[1][12])  > 1500 )* 255).astype('uint8'), mode='L')
# img.save('my{}.png'.format(str(12)))
print(result_numpy)
print("--------------------")
print(result_sim)
np.set_printoptions(suppress=True)

equal_arrays = np.equal(result_numpy, result_sim).all()
print("Equall: ")
print(equal_arrays)