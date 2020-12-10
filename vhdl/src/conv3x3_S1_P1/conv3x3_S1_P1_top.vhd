library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv3x3_S1_P1_top is
	generic(
		g_Pox                 : in integer := 3;
		g_Poy                 : in integer := 3;
		g_Pof                 : in integer := 3;
		g_DataW               : in integer := 16;
		g_WeightW             : in integer := 16;
		g_DataBramAddrWidth   : in integer := 16;
		g_KernelBramAddrWidth : in integer := 16
	);
	port(
		i_clk              : in  std_logic;
		i_reset            : in  std_logic;
		i_start            : in  std_logic;
		o_busy             : out std_logic;
		i_padding_mode     : in  std_logic_vector(2 downto 0);
		o_readaddr_data    : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_readen_data      : out std_logic;
		i_buffer_line      : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		i_kernels          : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_readaddr_kernels : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		o_readen_kernels   : out std_logic;
		o_mac_en           : out std_logic;
		o_mac_weight       : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_reg_en           : out std_logic_vector(g_Poy - 1 downto 0);
		o_pe_padding       : out std_logic_vector(2 downto 0);
		o_init_mode        : out std_logic_vector(g_Poy - 1 downto 0);
		o_init_data        : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_pixel            : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		o_fifo_wr_en       : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_rd_en       : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_mode        : out std_logic_vector(g_Poy - 1 downto 0)
	);
end entity conv3x3_S1_P1_top;

architecture RTL of conv3x3_S1_P1_top is

	component conv3x3_S1_P1_data_grabber
		generic(
			g_Pox               : in integer;
			g_Poy               : in integer;
			g_DataW             : in integer;
			g_DataBramAddrWidth : in integer
		);
		port(
			i_clk            : in  std_logic;
			i_reset          : in  std_logic;
			i_start          : in  std_logic;
			o_ready          : out std_logic;
			i_buffer_line    : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_readaddr       : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_readen         : out std_logic;
			o_init_L0        : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_init_L2_C1     : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_init_L2_C2     : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_pixels_L1_P1   : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			o_pixels_L1_P2   : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			o_pixel_L3_C1_P1 : out std_logic_vector(g_DataW - 1 downto 0);
			o_pixel_L3_C1_P2 : out std_logic_vector(g_DataW - 1 downto 0);
			o_pixel_L3_C2_P1 : out std_logic_vector(g_DataW - 1 downto 0);
			o_pixel_L3_C2_P2 : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component conv3x3_S1_P1_data_grabber;

	component conv3x3_S1_P1_ctrl
		generic(
			g_Pox                 : integer;
			g_Poy                 : integer;
			g_Pof                 : integer;
			g_DataW               : integer;
			g_WeightW             : integer;
			g_DataBramAddrWidth   : integer;
			g_KernelBramAddrWidth : integer
		);
		port(
			i_clk            : in  std_logic;
			i_reset          : in  std_logic;
			i_kernel         : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			i_start          : in  std_logic;
			i_padding_mode   : in  std_logic_vector(2 downto 0);
			o_kread_addr     : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			i_grabber_ready  : in  std_logic;
			i_init_L0        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_init_L2_C1     : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_init_L2_C2     : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_pixels_L1_P1   : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			i_pixels_L1_P2   : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			i_pixel_L3_C1_P1 : in  std_logic_vector(g_DataW - 1 downto 0);
			i_pixel_L3_C1_P2 : in  std_logic_vector(g_DataW - 1 downto 0);
			i_pixel_L3_C2_P1 : in  std_logic_vector(g_DataW - 1 downto 0);
			i_pixel_L3_C2_P2 : in  std_logic_vector(g_DataW - 1 downto 0);
			o_busy           : out std_logic;
			o_mac_en         : out std_logic;
			o_mac_weight     : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_reg_en         : out std_logic_vector(g_Poy - 1 downto 0);
			o_pe_padding     : out std_logic_vector(2 downto 0);
			o_init_mode      : out std_logic_vector(g_Poy - 1 downto 0);
			o_init_data      : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_pixel          : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			o_fifo_wr_en     : out std_logic_vector(g_Poy - 1 downto 0);
			o_fifo_rd_en     : out std_logic_vector(g_Poy - 1 downto 0);
			o_fifo_mode      : out std_logic_vector(g_Poy - 1 downto 0)
		);
	end component conv3x3_S1_P1_ctrl;

	signal init_L0        : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal init_L2_C1     : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal init_L2_C2     : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal pixels_L1_P1   : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal pixels_L1_P2   : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal pixel_L3_C1_P1 : std_logic_vector(g_DataW - 1 downto 0);
	signal pixel_L3_C1_P2 : std_logic_vector(g_DataW - 1 downto 0);
	signal pixel_L3_C2_P1 : std_logic_vector(g_DataW - 1 downto 0);
	signal pixel_L3_C2_P2 : std_logic_vector(g_DataW - 1 downto 0);

	signal data_grabber_rdy : std_logic;
begin

	dgrabber : conv3x3_S1_P1_data_grabber
		generic map(
			g_Pox               => g_Pox,
			g_Poy               => g_Poy,
			g_DataW             => g_DataW,
			g_DataBramAddrWidth => g_DataBramAddrWidth
		)
		port map(
			i_clk            => i_clk,
			i_reset          => i_reset,
			i_start          => i_start,
			o_ready          => data_grabber_rdy,
			i_buffer_line    => i_buffer_line,
			o_readaddr       => o_readaddr_data,
			o_readen         => o_readen_data,
			o_init_L0        => init_L0,
			o_init_L2_C1     => init_L2_C1,
			o_init_L2_C2     => init_L2_C2,
			o_pixels_L1_P1   => pixels_L1_P1,
			o_pixels_L1_P2   => pixels_L1_P2,
			o_pixel_L3_C1_P1 => pixel_L3_C1_P1,
			o_pixel_L3_C1_P2 => pixel_L3_C1_P2,
			o_pixel_L3_C2_P1 => pixel_L3_C2_P1,
			o_pixel_L3_C2_P2 => pixel_L3_C2_P2
		);

	convolver : conv3x3_S1_P1_ctrl
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
			i_clk            => i_clk,
			i_reset          => i_reset,
			i_kernel         => i_kernels,
			i_start          => i_start,
			i_padding_mode   => i_padding_mode,
			o_kread_addr     => o_readaddr_kernels,
			i_grabber_ready  => data_grabber_rdy,
			i_init_L0        => init_L0,
			i_init_L2_C1     => init_L2_C1,
			i_init_L2_C2     => init_L2_C2,
			i_pixels_L1_P1   => pixels_L1_P1,
			i_pixels_L1_P2   => pixels_L1_P2,
			i_pixel_L3_C1_P1 => pixel_L3_C1_P1,
			i_pixel_L3_C1_P2 => pixel_L3_C1_P2,
			i_pixel_L3_C2_P1 => pixel_L3_C2_P1,
			i_pixel_L3_C2_P2 => pixel_L3_C2_P2,
			o_busy           => o_busy,
			o_mac_en         => o_mac_en,
			o_mac_weight     => o_mac_weight,
			o_reg_en         => o_reg_en,
			o_pe_padding     => o_pe_padding,
			o_init_mode      => o_init_mode,
			o_init_data      => o_init_data,
			o_pixel          => o_pixel,
			o_fifo_wr_en     => o_fifo_wr_en,
			o_fifo_rd_en     => o_fifo_rd_en,
			o_fifo_mode      => o_fifo_mode
		);

end architecture RTL;
