library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity data_grabber_tb is
end entity;

architecture simulate OF data_grabber_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------

	constant clock_period : time    := 20 ns;
	constant Xparallelism : integer := 4;
	constant Yparallelism : integer := 4;
	constant DataWidth    : integer := 16;

	component ram_infer
		generic(
			WordWidth    : integer;
			RamDepth     : integer;
			InitFileName : string;
			DumpFileName : string
		);
		port(
			clock         : IN  std_logic;
			data          : IN  std_logic_vector(WordWidth - 1 DOWNTO 0);
			write_address : IN  integer;
			read_address  : IN  integer;
			we            : IN  std_logic;
			q             : OUT std_logic_vector(WordWidth - 1 DOWNTO 0);
			dump_size     : IN  integer;
			dump_flag     : IN  std_logic
		);
	end component ram_infer;

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
			o_valid            : out std_logic;
			o_col              : out std_logic_vector(7 downto 0);
			o_row              : out std_logic_vector(7 downto 0);
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

	signal clk         : std_logic;
	signal reset       : std_logic;
	signal start       : std_logic;
	signal ready       : std_logic;
	signal buffer_line : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal readaddr    : std_logic_vector(15 downto 0);
	signal readen      : std_logic;

	signal busy               : std_logic;
	signal init_line          : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal pixels             : std_logic_vector(Yparallelism * DataWidth - 1 downto 0);
	signal pixel              : std_logic_vector(DataWidth - 1 downto 0);
	signal dbram_wr_data_s    : std_logic_vector(Xparallelism * Yparallelism * DataWidth - 1 DOWNTO 0);
	signal dbram_wr_address_s : integer;
	signal dbram_wr_en_s      : std_logic;
	signal buffer_line_s      : std_logic_vector(Xparallelism * Yparallelism * DataWidth - 1 DOWNTO 0);
	signal dump_results_s     : std_logic;
	signal valid_s            : std_logic;
	signal col_s              : std_logic_vector(7 downto 0);
	signal row_s              : std_logic_vector(7 downto 0);

	signal init_line_rd   : std_logic;
	signal init_pixels_rd : std_logic;
	signal pixels_rd      : std_logic;
	signal pixel_rd       : std_logic;

	signal init_pixels_s    : std_logic_vector(Xparallelism * DataWidth - 1 downto 0);
	signal init_line_data   : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal init_pixels_data : std_logic_vector(Xparallelism * DataWidth - 1 downto 0);
	signal pixels_data      : std_logic_vector(Yparallelism * DataWidth - 1 downto 0);
	signal pixel_data       : std_logic_vector(DataWidth - 1 downto 0);

begin

	uut : component conv7x7_S2_P3_data_grabber
		generic map(
			g_Pox               => Xparallelism,
			g_Poy               => Yparallelism,
			g_DataW             => DataWidth,
			g_DataBramAddrWidth => 16
		)
		port map(
			i_clk              => clk,
			i_reset            => reset,
			i_start            => start,
			o_busy             => busy,
			i_buffer_line      => buffer_line,
			o_readaddr         => readaddr,
			o_readen           => readen,
			o_valid            => valid_s,
			o_col              => col_s,
			o_row              => row_s,
			i_init_line_rd     => init_line_rd,
			o_init_line_data   => init_line_data,
			i_init_pixels_rd   => init_pixels_rd,
			o_init_pixels_data => init_pixels_data,
			i_pixels_rd        => pixels_rd,
			o_pixels_data      => pixels_data,
			i_pixel_rd         => pixel_rd,
			o_pixel_data       => pixel_data
		);

	clock_process : process
	begin
		clk <= '0';
		wait for clock_period / 2;
		clk <= '1';
		wait for clock_period / 2;
	end process;

	stimulus : process
	begin
		-----------------------------------------------------
		---Provide stimulus in this section. (not shown here) 
		----------------------------------------------------

		wait for clock_period;
		reset          <= '1';
		init_line_rd   <= '0';
		init_pixels_rd <= '0';
		pixels_rd      <= '0';
		pixel_rd       <= '0';

		wait for clock_period;
		reset <= '0';
		start <= '1';

		wait for clock_period;
		start <= '0';

		wait until busy = '0';
		wait for 10 ns;
		
		init_line_rd <= '0';
		wait for clock_period;
		
		init_line_rd <= '0';
		pixels_rd <= '1';
		wait for 6*clock_period;
		
		-- End of macroblock 1
		-- Start macroblock 2
		init_line_rd <= '1';
		pixels_rd <= '0';
		wait for clock_period;
		
		init_line_rd <= '0';
		pixels_rd <= '1';
		wait for 6*clock_period;	
		
		init_line_rd <= '0';
		pixels_rd <= '0';		
		
		
		wait;
	end process;                        -- stimulus

	bramdata : ram_infer
		generic map(
			WordWidth    => Xparallelism * Yparallelism * DataWidth,
			RamDepth     => 256,
			--			InitFileName => "/home/symm3try/neuralnet_accel/MPE_Accel/vhdl/src/simulation/input/bram.txt",
			InitFileName => "C:\Users\sander\neuralnet_accel\MPE_Accel\vhdl\src\simulation\input\bram.txt",
			DumpFileName => "None"
		)
		port map(
			clock         => clk,
			data          => dbram_wr_data_s,
			write_address => dbram_wr_address_s,
			read_address  => to_integer(unsigned(readaddr)),
			we            => dbram_wr_en_s,
			q             => buffer_line,
			dump_size     => 0,
			dump_flag     => dump_results_s
		);

end simulate;

