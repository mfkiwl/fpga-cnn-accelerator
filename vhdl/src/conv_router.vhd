library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_router is
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

end entity;

architecture rtl of conv_router is

	component conv3x3_S1_P1_top
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
	end component conv3x3_S1_P1_top;

	component conv1x1_S1_P0_top
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
	end component conv1x1_S1_P0_top;

	component processing_element
		generic(
			g_Pox      : integer;
			g_Poy      : integer;
			g_DataW    : integer;
			g_WeightW  : integer;
			g_FifoSize : integer
		);
		port(
			i_clk        : in  std_logic;
			i_reset      : in  std_logic;
			i_reg_en     : in  std_logic_vector(g_Poy - 1 downto 0);
			i_padding    : in  std_logic_vector(2 downto 0);
			i_init_mode  : in  std_logic_vector(g_Poy - 1 downto 0);
			i_fifo_mode  : in  std_logic_vector(g_Poy - 1 downto 0);
			i_init_data  : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_pixel      : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
			i_fifo_wr_en : in  std_logic_vector(g_Poy - 1 downto 0);
			i_fifo_rd_en : in  std_logic_vector(g_Poy - 1 downto 0);
			o_mac_input  : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0)
		);
	end component processing_element;

	-- General signals
	signal mac_input_s : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);

	-- PE signals
	signal pe_reg_en_s      : std_logic_vector(g_Poy - 1 downto 0);
	signal pe_init_mode_s   : std_logic_vector(g_Poy - 1 downto 0);
	signal pe_init_data_s   : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal pe_pixel_s       : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal pe_fifo_wr_en_s  : std_logic_vector(g_Poy - 1 downto 0);
	signal pe_fifo_rd_en_s  : std_logic_vector(g_Poy - 1 downto 0);
	signal pe_fifo_mode_s   : std_logic_vector(g_Poy - 1 downto 0);
	signal pe_cur_padding_s : std_logic_vector(2 downto 0);

	-- CONV1X1 signals
	signal conv1x1_start_s          : std_logic;
	signal conv1x1_busy_s           : std_logic;
	signal conv1x1_reg_en_s         : std_logic_vector(g_Poy - 1 downto 0);
	signal conv1x1_init_mode_s      : std_logic_vector(g_Poy - 1 downto 0);
	signal conv1x1_init_data_s      : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal conv1x1_pixel_s          : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal conv1x1_fifo_wr_en_s     : std_logic_vector(g_Poy - 1 downto 0);
	signal conv1x1_fifo_rd_en_s     : std_logic_vector(g_Poy - 1 downto 0);
	signal conv1x1_fifo_mode_s      : std_logic_vector(g_Poy - 1 downto 0);
	signal conv1x1_cur_padding_s    : std_logic_vector(2 downto 0);
	signal conv1x1_readaddr_data    : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal conv1x1_readaddr_kernels : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal conv1x1_mac_en           : std_logic;
	signal conv1x1_mac_weight       : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);

	-- CONV3X3 signals
	signal conv3x3_start_s          : std_logic;
	signal conv3x3_busy_s           : std_logic;
	signal conv3x3_reg_en_s         : std_logic_vector(g_Poy - 1 downto 0);
	signal conv3x3_init_mode_s      : std_logic_vector(g_Poy - 1 downto 0);
	signal conv3x3_init_data_s      : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal conv3x3_pixel_s          : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal conv3x3_fifo_wr_en_s     : std_logic_vector(g_Poy - 1 downto 0);
	signal conv3x3_fifo_rd_en_s     : std_logic_vector(g_Poy - 1 downto 0);
	signal conv3x3_fifo_mode_s      : std_logic_vector(g_Poy - 1 downto 0);
	signal conv3x3_cur_padding_s    : std_logic_vector(2 downto 0);
	signal conv3x3_readaddr_data    : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal conv3x3_readaddr_kernels : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal conv3x3_mac_en           : std_logic;
	signal conv3x3_mac_weight       : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);

begin
	
	conv1x1_start_s <= '1' when i_start = '1' and i_convType = x"0001" else '0';
	conv3x3_start_s <= '1' when i_start = '1' and i_convType = x"0002" else '0';

	pe_reg_en_s        <= conv3x3_reg_en_s when i_convType = x"0002"
	                      else conv1x1_reg_en_s;
	pe_init_mode_s     <= conv3x3_init_mode_s when i_convType = x"0002"
	                      else conv1x1_init_mode_s;
	pe_init_data_s     <= conv3x3_init_data_s when i_convType = x"0002"
	                      else conv1x1_init_data_s;
	pe_pixel_s         <= conv3x3_pixel_s when i_convType = x"0002"
	                      else conv1x1_pixel_s;
	pe_fifo_wr_en_s    <= conv3x3_fifo_wr_en_s when i_convType = x"0002"
	                      else conv1x1_fifo_wr_en_s;
	pe_fifo_rd_en_s    <= conv3x3_fifo_rd_en_s when i_convType = x"0002"
	                      else conv1x1_fifo_rd_en_s;
	pe_fifo_mode_s     <= conv3x3_fifo_mode_s when i_convType = x"0002"
	                      else conv1x1_fifo_mode_s;
	pe_cur_padding_s   <= conv3x3_cur_padding_s when i_convType = x"0002"
	                      else conv1x1_cur_padding_s;
	o_readaddr_data    <= conv3x3_readaddr_data when i_convType = x"0002"
	                      else conv1x1_readaddr_data;
	o_readaddr_kernels <= conv3x3_readaddr_kernels when i_convType = x"0002"
	                      else conv1x1_readaddr_kernels;
	o_mac_en           <= conv3x3_mac_en when i_convType = x"0002"
	                      else conv1x1_mac_en;
	o_mac_weight       <= conv3x3_mac_weight when i_convType = x"0002"
	                      else conv1x1_mac_weight;
	o_busy             <= conv3x3_busy_s when i_convType = x"0002"
	                      else conv1x1_busy_s;

	con1x1S1P0_inst : component conv1x1_S1_P0_top
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
			i_start            => conv1x1_start_s,
			o_busy             => conv1x1_busy_s,
			i_padding_mode     => i_padding_mode,
			-- Data and kernel bram signals			
			o_readaddr_data    => conv1x1_readaddr_data,
			o_readen_data      => open,
			i_buffer_line      => i_buffer_line,
			i_kernels          => i_kernels,
			o_readaddr_kernels => conv1x1_readaddr_kernels,
			o_readen_kernels   => open,
			-- mac array signals
			o_mac_en           => conv1x1_mac_en,
			o_mac_weight       => conv1x1_mac_weight,
			-- Processing element signals
			o_reg_en           => conv1x1_reg_en_s,
			o_pe_padding       => conv1x1_cur_padding_s,
			o_init_mode        => conv1x1_init_mode_s,
			o_init_data        => conv1x1_init_data_s,
			o_pixel            => conv1x1_pixel_s,
			o_fifo_wr_en       => conv1x1_fifo_wr_en_s,
			o_fifo_rd_en       => conv1x1_fifo_rd_en_s,
			o_fifo_mode        => conv1x1_fifo_mode_s
		);

	conv3x3S1P1_inst : component conv3x3_S1_P1_top
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
			-- ctrl signals
			i_start            => conv3x3_start_s,
			o_busy             => conv3x3_busy_s,
			i_padding_mode     => i_padding_mode, -- bit 0 of i_padding_mode specifies if zero-west padding enabled
			-- Data and kernel bram signals
			o_readaddr_data    => conv3x3_readaddr_data,
			o_readen_data      => open,
			i_buffer_line      => i_buffer_line,
			i_kernels          => i_kernels,
			o_readaddr_kernels => conv3x3_readaddr_kernels,
			o_readen_kernels   => open,
			-- mac array signals
			o_mac_en           => conv3x3_mac_en,
			o_mac_weight       => conv3x3_mac_weight,
			-- Processing element signals
			o_reg_en           => conv3x3_reg_en_s,
			o_pe_padding       => conv3x3_cur_padding_s,
			o_init_mode        => conv3x3_init_mode_s,
			o_init_data        => conv3x3_init_data_s,
			o_pixel            => conv3x3_pixel_s,
			o_fifo_wr_en       => conv3x3_fifo_wr_en_s,
			o_fifo_rd_en       => conv3x3_fifo_rd_en_s,
			o_fifo_mode        => conv3x3_fifo_mode_s
		);

	pe_inst : processing_element
		generic map(
			g_Pox      => g_Pox,
			g_Poy      => g_Poy,
			g_DataW    => g_DataW,
			g_WeightW  => g_WeightW,
			g_FifoSize => 15
		)
		port map(
			i_clk        => i_clk,
			i_reset      => i_reset,
			i_reg_en     => pe_reg_en_s,
			i_padding    => pe_cur_padding_s,
			i_init_mode  => pe_init_mode_s,
			i_fifo_mode  => pe_fifo_mode_s,
			i_init_data  => pe_init_data_s,
			i_pixel      => pe_pixel_s,
			i_fifo_wr_en => pe_fifo_wr_en_s,
			i_fifo_rd_en => pe_fifo_rd_en_s,
			o_mac_input  => mac_input_s
		);

	macdata : for jj in g_Pof downto 1 generate
		o_mac_input(jj * g_Poy * g_Pox * g_DataW - 1 downto (jj - 1) * g_Poy * g_Pox * g_DataW) <= mac_input_s;
	end generate macdata;

end rtl;
