import re
import math

class ProcessingSystem:
    
    def __init__(self, tb_path):
        self.accel_testbench_path = tb_path

    def initialize(self, xpar=3, ypar=3, fpar=3, outbufs=3, data_wdt=16, dramdepth=256, kernelsize=9, weight_wdt=16, kramdepth=128):
        self.set_Xparallelsim(xpar)
        self.set_Yparallelsim(ypar)
        self.set_Fparallelsim(fpar)
        self.set_NumOutBuffers(outbufs)
        self.set_DataWidth(data_wdt)
        self.set_DataRamDepth(dramdepth)      
        self.set_KernelSize(kernelsize)
        self.set_WeightWidth(weight_wdt)
        self.set_KernelRamDepth(kramdepth)     

    def set_generic(self, generic, value):
        buffer = []
        with open(self.accel_testbench_path, 'r') as tb:
            for line in tb:
                temp = line
                if 'constant ' + generic in line:
                    temp = line.strip().split(':=')
                    temp[-1] = value
                    temp = '    ' + temp[0] + ":= " + str(value) + "; \n"
                buffer.append(temp)
        
        with open(self.accel_testbench_path,'w') as new_file:
            for line in buffer:
                new_file.write(line)

    # Set generics needed at synth time
    # Parallelism
    def set_Xparallelsim(self, value):
        self.set_generic("Xparallelism", value)

    def set_Yparallelsim(self, value):
        self.set_generic("Yparallelism", value)

    def set_Fparallelsim(self, value):
        self.set_generic("Fparallelism", value)

    # Data buffers and width
    def set_NumOutBuffers(self, value):
        self.set_generic('OutputBuffers', value)

    def set_DataWidth(self, value):
        self.set_generic('DataWidth', value)

    def set_DataRamDepth(self, value):
        self.set_generic('DataRamDepth', value)           

    # Kernel buffers and width
    def set_KernelSize(self, value):
        self.set_generic('KernelSize', value)

    def set_WeightWidth(self, value):
        self.set_generic('WeightWidth', value)

    def set_KernelRamDepth(self, value):
        self.set_generic('KernelRamDepth', value)    

    # Set registers needed at runtime
    # OpMode                 
    def set_opMode(self, value):
        self.set_generic('opMode', value)  

    # ConvType
    def set_ConvType(self, value):
        self.set_generic('ConvType', value)                                

	# Input Dimensions and Metainfo implied by dimensionality
    def set_Xdim(self, value):
        self.set_generic('X_Dim', value)

    def set_Ydim(self, value):
        self.set_generic('Y_Dim', value)

    def set_PaddingWidth(self, value):
        self.set_generic('PaddingWidth', value)

    def set_NumInFmaps(self, value):
        self.set_generic('NumInputFmaps', value)
	
    # -- Number Tiles to process at one runthrough
    def set_TileIterations(self, value):
        self.set_generic('TileIterations', value)

	# -- Information needed for FC layer
    def set_fclFlatdim(self, value):
        self.set_generic('fcl_flatdim', value)

    def set_fclDataBufNumLines(self, value):
        self.set_generic('fcl_data_bufnumlines', value)

    def set_fclKernelBufNumLines(self, value):
        self.set_generic('fcl_kernel_bufnumlines', value)         

    # Dataflow parameters
    def set_NumConvblockBuflines(self, value):
        self.set_generic('NumConvblockBuflines', value)         

    def set_InFmapBuflines(self, value):
        self.set_generic('InFmapBuflines', value)  

    # Batchnorm parameters
    def set_batchNormAlpha(self, value):
        self.set_generic('batchNorm_Alpha', value)   

    def set_batchNormBeta(self, value):
        self.set_generic('batchNorm_Beta', value)          