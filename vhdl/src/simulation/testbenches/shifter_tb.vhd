library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter_tb is
end entity shifter_tb;

architecture RTL of shifter_tb is
	
	constant period : time := 20 ns;
	
	constant g_Depth : integer := 4;
	constant g_DataW : integer := 16;
	
	component shifter
		generic(
			g_Depth : integer;
			g_DataW : integer
		);
		port(
			i_clk      : in  std_logic;
			i_reset    : in  std_logic;
			i_init     : in  std_logic;
			i_initdata : in  std_logic_vector(g_Depth * g_DataW - 1 downto 0);
			i_shift    : in  std_logic;
			o_output   : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component shifter;
	
	signal clk_s : std_logic;
	signal reset_s : std_logic;
	signal init_s : std_logic;
	signal initdata_s : std_logic_vector(g_Depth * g_DataW - 1 downto 0);
	signal shift_s : std_logic;
	signal output_s : std_logic_vector(g_DataW - 1 downto 0);
	
begin

	sft : component shifter
		generic map(
			g_Depth => 4,
			g_DataW => 16
		)
		port map(
			i_clk      => clk_s,
			i_reset    => reset_s,
			i_init     => init_s,
			i_initdata => initdata_s,
			i_shift    => shift_s,
			o_output   => output_s
		);
		
		
	
	clock_driver : process
	begin
		clk_s <= '0';
		wait for period / 2;
		clk_s <= '1';
		wait for period / 2;
	end process clock_driver;
	
	test : process is
	begin
		
		reset_s <= '1';
		wait for period;
		
		reset_s <= '0';
		init_s  <= '1';
		initdata_s <= x"0001000200030004";
		wait for period;
		
		init_s <= '0';
		wait for period;
		
		shift_s <= '1';
		wait for 10*period;
		
		wait;
	end process test;
	
	

end architecture RTL;
