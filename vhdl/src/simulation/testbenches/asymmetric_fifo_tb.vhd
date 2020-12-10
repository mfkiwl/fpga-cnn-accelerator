library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity assymetric_fifo_tb is
end assymetric_fifo_tb;

architecture behave of assymetric_fifo_tb is

	constant clock_period : time    := 10 ns;
	constant g_NumInputs  : integer := 4;
	constant g_DataWidth  : integer := 16;
	constant g_Depth      : integer := 9;

	component assymetric_fifo
		generic(
			g_NumInputs : integer;
			g_DataWidth : integer;
			g_Depth     : integer
		);
		port(
			i_clk     : in  std_logic;
			i_reset   : in  std_logic;
			i_wr_en   : in  std_logic;
			i_wr_data : in  std_logic_vector(g_NumInputs * g_DataWidth - 1 downto 0);
			o_full    : out std_logic;
			i_rd_en   : in  std_logic;
			o_rd_data : out std_logic_vector(g_DataWidth - 1 downto 0);
			o_empty   : out std_logic
		);
	end component assymetric_fifo;

	signal clk_s   : std_logic;
	signal reset_s : std_logic;

	signal wr_en_s   : std_logic;
	signal wr_data_s : std_logic_vector(g_NumInputs * g_DataWidth - 1 downto 0);
	signal full_s    : std_logic;
	signal rd_en_s   : std_logic;
	signal rd_data_s : std_logic_vector(g_DataWidth - 1 downto 0);
	signal empty_s   : std_logic;

begin

	test_inst : component assymetric_fifo
		generic map(
			g_NumInputs => g_NumInputs,
			g_DataWidth => g_DataWidth,
			g_Depth     => g_Depth
		)
		port map(
			i_clk     => clk_s,
			i_reset   => reset_s,
			i_wr_en   => wr_en_s,
			i_wr_data => wr_data_s,
			o_full    => full_s,
			i_rd_en   => rd_en_s,
			o_rd_data => rd_data_s,
			o_empty   => empty_s
		);

	clock_driver : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process clock_driver;

	sim : process is
	begin
		reset_s <= '1';
		rd_en_s <= '0';
		wr_en_s <= '0';
		wait for clock_period;
		
		reset_s <= '0';
		wait for clock_period;
		
		wr_en_s <= '1';
		wr_data_s <= x"0001000200030004";
		wait for clock_period;
		
		wr_data_s <= x"0011001200130014";
		wait for clock_period;
		
		wr_data_s <= x"0021002200230024";
		wait for clock_period;
		
		wr_en_s <= '0';
		wait for clock_period;
		
		rd_en_s <= '1';
		wait until empty_s = '1';
		
		rd_en_s <= '0';
	end process sim;

end behave;
