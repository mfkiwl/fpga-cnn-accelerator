library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpeaccel is
	generic(
		-- Users to add parameters here
		C_POX                   : in integer := 3;
		C_POY                   : in integer := 3;
		C_POF                   : in integer := 3;
		C_NUM_BUFFERS           : in integer := 3;
		C_DATA_W                : in integer := 32;
		C_WEIGHT_W              : in integer := 16;
		C_DATABRAM_ADDR_WIDTH   : in integer := 32;
		C_KERNELBRAM_ADDR_WIDTH : in integer := 32;
		C_OUTPUTBRAM_ADDR_WIDTH : in integer := 32;
		-- User parameters ends
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH    : integer    := 32;
		C_S00_AXI_ADDR_WIDTH    : integer    := 7
	);
	port(
		-- Users to add ports here
		dbram_rd_data     : in  std_logic_vector(C_POY * C_POX * C_DATA_W - 1 downto 0);
		dbram_rd_address  : out std_logic_vector(C_DATABRAM_ADDR_WIDTH - 1 downto 0);
		dbram_rd_en       : out std_logic;
		kbram_rd_data     : in  std_logic_vector(C_POF * C_WEIGHT_W - 1 downto 0);
		kbram_rd_address  : out std_logic_vector(C_KERNELBRAM_ADDR_WIDTH - 1 downto 0);
		kbram_rd_en       : out std_logic;
		outbuf_rd_data    : in  std_logic_vector(C_NUM_BUFFERS * C_POX * C_DATA_W - 1 downto 0);
		outbuf_rd_address : out std_logic_vector(C_NUM_BUFFERS * C_OUTPUTBRAM_ADDR_WIDTH - 1 downto 0);
		outbuf_rd_en      : out std_logic_vector(C_NUM_BUFFERS - 1 downto 0);
		outbuf_wr_data    : out std_logic_vector(C_NUM_BUFFERS * C_POX * C_DATA_W - 1 downto 0);
		outbuf_wr_address : out std_logic_vector(C_NUM_BUFFERS * C_OUTPUTBRAM_ADDR_WIDTH - 1 downto 0);
		outbuf_wr_en      : out std_logic_vector(C_NUM_BUFFERS - 1 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk      : in  std_logic;
		s00_axi_aresetn   : in  std_logic;
		s00_axi_awaddr    : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH - 1 downto 0);
		s00_axi_awprot    : in  std_logic_vector(2 downto 0);
		s00_axi_awvalid   : in  std_logic;
		s00_axi_awready   : out std_logic;
		s00_axi_wdata     : in  std_logic_vector(C_S00_AXI_DATA_WIDTH - 1 downto 0);
		s00_axi_wstrb     : in  std_logic_vector((C_S00_AXI_DATA_WIDTH / 8) - 1 downto 0);
		s00_axi_wvalid    : in  std_logic;
		s00_axi_wready    : out std_logic;
		s00_axi_bresp     : out std_logic_vector(1 downto 0);
		s00_axi_bvalid    : out std_logic;
		s00_axi_bready    : in  std_logic;
		s00_axi_araddr    : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH - 1 downto 0);
		s00_axi_arprot    : in  std_logic_vector(2 downto 0);
		s00_axi_arvalid   : in  std_logic;
		s00_axi_arready   : out std_logic;
		s00_axi_rdata     : out std_logic_vector(C_S00_AXI_DATA_WIDTH - 1 downto 0);
		s00_axi_rresp     : out std_logic_vector(1 downto 0);
		s00_axi_rvalid    : out std_logic;
		s00_axi_rready    : in  std_logic
	);
end mpeaccel;

architecture arch_imp of mpeaccel is

	-- component declaration
	component mpeaccel_AXI
		generic(
			C_S_AXI_DATA_WIDTH : integer;
			C_S_AXI_ADDR_WIDTH : integer
		);
		port(
			o_opMode                 : out std_logic_vector(1 downto 0);
			o_start                  : out std_logic;
			i_ready                  : in  std_logic;
			o_xDim                   : out std_logic_vector(15 downto 0);
			o_yDim                   : out std_logic_vector(15 downto 0);
			o_flattenedDim           : out std_logic_vector(15 downto 0);
			o_xIterations            : out std_logic_vector(15 downto 0);
			o_yIterations            : out std_logic_vector(15 downto 0);
			o_numInputFmaps          : out std_logic_vector(15 downto 0);
			o_inFmapBuflines         : out std_logic_vector(15 downto 0);
			o_outFmapBuflines        : out std_logic_vector(15 downto 0);
			o_fclayerKernelBufflines : out std_logic_vector(15 downto 0);
			o_fclayerDataBufflines   : out std_logic_vector(15 downto 0);
			o_fclayerElemPerBuffline : out std_logic_vector(15 downto 0);
			o_tileIterations         : out std_logic_vector(15 downto 0);
			o_numOutbufFmaps         : out std_logic_vector(15 downto 0);
			S_AXI_ACLK               : in  std_logic;
			S_AXI_ARESETN            : in  std_logic;
			S_AXI_AWADDR             : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
			S_AXI_AWPROT             : in  std_logic_vector(2 downto 0);
			S_AXI_AWVALID            : in  std_logic;
			S_AXI_AWREADY            : out std_logic;
			S_AXI_WDATA              : in  std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
			S_AXI_WSTRB              : in  std_logic_vector((C_S_AXI_DATA_WIDTH / 8) - 1 downto 0);
			S_AXI_WVALID             : in  std_logic;
			S_AXI_WREADY             : out std_logic;
			S_AXI_BRESP              : out std_logic_vector(1 downto 0);
			S_AXI_BVALID             : out std_logic;
			S_AXI_BREADY             : in  std_logic;
			S_AXI_ARADDR             : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
			S_AXI_ARPROT             : in  std_logic_vector(2 downto 0);
			S_AXI_ARVALID            : in  std_logic;
			S_AXI_ARREADY            : out std_logic;
			S_AXI_RDATA              : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
			S_AXI_RRESP              : out std_logic_vector(1 downto 0);
			S_AXI_RVALID             : out std_logic;
			S_AXI_RREADY             : in  std_logic
		);
	end component mpeaccel_AXI;

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

	signal opMode_s                 : std_logic_vector(3 downto 0);
	signal start_s                  : std_logic;
	signal ready_s                  : std_logic;
	signal xDim_s                   : std_logic_vector(15 downto 0);
	signal yDim_s                   : std_logic_vector(15 downto 0);
	signal flattenedDim_s           : std_logic_vector(15 downto 0);
	signal xIterations_s            : std_logic_vector(15 downto 0);
	signal yIterations_s            : std_logic_vector(15 downto 0);
	signal numInputFmaps_s          : std_logic_vector(15 downto 0);
	signal inFmapBuflines_s         : std_logic_vector(15 downto 0);
	signal outFmapBuflines_s        : std_logic_vector(15 downto 0);
	signal fclayerKernelBufflines_s : std_logic_vector(15 downto 0);
	signal fclayerDataBufflines_s   : std_logic_vector(15 downto 0);
	signal fclayerElemPerBuffline_s : std_logic_vector(15 downto 0);
	signal tileIterations_s         : std_logic_vector(15 downto 0);
	signal numOutbufFmaps_s         : std_logic_vector(15 downto 0);
			
	signal kernelSize_s 			: std_logic_vector(15 downto 0);
	signal convType_s 				: std_logic_vector(15 downto 0);
	signal numConvblockBuflines_s	: std_logic_vector(15 downto 0);
	signal i_bnormAlpha_s 			: std_logic_vector(15 downto 0);
	signal i_bnormBeta_s 			: std_logic_vector(15 downto 0);

begin


	-- Instantiation of Axi Bus Interface S00_AXI
	mpeaccel_AXI_inst : mpeaccel_AXI
		generic map(
			C_S_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
			C_S_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
		)
		port map(
			o_opMode                 => opMode_s(1 downto 0),
			o_start                  => start_s,
			i_ready                  => ready_s,
			o_xDim                   => xDim_s,
			o_yDim                   => yDim_s,
			o_flattenedDim           => flattenedDim_s,
			o_xIterations            => xIterations_s,
			o_yIterations            => yIterations_s,
			o_numInputFmaps          => numInputFmaps_s,
			o_inFmapBuflines         => inFmapBuflines_s,
			o_outFmapBuflines        => outFmapBuflines_s,
			o_fclayerKernelBufflines => fclayerKernelBufflines_s,
			o_fclayerDataBufflines   => fclayerDataBufflines_s,
			o_fclayerElemPerBuffline => fclayerElemPerBuffline_s,
			o_tileIterations         => tileIterations_s,
			o_numOutbufFmaps         => numOutbufFmaps_s,
			S_AXI_ACLK               => s00_axi_aclk,
			S_AXI_ARESETN            => s00_axi_aresetn,
			S_AXI_AWADDR             => s00_axi_awaddr,
			S_AXI_AWPROT             => s00_axi_awprot,
			S_AXI_AWVALID            => s00_axi_awvalid,
			S_AXI_AWREADY            => s00_axi_awready,
			S_AXI_WDATA              => s00_axi_wdata,
			S_AXI_WSTRB              => s00_axi_wstrb,
			S_AXI_WVALID             => s00_axi_wvalid,
			S_AXI_WREADY             => s00_axi_wready,
			S_AXI_BRESP              => s00_axi_bresp,
			S_AXI_BVALID             => s00_axi_bvalid,
			S_AXI_BREADY             => s00_axi_bready,
			S_AXI_ARADDR             => s00_axi_araddr,
			S_AXI_ARPROT             => s00_axi_arprot,
			S_AXI_ARVALID            => s00_axi_arvalid,
			S_AXI_ARREADY            => s00_axi_arready,
			S_AXI_RDATA              => s00_axi_rdata,
			S_AXI_RRESP              => s00_axi_rresp,
			S_AXI_RVALID             => s00_axi_rvalid,
			S_AXI_RREADY             => s00_axi_rready
		);

	-- Add user logic here
	accel_inst : component accelerator
		generic map(
			g_Pox                 => C_POX,
			g_Poy                 => C_POY,
			g_Pof                 => C_POF,
			g_NumBuffers          => C_NUM_BUFFERS,
			g_DataW               => C_DATA_W,
			g_WeightW             => C_WEIGHT_W,
			g_DataBramAddrWidth   => C_DATABRAM_ADDR_WIDTH,
			g_KernelBramAddrWidth => C_KERNELBRAM_ADDR_WIDTH,
			g_OutputBramAddrWidth => C_OUTPUTBRAM_ADDR_WIDTH
		)
		port map(
			i_clk                        => s00_axi_aclk,
			i_reset                      => s00_axi_aresetn,
			i_opMode                     => opMode_s,
			i_start                      => start_s,
			o_ready                      => ready_s,
			i_kernelSize                 => kernelSize_s,
			i_xDim                       => xDim_s,
			i_yDim                       => yDim_s,
			i_xIterations                => xIterations_s,
			i_yIterations                => yIterations_s,
			i_convType                   => convType_s,
			i_numConvblockBuflines       => numConvblockBuflines_s,
			i_numInputFmaps              => numInputFmaps_s,
			i_inFmapBuflines             => inFmapBuflines_s,
			i_outFmapBuflines            => outFmapBuflines_s,
			i_fclayer_flatdim            => flattenedDim_s,
			i_fclayer_data_bufnumlines   => fclayerDataBufflines_s,
			i_fclayer_kernel_bufnumlines => fclayerKernelBufflines_s,
			i_tileIterations             => tileIterations_s,
			i_numOutbufFmaps             => numOutbufFmaps_s,
			i_bnormAlpha                 => i_bnormAlpha_s,
			i_bnormBeta                  => i_bnormBeta_s,
			i_dbram_line                 => dbram_rd_data,
			o_dbram_rd_address           => dbram_rd_address,
			o_dbram_rd_en                => dbram_rd_en,
			i_kbram_line                 => kbram_rd_data,
			o_kbram_rd_address           => kbram_rd_address,
			o_kbram_rd_en                => kbram_rd_en,
			i_outbuf_line                => outbuf_rd_data,
			o_outbuf_rd_address          => outbuf_rd_address,
			o_outbuf_rd_en               => outbuf_rd_en,
			o_outbuf_line                => outbuf_wr_data,
			o_outbuf_wr_address          => outbuf_wr_address,
			o_outbuf_wr_en               => outbuf_wr_en
		);
		-- User logic ends
end arch_imp;
