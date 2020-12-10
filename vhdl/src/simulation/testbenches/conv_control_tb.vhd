library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_control_tb is
end entity;

architecture simulate OF conv_control_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------

	component conv_control
		port(
			i_clk        : in  std_logic;
			i_reset      : in  std_logic;
			i_start      : in  std_logic;
			o_ready      : out std_logic;
			i_conv_busy  : in  std_logic;
			o_conv_start : out std_logic;
			o_conv_reset : out std_logic;
			i_p2s_busy   : in  std_logic;
			o_p2s_start  : out std_logic;
			i_iterX      : in  std_logic_vector(15 downto 0);
			i_iterY      : in  std_logic_vector(15 downto 0);
			o_en_padding : out std_logic;
			o_dread_base : out std_logic_vector(15 downto 0)
		);
	end component conv_control;

	constant clock_period : time := 20 ns;

	signal clk        : std_logic;
	signal reset      : std_logic;
	signal start      : std_logic;
	signal ready      : std_logic;
	signal conv_busy  : std_logic;
	signal conv_start : std_logic;
	signal iterX      : std_logic_vector(15 downto 0);
	signal iterY      : std_logic_vector(15 downto 0);
	signal en_padding : std_logic;
	signal dread_base : std_logic_vector(15 downto 0);
	signal p2s_busy   : std_logic;
	signal conv_reset : std_logic;
	signal p2s_start  : std_logic;

begin

	uut : conv_control
		port map(
			i_clk => clk,
			i_reset => reset,
			i_start => start,
			o_ready => ready,
			i_conv_busy => conv_busy,
			o_conv_start => conv_start,
			o_conv_reset => conv_reset,
			i_p2s_busy => p2s_busy,
			o_p2s_start => p2s_start,
			i_iterX => iterX,
			i_iterY => iterY,
			o_en_padding => en_padding,
			o_dread_base => dread_base
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
		-----------------------------------------------------
		wait for clock_period;
		reset <= '1';
		iterX <= std_logic_vector(to_unsigned(8, 16));
		iterY <= std_logic_vector(to_unsigned(6, 16));
		p2s_busy <= '0';
		conv_busy <= '0';
		wait for clock_period;
		reset <= '0';
		start <= '1';

		wait for clock_period;
		start <= '0';
		conv_busy <= '1';
		
		for jj in 1 to 36 loop
			wait for 10 * clock_period;
			conv_busy <= '0';
			p2s_busy <= '1';
			wait for 25 * clock_period;
			p2s_busy <= '0';
			
			wait for 2 * clock_period;
			conv_busy <= '1';
		end loop;

		wait for clock_period;
		reset <= '1';

		wait for clock_period;
		reset <= '0';

		wait;
	end process;                        -- stimulus

end simulate;
