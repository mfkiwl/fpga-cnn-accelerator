library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processing_element is
	generic(
		g_Pox      : integer := 3;
		g_Poy      : integer := 3;
		g_DataW    : integer := 16;
		g_WeightW  : integer := 16;
		g_FifoSize : integer := 9
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
end processing_element;

architecture rtl of processing_element is

	component reg_array
		generic(
			g_Pox   : integer;
			g_DataW : integer
		);
		port(
			i_clk       : in  std_logic;
			i_reset     : in  std_logic;
			i_en        : in  std_logic;
			i_init_mode : in  std_logic;
			i_padding   : in  std_logic_vector(2 downto 0);
			i_init_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			i_pixel     : in  std_logic_vector(g_DataW - 1 downto 0);
			i_fifo_mode : in  std_logic;
			i_fifo_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			o_data      : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
		);
	end component reg_array;

	component fifo
		generic(
			g_WIDTH : natural := 16;
			g_DEPTH : integer := 9
		);
		port(
			i_rst     : in  std_logic;
			i_clk     : in  std_logic;
			-- FIFO Write Interface
			i_wr_en   : in  std_logic;
			i_wr_data : in  std_logic_vector(g_WIDTH - 1 downto 0);
			o_full    : out std_logic;
			-- FIFO Read Interface
			i_rd_en   : in  std_logic;
			o_rd_data : out std_logic_vector(g_WIDTH - 1 downto 0);
			o_empty   : out std_logic
		);
	end component fifo;

	--	signal output_data : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal reg_data : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);

	signal fifo_input_bus  : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal fifo_output_bus : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);

begin

	fifo_input_bus <= std_logic_vector(shift_left(signed(reg_data), g_Pox * g_DataW));
	o_mac_input    <= reg_data;

	g1 : for jj in g_Poy downto 1 generate
		-- Instantiate registers.
		regs : reg_array
			generic map(
				g_Pox   => g_Pox,
				g_DataW => g_DataW
			)
			port map(
				i_clk       => i_clk,
				i_reset     => i_reset,
				i_en        => i_reg_en(jj - 1),
				i_init_mode => i_init_mode(jj - 1),
				i_padding   => i_padding,
				i_init_data => i_init_data(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				i_pixel     => i_pixel(jj * g_DataW - 1 downto (jj - 1) * g_DataW),
				i_fifo_mode => i_fifo_mode(jj - 1),
				i_fifo_data => fifo_output_bus(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				o_data      => reg_data(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW)
			);
	end generate g1;

	ifPoy : if g_Poy > 1 generate
		g2 : for kk in g_Poy downto 2 generate
			fifos : fifo
				generic map(
					g_WIDTH => g_Pox * g_DataW,
					g_DEPTH => g_FifoSize
				)
				port map(
					i_rst     => i_reset,
					i_clk     => i_clk,
					-- FIFO Write Interface
					i_wr_en   => i_fifo_wr_en(kk - 1),
					i_wr_data => fifo_input_bus(kk * g_Pox * g_DataW - 1 downto (kk - 1) * g_Pox * g_DataW),
					o_full    => open,
					-- FIFO Read Interface
					i_rd_en   => i_fifo_rd_en(kk - 1),
					o_rd_data => fifo_output_bus(kk * g_Pox * g_DataW - 1 downto (kk - 1) * g_Pox * g_DataW),
					o_empty   => open
				);
		end generate g2;
	end generate;
end rtl;
