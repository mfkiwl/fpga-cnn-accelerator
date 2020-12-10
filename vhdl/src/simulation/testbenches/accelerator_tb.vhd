library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity accelerator_tb is
end entity;

architecture simulate OF accelerator_tb is

	----------------------------------------------------
	--- Generics specified at synthesis time
	----------------------------------------------------
	-- Parallelism
    constant Xparallelism : integer := 32; 
    constant Yparallelism : integer := 16; 
    constant Fparallelism : integer := 32; 

    constant OutputBuffers  : integer := 32; 
    constant DataWidth      : integer := 32; 
    constant DataRamDepth   : integer := 1024; 
	-- Kernel Buffers
    constant KernelSize     : integer := 9; 
    constant WeightWidth    : integer := 8; 
    constant KernelRamDepth : integer := 1024; 
	-- P2S to Outputbuf MUXes
	constant MuxInputWidth  : integer := (Fparallelism / OutputBuffers) * Yparallelism * Xparallelism * DataWidth;
	constant MuxOutputWidth : integer := Xparallelism * DataWidth;

	constant DataBramAddrWidth   : integer := 32;
	constant KernelBramAddrWidth : integer := 32;
	constant OutputBramAddrWidth : integer := 32;

	----------------------------------------------------
	--- Registers to be set by Processing System
	----------------------------------------------------
	-- Mode of operation:
	-- **00 - convolution
	-- **01 - convolution + pooling
	-- **10 - fclayer
	-- *1** - ReLU active
	-- 1*** - BatchNormalization active

    constant opMode : std_logic_vector(3 downto 0) := "0010"; 

	-- ConvType:
	-- x"0001" - 1x1, Padding 0,
	-- x"0002" - 3x3, Padding 1, 
    constant ConvType : std_logic_vector(15 downto 0) := x"0002"; 

	-- Input Dimensions and Metainfo implied by dimensionality
    constant X_Dim                : integer := 64; 
    constant Y_Dim                : integer := 64; 
	constant X_NumBlocks          : integer := X_Dim / Xparallelism;
	constant Y_NumBlocks          : integer := Y_Dim / Yparallelism;
	-- Convblock properties
    constant NumConvblockBuflines : integer := 4; 

	-- Number of I/O Fmaps to calculate for
	constant NumOutputFmaps : integer := Fparallelism / OutputBuffers;
    constant NumInputFmaps  : integer := 2; 

    constant InFmapBuflines  : integer := 64; 
	constant OutFmapBuflines : integer := X_NumBlocks * Y_NumBlocks * Yparallelism * NumOutputFmaps;

	-- Number Tiles to process at one runthrough
    constant TileIterations : integer := 1; 

	-- Information needed for FC layer
    constant fcl_flatdim            : integer := 1024; 
    constant fcl_data_bufnumlines   : integer := 2; 
    constant fcl_kernel_bufnumlines : integer := 1024; 

	-- Batchnorm Parameters
    constant batchNorm_Alpha : integer := 2; 
    constant batchNorm_Beta  : integer := -4; 

	----------------------------------------------------
	--- Simulation constants
	----------------------------------------------------
	constant clock_period : time := 20 ns;

	----------------------------------------------------
	--- Component declarations.
	----------------------------------------------------

	component accelerator
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_NumBuffers          : in integer;
			g_DataW               : in integer;
			g_WeightW             : in integer;
			g_DataBramAddrWidth   : in integer;
			g_KernelBramAddrWidth : in integer;
			g_OutputBramAddrWidth : in integer
		);
		port(
			i_clk                        : in  std_logic;
			i_reset                      : in  std_logic;
			i_opMode                     : in  std_logic_vector(3 downto 0);
			i_start                      : in  std_logic;
			o_ready                      : out std_logic;
			i_kernelSize                 : in  std_logic_vector(15 downto 0);
			i_xDim                       : in  std_logic_vector(15 downto 0);
			i_yDim                       : in  std_logic_vector(15 downto 0);
			i_xIterations                : in  std_logic_vector(15 downto 0);
			i_yIterations                : in  std_logic_vector(15 downto 0);
			i_convType                   : in  std_logic_vector(15 downto 0);
			i_numConvblockBuflines       : in  std_logic_vector(15 downto 0);
			i_numInputFmaps              : in  std_logic_vector(15 downto 0);
			i_inFmapBuflines             : in  std_logic_vector(15 downto 0);
			i_outFmapBuflines            : in  std_logic_vector(15 downto 0);
			i_fclayer_flatdim            : in  std_logic_vector(15 downto 0);
			i_fclayer_data_bufnumlines   : in  std_logic_vector(15 downto 0);
			i_fclayer_kernel_bufnumlines : in  std_logic_vector(15 downto 0);
			i_tileIterations             : in  std_logic_vector(15 downto 0);
			i_numOutbufFmaps             : in  std_logic_vector(15 downto 0);
			i_bnormAlpha                 : in  std_logic_vector(15 downto 0);
			i_bnormBeta                  : in  std_logic_vector(15 downto 0);
			i_dbram_line                 : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_dbram_rd_address           : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_dbram_rd_en                : out std_logic;
			i_kbram_line                 : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_kbram_rd_address           : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_kbram_rd_en                : out std_logic;
			i_outbuf_line                : in  std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
			o_outbuf_rd_address          : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
			o_outbuf_rd_en               : out std_logic_vector(g_NumBuffers - 1 downto 0);
			o_outbuf_line                : out std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
			o_outbuf_wr_address          : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
			o_outbuf_wr_en               : out std_logic_vector(g_NumBuffers - 1 downto 0)
		);
	end component accelerator;

	component ram_infer
		generic(
			WordWidth    : integer;
			RamDepth     : integer;
			InitFileName : string;
			DumpFileName : string
		);
		port(
			clock         : in  std_logic;
			data          : in  std_logic_vector(WordWidth - 1 DOWNTO 0);
			write_address : in  integer;
			read_address  : in  integer;
			we            : in  std_logic;
			q             : out std_logic_vector(WordWidth - 1 DOWNTO 0);
			dump_size     : in  integer;
			dump_flag     : in  std_logic
		);
	end component ram_infer;
	
	component up_counter
		generic(g_DataWidth : in integer);
		port(
			clk    : in  std_logic;
			reset  : in  std_logic;
			enable : in  std_logic;
			cout   : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component up_counter;

	----------------------------------------------------
	--- Intermediate connection signals.
	----------------------------------------------------
	-- clk & reset
	signal clk_s   : std_logic;
	signal reset_s : std_logic;

	-- kernel/weight BRAM connections
	signal kbram_wr_en_s      : std_logic;
	signal kbram_wr_data_s    : std_logic_vector(Fparallelism * WeightWidth - 1 downto 0);
	signal kbram_rd_data_s    : std_logic_vector(Fparallelism * WeightWidth - 1 downto 0);
	signal kbram_wr_address_s : integer;
	signal kbram_rd_address_s : std_logic_vector(KernelBramAddrWidth - 1 downto 0);

	-- data/feature-map BRAM connections
	signal dbram_wr_en_s      : std_logic;
	signal dbram_wr_data_s    : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal dbram_rd_data_s    : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal dbram_rd_address_s : std_logic_vector(DataBramAddrWidth - 1 downto 0);
	signal dbram_wr_address_s : integer;

	-- dbram/kbram ready indications.
	signal dbram_ready : std_logic;
	signal kbram_ready : std_logic;

	-- ctrl signals
	signal accel_start_s    : std_logic;
	signal accel_ready_s    : std_logic;
	signal test_completed_s : std_logic;
	signal dump_results_s   : std_logic;

	--obuf
	signal outbuf_wrdata_s   : std_logic_vector(OutputBuffers * Xparallelism * DataWidth - 1 downto 0);
	signal outbuf_wraddr_s   : std_logic_vector(OutputBuffers * OutputBramAddrWidth - 1 downto 0);
	signal outbuf_wren_s     : std_logic_vector(OutputBuffers - 1 downto 0);
	signal outbuf_readaddr_s : std_logic_vector(OutputBuffers * OutputBramAddrWidth - 1 downto 0);
	signal outbuf_rddata_s   : std_logic_vector(OutputBuffers * Xparallelism * DataWidth - 1 downto 0);

	-- file handle
	file file_RESULTS : text;

	signal outbuf_accel_readaddr_s : std_logic_vector(OutputBuffers * OutputBramAddrWidth - 1 downto 0);
	signal outbuf_file_readaddr_s  : std_logic_vector(OutputBuffers * OutputBramAddrWidth - 1 downto 0);
	
	
	signal clk_bram_wr_data_s : std_logic_vector(31 downto 0);
	signal clk_bram_wr_en_s : std_logic;
	signal clk_bram_rd_data_s : std_logic_vector(31 downto 0);
	signal clk_dump_s : std_logic;

begin

	----------------------------------------------------
	--- Instantiations
	----------------------------------------------------
	outbuf_readaddr_s <= outbuf_accel_readaddr_s when accel_ready_s = '0' else outbuf_file_readaddr_s;

	accel : component accelerator
		generic map(
			g_Pox                 => Xparallelism,
			g_Poy                 => Yparallelism,
			g_Pof                 => Fparallelism,
			g_NumBuffers          => OutputBuffers,
			g_DataW               => DataWidth,
			g_WeightW             => WeightWidth,
			g_DataBramAddrWidth   => DataBramAddrWidth,
			g_KernelBramAddrWidth => KernelBramAddrWidth,
			g_OutputBramAddrWidth => OutputBramAddrWidth
		)
		port map(
			i_clk                        => clk_s,
			i_reset                      => reset_s,
			i_opMode                     => opMode,
			i_start                      => accel_start_s,
			o_ready                      => accel_ready_s,
			i_kernelSize                 => std_logic_vector(to_unsigned(KernelSize, 16)),
			i_xDim                       => std_logic_vector(to_unsigned(X_Dim, 16)), -- XDimension of featuremap
			i_yDim                       => std_logic_vector(to_unsigned(Y_Dim, 16)), -- YDimension of featuremap
			i_xIterations                => std_logic_vector(to_unsigned(X_NumBlocks, 16)), -- Number of processing blocks in XDir under Pox, Poy
			i_yIterations                => std_logic_vector(to_unsigned(Y_NumBlocks, 16)), -- Number of processing blocks in YDir under Pox, Poy
			i_convType                   => ConvType,
			i_numConvblockBuflines       => std_logic_vector(to_unsigned(NumConvblockBuflines, 16)),
			i_numInputFmaps              => std_logic_vector(to_unsigned(NumInputFmaps, 16)), -- Number of input feature maps
			i_inFmapBuflines             => std_logic_vector(to_unsigned(InFmapBuflines, 16)), -- Number of Bufferlines in Input-Dataflow under Pox, Poy
			i_outFmapBuflines            => std_logic_vector(to_unsigned(OutFmapBuflines, 16)),
			i_fclayer_flatdim            => std_logic_vector(to_unsigned(fcl_flatdim, 16)),
			i_fclayer_data_bufnumlines   => std_logic_vector(to_unsigned(fcl_data_bufnumlines, 16)),
			i_fclayer_kernel_bufnumlines => std_logic_vector(to_unsigned(fcl_kernel_bufnumlines, 16)),
			i_tileIterations             => std_logic_vector(to_unsigned(TileIterations, 16)), -- Tiles to process during a single run.
			i_numOutbufFmaps             => std_logic_vector(to_unsigned(NumOutputFmaps, 16)), -- Tiles to process during a single run.
			i_bnormAlpha                 => std_logic_vector(to_signed(batchNorm_Alpha, 16)),
			i_bnormBeta                  => std_logic_vector(to_signed(batchNorm_Beta, 16)),
			i_dbram_line                 => dbram_rd_data_s,
			o_dbram_rd_address           => dbram_rd_address_s,
			o_dbram_rd_en                => open,
			i_kbram_line                 => kbram_rd_data_s,
			o_kbram_rd_address           => kbram_rd_address_s,
			o_kbram_rd_en                => open,
			i_outbuf_line                => outbuf_rddata_s,
			o_outbuf_rd_address          => outbuf_accel_readaddr_s,
			o_outbuf_rd_en               => open,
			o_outbuf_line                => outbuf_wrdata_s,
			o_outbuf_wr_address          => outbuf_wraddr_s,
			o_outbuf_wr_en               => outbuf_wren_s
		);

	-- Data BRAM
	bramdata : ram_infer
		generic map(
			WordWidth    => Xparallelism * Yparallelism * DataWidth,
			RamDepth     => DataRamDepth,
			--			InitFileName => "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/input/bram.txt",
			InitFileName => "C:\Users\sander\neuralnet_accel\MPE_Accel\vhdl\src\simulation\input\bram.txt",
			DumpFileName => "None"
		)
		port map(
			clock         => clk_s,
			data          => dbram_wr_data_s,
			write_address => dbram_wr_address_s,
			read_address  => to_integer(unsigned(dbram_rd_address_s)),
			we            => dbram_wr_en_s,
			q             => dbram_rd_data_s,
			dump_size     => 0,
			dump_flag     => dump_results_s
		);

	-- Kernel BRAM
	bramkernel : ram_infer
		generic map(
			WordWidth    => Fparallelism * WeightWidth,
			RamDepth     => KernelRamDepth,
			--			InitFileName => "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/input/kernels.txt",
			InitFileName => "C:\Users\sander\neuralnet_accel\MPE_Accel\vhdl\src\simulation\input\kernels.txt",
			DumpFileName => "None"
		)
		port map(
			clock         => clk_s,
			data          => kbram_wr_data_s,
			write_address => kbram_wr_address_s,
			read_address  => to_integer(unsigned(kbram_rd_address_s)),
			we            => kbram_wr_en_s,
			q             => kbram_rd_data_s,
			dump_size     => 0,
			dump_flag     => dump_results_s
		);

	-- output buffers and muxes
	g1 : for jj in OutputBuffers downto 1 generate
	begin
		outbuf : ram_infer
			generic map(
				WordWidth    => MuxOutputWidth,
				RamDepth     => DataRamDepth,
				InitFileName => "None",
				DumpFileName => "C:\Users\sander\neuralnet_accel\MPE_Accel\vhdl\src\simulation\output\output" & INTEGER'IMAGE(OutputBuffers - jj + 1) & ".txt"
				--				DumpFileName => "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/output/output" & INTEGER'IMAGE(OutputBuffers - jj + 1) & ".txt"
			)
			port map(
				clock         => clk_s,
				data          => outbuf_wrdata_s(jj * Xparallelism * DataWidth - 1 downto (jj - 1) * Xparallelism * DataWidth),
				write_address => to_integer(unsigned(outbuf_wraddr_s(jj * OutputBramAddrWidth - 1 downto (jj - 1) * OutputBramAddrWidth))),
				read_address  => to_integer(unsigned(outbuf_readaddr_s(jj * OutputBramAddrWidth - 1 downto (jj - 1) * OutputBramAddrWidth))),
				we            => outbuf_wren_s(jj - 1),
				q             => outbuf_rddata_s(jj * Xparallelism * DataWidth - 1 downto (jj - 1) * Xparallelism * DataWidth),
				dump_size     => to_integer(unsigned(outbuf_wraddr_s(jj * OutputBramAddrWidth - 1 downto (jj - 1) * OutputBramAddrWidth))),
				dump_flag     => dump_results_s
			);
	end generate;
	
	
	
	-- clock counter
	bramclock : ram_infer
		generic map(
			WordWidth    => 32,
			RamDepth     => 4,
			--			InitFileName => "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/input/kernels.txt",
			InitFileName => "None",
			DumpFileName => "C:\Users\sander\neuralnet_accel\MPE_Accel\vhdl\src\simulation\output\clocks.txt"
		)
		port map(
			clock         => clk_s,
			data          => clk_bram_wr_data_s,
			write_address => 0,
			read_address  => 0,
			we            => not accel_ready_s,
			q             => clk_bram_rd_data_s,
			dump_size     => 1,
			dump_flag     => dump_results_s
		);		
		
	ctr: up_counter
		generic map(
			g_DataWidth => 32
		)
		port map(
			clk    => clk_s,
			reset  => reset_s,
			enable => not accel_ready_s,
			cout   => clk_bram_wr_data_s
		);
		
			

	----------------------------------------------------
	--- Processes
	----------------------------------------------------
	-- Produce clock signal 
	clock_process : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process;

	---------------------------------------------------------------------------
	-- Main simulation process
	---------------------------------------------------------------------------
	testProcess : process
	begin
		test_completed_s <= '0';
		dump_results_s   <= '0';
		reset_s          <= '1';
		accel_start_s    <= '0';

		wait for clock_period;
		reset_s       <= '0';
		accel_start_s <= '1';

		wait for clock_period;
		accel_start_s <= '0';

		wait until accel_ready_s = '1';		
		
		test_completed_s <= '1';
		dump_results_s   <= '1';
		wait for clock_period;

		dump_results_s <= '0';
		wait;

	end process;

end simulate;

