library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity core_unit is
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
		-- Start / Ready
		i_start                      : in  std_logic;
		i_fcmode                     : in  std_logic;
		i_ReLU                       : in  std_logic;
		i_bNorm                      : in  std_logic;		
		o_ready                      : out std_logic;
		-- Dimensions of convolution feature map
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
		-- Data Bus
		i_buffer_line                : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_dbram_rd_address           : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_dbram_rd_en                : out std_logic;
		-- Kernel Bus
		i_kernels                    : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_kbram_rd_address           : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		o_kbram_rd_en                : out std_logic;
		-- Result Bus
		o_result                     : out std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
		o_outbuf_wraddr              : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
		o_outbuf_wren                : out std_logic_vector(g_NumBuffers - 1 downto 0)
	);
end entity core_unit;

architecture RTL of core_unit is

	constant MuxInputWidth  : integer := (g_Pof / g_NumBuffers) * g_Poy * g_Pox * g_DataW;
	constant MuxOutputWidth : integer := g_Pox * g_DataW;

	component parallel2serial
		generic(
			g_ParallelWidth       : integer;
			g_SerialWidth         : integer;
			g_OutputBramAddrWidth : integer
		);
		port(
			i_clk   : in  std_logic;
			i_reset : in  std_logic;
			i_start : in  std_logic;
			o_busy  : out std_logic;
			i_data  : in  std_logic_vector(g_ParallelWidth - 1 downto 0);
			o_data  : out std_logic_vector(g_SerialWidth - 1 downto 0);
			o_wren  : out std_logic;
			o_waddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0)
		);
	end component parallel2serial;

	component mac_array
		generic(
			g_Pox     : integer;
			g_Poy     : integer;
			g_DataW   : integer;
			g_WeightW : integer
		);
		port(
			i_clk    : in  std_logic;
			i_reset  : in  std_logic;
			i_mac_en : in  std_logic_vector(g_Pox * g_Poy - 1 downto 0);
			i_data   : in  std_logic_vector(g_Pox * g_Poy * g_DataW - 1 downto 0);
			i_weight : in  std_logic_vector(g_WeightW - 1 downto 0);
			o_result : out std_logic_vector(g_Pox * g_Poy * g_DataW - 1 downto 0)
		);
	end component mac_array;

	component convolver
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_NumBuffers          : in integer;
			g_DataW               : in integer;
			g_WeightW             : in integer;
			g_DataBramAddrWidth   : in integer;
			g_KernelBramAddrWidth : in integer
		);
		port(
			i_clk                  : in  std_logic;
			i_reset                : in  std_logic;
			i_start                : in  std_logic;
			o_ready                : out std_logic;
			i_p2s_busy             : in  std_logic;
			o_p2s_start            : out std_logic;
			i_kernelSize           : in  std_logic_vector(15 downto 0);
			i_iterX                : in  std_logic_vector(15 downto 0);
			i_iterY                : in  std_logic_vector(15 downto 0);
			i_convType             : in  std_logic_vector(15 downto 0);
			i_numConvblockBuflines : in  std_logic_vector(15 downto 0);
			i_numInputFmaps        : in  std_logic_vector(15 downto 0);
			i_fmapBuflines         : in  std_logic_vector(15 downto 0);
			i_tileIterations       : in  std_logic_vector(15 downto 0);
			i_buffer_line          : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_dbram_rd_address     : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_dbram_rd_en          : out std_logic;
			i_kernels              : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_kbram_rd_address     : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_kbram_rd_en          : out std_logic;
			o_mac_en               : out std_logic;
			o_mac_reset            : out std_logic;
			o_mac_weight           : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_mac_input            : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0)
		);
	end component convolver;

	component fclayer
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_DataW               : in integer;
			g_WeightW             : in integer;
			g_DataBramAddrWidth   : in integer;
			g_KernelBramAddrWidth : in integer
		);
		port(
			i_clk                : in  std_logic;
			i_reset              : in  std_logic;
			i_start              : in  std_logic;
			o_ready              : out std_logic;
			i_numInputFmaps      : in  std_logic_vector(15 downto 0);
			i_flatdim            : in  std_logic_vector(15 downto 0);
			i_data_bufnumlines   : in  std_logic_vector(15 downto 0);
			i_kernel_bufnumlines : in  std_logic_vector(15 downto 0);
			i_xDim               : in  std_logic_vector(15 downto 0);
			i_yDim               : in  std_logic_vector(15 downto 0);
			i_tileIterations     : in  std_logic_vector(15 downto 0);
			i_buffer_line        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_dread_base         : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			i_kernels            : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_kread_base         : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_dbram_rd_en        : out std_logic;
			o_mac_reset          : out std_logic;
			o_mac_en             : out std_logic_vector(g_Pof * g_Poy * g_Pox - 1 downto 0);
			o_mac_weight         : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_mac_input          : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_p2s_start          : out std_logic;
			i_p2s_busy           : in  std_logic
		);
	end component fclayer;

	component ReLU
		generic(
			g_Pox   : integer;
			g_DataW : integer
		);
		port(
			i_en   : in  std_logic;
			i_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			o_data : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
		);
	end component ReLU;
	
	component batch_normalization
		generic(
			g_Pox   : integer;
			g_DataW : integer
		);
		port(
			i_en    : in  std_logic;
			i_alpha : in  std_logic_vector(15 downto 0);
			i_beta  : in  std_logic_vector(15 downto 0);
			i_data  : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			o_data  : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
		);
	end component batch_normalization;

	-- Convolver signals
	signal conv_start_s      : std_logic;
	signal conv_ready_s      : std_logic;
	signal conv_kread_addr_s : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal conv_dbram_rd_en  : std_logic;
	signal conv_dread_addr_s : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal conv_kbram_rd_en  : std_logic;

	-- conv-mac interface
	signal conv_mac_en_s     : std_logic;
	signal conv_mac_reset_s  : std_logic;
	signal conv_mac_weight_s : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
	signal conv_mac_input_s  : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);

	-- conv-p2s interface
	signal conv_p2s_start_s : std_logic;
	signal conv_p2s_busy_s  : std_logic_vector(g_NumBuffers - 1 downto 0);

	-- fc-layer connections
	signal fclayer_start_s      : std_logic;
	signal fclayer_ready_s      : std_logic;
	signal fclayer_dread_base_s : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal fclayer_kread_base_s : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal fclayer_dbram_rd_en  : std_logic;

	-- fc-layer - mac interface
	signal fclayer_mac_reset_s  : std_logic;
	signal fclayer_mac_en_s     : std_logic_vector(g_Pof * g_Poy * g_Pox - 1 downto 0);
	signal fclayer_mac_weight_s : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
	signal fclayer_mac_input_s  : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);

	-- fc-layer - p2s interface
	signal fclayer_p2s_start_s : std_logic;
	signal fclayer_p2s_busy_s  : std_logic_vector(g_NumBuffers - 1 downto 0);

	-- output p2s signals
	signal p2s_start_s  : std_logic;
	signal p2s_busy_s   : std_logic_vector(g_NumBuffers - 1 downto 0);
	signal p2s_output_s : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);

	-- relu output
	signal relu_output_s : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);

	-- mac array signals
	signal mac_reset_s  : std_logic;
	signal mac_en_s     : std_logic_vector(g_Pof * g_Poy * g_Pox - 1 downto 0);
	signal mac_weight_s : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
	signal mac_input_s  : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal mac_result_s : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);

	function or_reduce(vector : std_logic_vector) return std_logic is
		variable result : std_logic := '0';
	begin
		for i in vector'range loop
			result := result or vector(i);
		end loop;
		return result;
	end function;

begin

	-- Multiplex signals between FC and Conv mode
	-- Start/Ready signals
	conv_start_s    <= i_start when i_fcmode = '0' else '0';
	fclayer_start_s <= i_start when i_fcmode = '1' else '0';
	o_ready         <= conv_ready_s when i_fcmode = '0' else fclayer_ready_s;

	-- dbram/kbram read addresses and enable
	o_dbram_rd_address <= conv_dread_addr_s when i_fcmode = '0' else fclayer_dread_base_s;
	o_kbram_rd_address <= conv_kread_addr_s when i_fcmode = '0' else fclayer_kread_base_s;
	o_dbram_rd_en      <= conv_dbram_rd_en when i_fcmode = '0' else fclayer_dbram_rd_en;

	-- mac array signals multiplex
	mac_weight_s <= conv_mac_weight_s when i_fcmode = '0' else fclayer_mac_weight_s;
	mac_input_s  <= conv_mac_input_s when i_fcmode = '0' else fclayer_mac_input_s;
	mac_en_s     <= (others => conv_mac_en_s) when i_fcmode = '0' else fclayer_mac_en_s;
	mac_reset_s  <= conv_mac_reset_s when i_fcmode = '0' else fclayer_mac_reset_s;

	-- p2s interface multiplexing
	p2s_start_s        <= conv_p2s_start_s when i_fcmode = '0' else fclayer_p2s_start_s;
	conv_p2s_busy_s    <= p2s_busy_s;
	fclayer_p2s_busy_s <= p2s_busy_s;

	-- MAC array
	gmac : for jj in g_Pof downto 1 generate
	begin
		macarr : component mac_array
			generic map(
				g_Pox     => g_Pox,
				g_Poy     => g_Poy,
				g_DataW   => g_DataW,
				g_WeightW => g_WeightW
			)
			port map(
				i_clk    => i_clk,
				i_reset  => mac_reset_s,
				i_mac_en => mac_en_s(jj * g_Poy * g_Pox - 1 downto (jj - 1) * g_Poy * g_Pox),
				i_data   => mac_input_s(jj * g_Poy * g_Pox * g_DataW - 1 downto (jj - 1) * g_Poy * g_Pox * g_DataW),
				i_weight => mac_weight_s(jj * g_WeightW - 1 downto (jj - 1) * g_WeightW),
				o_result => mac_result_s(jj * g_Poy * g_Pox * g_DataW - 1 downto (jj - 1) * g_Poy * g_Pox * g_DataW)
			);
	end generate;

	conv : component convolver
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_NumBuffers          => g_NumBuffers,
			g_DataW               => g_DataW,
			g_WeightW             => g_WeightW,
			g_DataBramAddrWidth   => g_DataBramAddrWidth,
			g_KernelBramAddrWidth => g_KernelBramAddrWidth
		)
		port map(
			i_clk                  => i_clk,
			i_reset                => i_reset,
			i_start                => conv_start_s,
			o_ready                => conv_ready_s,
			i_p2s_busy             => or_reduce(conv_p2s_busy_s),
			o_p2s_start            => conv_p2s_start_s,
			i_kernelSize           => i_kernelSize,
			i_iterX                => i_xIterations,
			i_iterY                => i_yIterations,
			i_convType             => i_convType,
			i_numConvblockBuflines => i_numConvblockBuflines,
			i_numInputFmaps        => i_numInputFmaps,
			i_fmapBuflines         => i_inFmapBuflines,
			i_tileIterations       => i_tileIterations,
			i_buffer_line          => i_buffer_line,
			o_dbram_rd_address     => conv_dread_addr_s,
			o_dbram_rd_en          => conv_dbram_rd_en,
			i_kernels              => i_kernels,
			o_kbram_rd_address     => conv_kread_addr_s,
			o_kbram_rd_en          => conv_kbram_rd_en,
			o_mac_en               => conv_mac_en_s,
			o_mac_reset            => conv_mac_reset_s,
			o_mac_weight           => conv_mac_weight_s,
			o_mac_input            => conv_mac_input_s
		);

	fc : component fclayer
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_DataW               => g_DataW,
			g_WeightW             => g_WeightW,
			g_DataBramAddrWidth   => g_DataBramAddrWidth,
			g_KernelBramAddrWidth => g_KernelBramAddrWidth
		)
		port map(
			i_clk                => i_clk,
			i_reset              => i_reset,
			i_start              => fclayer_start_s,
			o_ready              => fclayer_ready_s,
			i_numInputFmaps      => i_numInputFmaps,
			i_flatdim            => i_fclayer_flatdim,
			i_data_bufnumlines   => i_fclayer_data_bufnumlines,
			i_kernel_bufnumlines => i_fclayer_kernel_bufnumlines,
			i_xDim               => i_xDim,
			i_yDim               => i_yDim,
			i_tileIterations     => i_tileIterations,
			i_buffer_line        => i_buffer_line,
			o_dread_base         => fclayer_dread_base_s,
			i_kernels            => i_kernels,
			o_kread_base         => fclayer_kread_base_s,
			o_dbram_rd_en        => fclayer_dbram_rd_en,
			o_mac_reset          => fclayer_mac_reset_s,
			o_mac_en             => fclayer_mac_en_s,
			o_mac_weight         => fclayer_mac_weight_s,
			o_mac_input          => fclayer_mac_input_s,
			o_p2s_start          => fclayer_p2s_start_s,
			i_p2s_busy           => or_reduce(fclayer_p2s_busy_s)
		);

	-- P2S
	g1 : for jj in g_NumBuffers downto 1 generate
	begin
		p2s : parallel2serial
			generic map(
				g_ParallelWidth       => MuxInputWidth,
				g_SerialWidth         => MuxOutputWidth,
				g_OutputBramAddrWidth => g_OutputBramAddrWidth
			)
			port map(
				i_clk   => i_clk,
				i_reset => i_reset,
				i_start => p2s_start_s,
				o_busy  => p2s_busy_s(jj - 1),
				i_data  => mac_result_s(jj * MuxInputWidth - 1 downto (jj - 1) * MuxInputWidth),
				o_data  => p2s_output_s(jj * MuxOutputWidth - 1 downto (jj - 1) * MuxOutputWidth),
				o_wren  => o_outbuf_wren(jj - 1),
				o_waddr => o_outbuf_wraddr(jj * g_OutputBramAddrWidth - 1 downto (jj - 1) * g_OutputBramAddrWidth)
			);

		relu_inst : ReLU
			generic map(
				g_Pox   => g_Pox,
				g_DataW => g_DataW
			)
			port map(
				i_en   => i_ReLU,
				i_data => p2s_output_s(jj * MuxOutputWidth - 1 downto (jj - 1) * MuxOutputWidth),
				o_data => relu_output_s(jj * MuxOutputWidth - 1 downto (jj - 1) * MuxOutputWidth)
			);
			
		bnorm_inst : component batch_normalization
			generic map(
				g_Pox   => g_Pox,
				g_DataW => g_DataW
			)
			port map(
				i_en    => i_bNorm,
				i_alpha => i_bnormAlpha,
				i_beta  => i_bnormBeta,
				i_data  => relu_output_s(jj * MuxOutputWidth - 1 downto (jj - 1) * MuxOutputWidth),
				o_data  => o_result(jj * MuxOutputWidth - 1 downto (jj - 1) * MuxOutputWidth)
			);
	end generate;

end architecture RTL;
