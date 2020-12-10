library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity convolver is
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
		-- Data Bus
		i_buffer_line          : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_dbram_rd_address     : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_dbram_rd_en          : out std_logic;
		-- Kernel Bus
		i_kernels              : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_kbram_rd_address     : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		o_kbram_rd_en          : out std_logic;
		o_mac_en               : out std_logic;
		o_mac_reset            : out std_logic;
		o_mac_weight           : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_mac_input            : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0)
	);
end entity convolver;

architecture RTL of convolver is

	component conv_control
		generic(
			g_DataBramAddrWidth   : in integer;
			g_KernelBramAddrWidth : in integer
		);
		port(
			i_clk                  : in  std_logic;
			i_reset                : in  std_logic;
			i_start                : in  std_logic;
			o_ready                : out std_logic;
			i_conv_busy            : in  std_logic;
			o_conv_start           : out std_logic;
			o_conv_reset           : out std_logic;
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
			o_padding_mode         : out std_logic_vector(2 downto 0);
			o_dread_base           : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_kread_base           : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0)
		);
	end component conv_control;

	component conv_router
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
			i_clk              : in  std_logic;
			i_reset            : in  std_logic;
			i_start            : in  std_logic;
			o_busy             : out std_logic;
			i_padding_mode     : in  std_logic_vector(2 downto 0);
			i_convType         : in  std_logic_vector(15 downto 0);
			i_buffer_line      : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_readaddr_data    : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_readen_data      : out std_logic;
			i_kernels          : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_readaddr_kernels : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_readen_kernels   : out std_logic;
			o_mac_en           : out std_logic;
			o_mac_weight       : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_mac_input        : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0)
		);
	end component conv_router;

	signal router_reset_s        : std_logic;
	signal router_start_s        : std_logic;
	signal router_busy_s         : std_logic;
	signal router_padding_mode_s : std_logic_vector(2 downto 0);

	signal dread_base_s   : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal dread_offset_s : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal kread_base_s   : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal kread_offset_s : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

begin

	o_dbram_rd_address <= std_logic_vector(unsigned(dread_offset_s) + unsigned(dread_base_s));
	o_kbram_rd_address <= std_logic_vector(unsigned(kread_offset_s) + unsigned(kread_base_s));
	o_mac_reset        <= router_reset_s;

	uut : conv_router
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
			i_clk              => i_clk,
			i_reset            => router_reset_s,
			i_start            => router_start_s,
			o_busy             => router_busy_s,
			i_padding_mode     => router_padding_mode_s,
			i_convType         => i_convType,
			i_buffer_line      => i_buffer_line,
			o_readaddr_data    => dread_offset_s,
			o_readen_data      => o_dbram_rd_en,
			i_kernels          => i_kernels,
			o_readaddr_kernels => kread_offset_s,
			o_readen_kernels   => o_kbram_rd_en,
			o_mac_en           => o_mac_en,
			o_mac_weight       => o_mac_weight,
			o_mac_input        => o_mac_input
		);

	-- Controller
	ctrl : conv_control
		generic map(
			g_DataBramAddrWidth   => g_DataBramAddrWidth,
			g_KernelBramAddrWidth => g_KernelBramAddrWidth
		)
		port map(
			i_clk                  => i_clk,
			i_reset                => i_reset,
			i_start                => i_start,
			o_ready                => o_ready,
			i_conv_busy            => router_busy_s,
			o_conv_start           => router_start_s,
			o_conv_reset           => router_reset_s,
			i_p2s_busy             => i_p2s_busy,
			o_p2s_start            => o_p2s_start,
			i_kernelSize           => i_kernelSize,
			i_iterX                => i_iterX,
			i_iterY                => i_iterY,
			i_convType             => i_convType,
			i_numConvblockBuflines => i_numConvblockBuflines,
			i_numInputFmaps        => i_numInputFmaps,
			i_fmapBuflines         => i_fmapBuflines,
			i_tileIterations       => i_tileIterations,
			o_padding_mode         => router_padding_mode_s,
			o_dread_base           => dread_base_s,
			o_kread_base           => kread_base_s
		);

end architecture RTL;
