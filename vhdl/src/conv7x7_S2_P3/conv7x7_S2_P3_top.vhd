library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv7x7_S2_P3_top is
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
end entity conv7x7_S2_P3_top;

architecture RTL of conv7x7_S2_P3_top is

	component conv7x7_S2_P3_ctrl
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
			i_clk              : in  std_logic;
			i_reset            : in  std_logic;
			i_start            : in  std_logic;
			i_padding_mode     : in  std_logic_vector(2 downto 0);
			o_busy             : out std_logic;
			i_kernel           : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_kread_addr       : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_grabber_start    : out std_logic;
			i_grabber_busy     : in  std_logic;
			o_init_line_rd     : out std_logic;
			i_init_line_data   : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_init_pixels_rd   : out std_logic;
			i_init_pixels_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			o_pixels_rd        : out std_logic;
			i_pixels_data      : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			o_pixel_rd         : out std_logic;
			i_pixel_data       : in  std_logic_vector(g_DataW - 1 downto 0);
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
	end component conv7x7_S2_P3_ctrl;

	component conv7x7_S2_P3_data_grabber
		generic(
			g_Pox               : in integer;
			g_Poy               : in integer;
			g_DataW             : in integer;
			g_DataBramAddrWidth : in integer
		);
		port(
			i_clk              : in  std_logic;
			i_reset            : in  std_logic;
			i_start            : in  std_logic;
			o_busy             : out std_logic;
			i_buffer_line      : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			o_readaddr         : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_readen           : out std_logic;
			i_init_line_rd     : in  std_logic;
			o_init_line_data   : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_init_pixels_rd   : in  std_logic;
			o_init_pixels_data : out std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			i_pixels_rd        : in  std_logic;
			o_pixels_data      : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			i_pixel_rd         : in  std_logic;
			o_pixel_data       : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component conv7x7_S2_P3_data_grabber;

	signal dgrabber_start : std_logic;
	signal dgrabber_busy  : std_logic;

	signal dreaden_s     : std_logic;
	signal dvalid_s      : std_logic;
	signal col_s         : std_logic_vector(7 downto 0);
	signal row_s         : std_logic_vector(7 downto 0);
	signal init_line_s   : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal init_pixels_s : std_logic_vector(g_Pox * g_DataW - 1 downto 0);
	signal pixels_s      : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal pixel_s       : std_logic_vector(g_DataW - 1 downto 0);

	signal init_line_rd_s     : std_logic;
	signal init_line_data_s   : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal init_pixels_rd_s   : std_logic;
	signal init_pixels_data_s : std_logic_vector(g_Pox * g_DataW - 1 downto 0);
	signal pixels_rd_s        : std_logic;
	signal pixels_data_s      : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal pixel_rd_s         : std_logic;
	signal pixel_data_s       : std_logic_vector(g_DataW - 1 downto 0);

begin

	dgrabber : component conv7x7_S2_P3_data_grabber
		generic map(
			g_Pox               => g_Pox,
			g_Poy               => g_Poy,
			g_DataW             => g_DataW,
			g_DataBramAddrWidth => g_DataBramAddrWidth
		)
		port map(
			i_clk              => i_clk,
			i_reset            => i_reset,
			i_start            => dgrabber_start,
			o_busy             => dgrabber_busy,
			i_buffer_line      => i_buffer_line,
			o_readaddr         => o_readaddr_data,
			o_readen           => open,
			i_init_line_rd     => init_line_rd_s,
			o_init_line_data   => init_line_data_s,
			i_init_pixels_rd   => init_pixels_rd_s,
			o_init_pixels_data => init_pixels_data_s,
			i_pixels_rd        => pixels_rd_s,
			o_pixels_data      => pixels_data_s,
			i_pixel_rd         => pixel_rd_s,
			o_pixel_data       => pixel_data_s
		);

	ctrl : component conv7x7_S2_P3_ctrl
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
			i_reset            => i_reset,
			i_start            => i_start,
			i_padding_mode     => i_padding_mode,
			o_busy             => o_busy,
			i_kernel           => i_kernels,
			o_kread_addr       => o_readaddr_kernels,
			o_grabber_start    => dgrabber_start,
			i_grabber_busy     => dgrabber_busy,
			o_init_line_rd     => init_line_rd_s,
			i_init_line_data   => init_line_data_s,
			o_init_pixels_rd   => init_pixels_rd_s,
			i_init_pixels_data => init_pixels_data_s,
			o_pixels_rd        => pixels_rd_s,
			i_pixels_data      => pixels_data_s,
			o_pixel_rd         => pixel_rd_s,
			i_pixel_data       => pixel_data_s,
			o_mac_en           => o_mac_en,
			o_mac_weight       => o_mac_weight,
			o_reg_en           => o_reg_en,
			o_pe_padding       => o_pe_padding,
			o_init_mode        => o_init_mode,
			o_init_data        => o_init_data,
			o_pixel            => o_pixel,
			o_fifo_wr_en       => o_fifo_wr_en,
			o_fifo_rd_en       => o_fifo_rd_en,
			o_fifo_mode        => o_fifo_mode
		);

end architecture RTL;
