library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accelerator is
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
end entity accelerator;

architecture RTL of accelerator is

	component controller
		port(
			i_clk        : in  std_logic;
			i_reset      : in  std_logic;
			i_en_polling : in  std_logic;
			i_en_relu    : in  std_logic;
			i_en_bnorm   : in  std_logic;
			o_obuf_mode  : out std_logic;
			i_start      : in  std_logic;
			o_ready      : out std_logic;
			o_conv_start : out std_logic;
			i_conv_ready : in  std_logic;
			o_relu_on    : out std_logic;
			o_bnorm_on   : out std_logic;
			o_pool_start : out std_logic;
			i_pool_ready : in  std_logic
		);
	end component controller;

	component core_unit
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
			i_start                      : in  std_logic;
			i_fcmode                     : in  std_logic;
			i_ReLU                       : in  std_logic;
			i_bNorm                      : in  std_logic;
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
			i_fclayer_flatdim            : in  std_logic_vector(15 downto 0);
			i_fclayer_data_bufnumlines   : in  std_logic_vector(15 downto 0);
			i_fclayer_kernel_bufnumlines : in  std_logic_vector(15 downto 0);
			i_tileIterations             : in  std_logic_vector(15 downto 0);
			i_bnormAlpha                 : in  std_logic_vector(15 downto 0);
			i_bnormBeta                  : in  std_logic_vector(15 downto 0);
			i_buffer_line                : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_dbram_rd_address           : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_dbram_rd_en                : out std_logic;
			i_kernels                    : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_kbram_rd_address           : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_kbram_rd_en                : out std_logic;
			o_result                     : out std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
			o_outbuf_wraddr              : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
			o_outbuf_wren                : out std_logic_vector(g_NumBuffers - 1 downto 0)
		);
	end component core_unit;

	component pooler
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_NumBuffers          : in integer;
			g_DataW               : in integer;
			g_OutputBramAddrWidth : in integer
		);
		port(
			i_clk               : in  std_logic;
			i_reset             : in  std_logic;
			i_start             : in  std_logic;
			o_ready             : out std_logic;
			i_xDim              : in  std_logic_vector(15 downto 0);
			i_yDim              : in  std_logic_vector(15 downto 0);
			i_numOutbufFmaps    : in  std_logic_vector(15 downto 0);
			i_outFmapBuflines   : in  std_logic_vector(15 downto 0);
			i_tileIterations    : in  std_logic_vector(15 downto 0);
			i_buffer_line       : in  std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
			o_outbuf_rd_address : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
			o_outbuf_rd_en      : out std_logic_vector(g_NumBuffers - 1 downto 0);
			o_buffer_line       : out std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
			o_outbuf_wr_address : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
			o_outbuf_wr_en      : out std_logic_vector(g_NumBuffers - 1 downto 0)
		);
	end component pooler;

	-- pooling unit 
	signal pooler_start_s : std_logic;
	signal pooler_ready_s : std_logic;

	-- convolver
	signal convolver_start_s : std_logic;
	signal convolver_ready_s : std_logic;

	-- ctrl
	signal ctrl_outbuf_mode_s : std_logic;
	signal ctrl_relu_on_s     : std_logic;
	signal ctrl_bnorm_on_s    : std_logic;

	-- outbuf signals and for mux to select between pooling and conv
	signal obuf_conv_wrdata_s   : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal obuf_conv_wraddr_s   : std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
	signal obuf_conv_wren_s     : std_logic_vector(g_NumBuffers - 1 downto 0);
	signal obuf_conv_readaddr_s : std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
	signal obuf_conv_rddata_s   : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);

	signal obuf_pool_wrdata_s   : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal obuf_pool_wraddr_s   : std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
	signal obuf_pool_wren_s     : std_logic_vector(g_NumBuffers - 1 downto 0);
	signal obuf_pool_readaddr_s : std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
	signal obuf_pool_rddata_s   : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);

begin

	----------------------------------------------------
	--- Top-Level signal connections
	----------------------------------------------------
	-- Multiplexers connecting output buffers to either the convolution module or the pooling block depending on mode.
	o_outbuf_line       <= obuf_conv_wrdata_s when ctrl_outbuf_mode_s = '0' else obuf_pool_wrdata_s;
	o_outbuf_wr_address <= obuf_conv_wraddr_s when ctrl_outbuf_mode_s = '0' else obuf_pool_wraddr_s;
	o_outbuf_wr_en      <= obuf_conv_wren_s when ctrl_outbuf_mode_s = '0' else obuf_pool_wren_s;
	o_outbuf_rd_address <= obuf_conv_readaddr_s when ctrl_outbuf_mode_s = '0' else obuf_pool_readaddr_s;

	ctrl : controller
		port map(
			i_clk        => i_clk,
			i_reset      => i_reset,
			i_en_polling => i_opMode(0),
			i_en_relu    => i_opMode(2),
			i_en_bnorm   => i_opMode(3),
			o_obuf_mode  => ctrl_outbuf_mode_s,
			i_start      => i_start,
			o_ready      => o_ready,
			o_conv_start => convolver_start_s,
			i_conv_ready => convolver_ready_s,
			o_relu_on    => ctrl_relu_on_s,
			o_bnorm_on   => ctrl_bnorm_on_s,
			o_pool_start => pooler_start_s,
			i_pool_ready => pooler_ready_s
		);

	core : core_unit
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_NumBuffers          => g_NumBuffers,
			g_DataW               => g_DataW,
			g_WeightW             => g_WeightW,
			g_DataBramAddrWidth   => g_DataBramAddrWidth,
			g_KernelBramAddrWidth => g_KernelBramAddrWidth,
			g_OutputBramAddrWidth => g_OutputBramAddrWidth
		)
		port map(
			i_clk                        => i_clk,
			i_reset                      => i_reset,
			-- Control and Status
			i_start                      => convolver_start_s,
			i_fcmode                     => i_opMode(1),
			i_ReLU                       => ctrl_relu_on_s,
			i_bNorm                      => ctrl_bnorm_on_s,
			o_ready                      => convolver_ready_s,
			-- Driver signals 
			i_kernelSize                 => i_kernelSize,
			-- Metainformation 
			i_xDim                       => i_xDim, -- XDimension of featuremap
			i_yDim                       => i_yDim, -- YDimension of featuremap
			i_xIterations                => i_xIterations, -- Number of processing blocks in XDir under Pox, Poy
			i_yIterations                => i_yIterations, -- Number of processing blocks in YDir under Pox, Poy
			i_convType                   => i_convType,
			i_numConvblockBuflines       => i_numConvblockBuflines,
			i_numInputFmaps              => i_numInputFmaps, -- Number of input feature maps
			i_inFmapBuflines             => i_inFmapBuflines, -- Number of Bufferlines in Input-Dataflow under Pox, Poy
			i_fclayer_flatdim            => i_fclayer_flatdim,
			i_fclayer_data_bufnumlines   => i_fclayer_data_bufnumlines,
			i_fclayer_kernel_bufnumlines => i_fclayer_kernel_bufnumlines,
			i_tileIterations             => i_tileIterations, -- Tiles to process during a single run.
			i_bnormAlpha                 => i_bnormAlpha,
			i_bnormBeta                  => i_bnormBeta,
			-- Data Read
			i_buffer_line                => i_dbram_line,
			o_dbram_rd_address           => o_dbram_rd_address,
			o_dbram_rd_en                => o_dbram_rd_en,
			-- Kernel Read
			i_kernels                    => i_kbram_line,
			o_kbram_rd_address           => o_kbram_rd_address,
			o_kbram_rd_en                => o_kbram_rd_en,
			-- Result Writeback
			o_result                     => obuf_conv_wrdata_s,
			o_outbuf_wraddr              => obuf_conv_wraddr_s,
			o_outbuf_wren                => obuf_conv_wren_s
		);

	pool : component pooler
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_NumBuffers          => g_NumBuffers,
			g_DataW               => g_DataW,
			g_OutputBramAddrWidth => g_OutputBramAddrWidth
		)
		port map(
			-- Driver signals
			i_clk               => i_clk,
			i_reset             => i_reset,
			-- Control and status
			i_start             => pooler_start_s,
			o_ready             => pooler_ready_s,
			-- Metainformation
			i_xDim              => i_xDim,
			i_yDim              => i_yDim,
			i_numOutbufFmaps    => i_numOutbufFmaps,
			i_outFmapBuflines   => i_outFmapBuflines,
			i_tileIterations    => i_tileIterations,
			-- Data read
			i_buffer_line       => i_outbuf_line,
			o_outbuf_rd_address => obuf_pool_readaddr_s,
			o_outbuf_rd_en      => open,
			-- Result writeback
			o_buffer_line       => obuf_pool_wrdata_s,
			o_outbuf_wr_address => obuf_pool_wraddr_s,
			o_outbuf_wr_en      => obuf_pool_wren_s
		);

end architecture RTL;
