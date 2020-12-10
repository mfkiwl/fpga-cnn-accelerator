library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_tb is
end entity;

architecture simulate OF mac_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------

	constant clock_period : time := 20 ns;

	component mac
		generic(
			g_DataW   : in integer := 16;
			g_WeightW : in integer := 16
		);
		port(
			i_clk       : in  std_logic;
			i_reset     : in  std_logic;
			i_en        : in  std_logic;
			i_data      : in  std_logic_vector(g_DataW - 1 downto 0);
			i_weight    : in  std_logic_vector(g_WeightW - 1 downto 0);
			o_accum_out : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component;

	signal a_s         : std_logic_vector(15 downto 0);
	signal b_s         : std_logic_vector(15 downto 0);
	signal clk_s       : std_logic;
	signal en_s        : std_logic;
	signal reset_s     : std_logic;
	signal accum_out_s : std_logic_vector(15 downto 0);

begin

	uut : mac
		generic map(
			g_DataW   => 16,
			g_WeightW => 16
		)
		port map(
			i_clk       => clk_s,
			i_reset     => reset_s,
			i_en        => en_s,
			i_data      => a_s,
			i_weight    => b_s,
			o_accum_out => accum_out_s
		);

	clock_process : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process;

	stimulus : process
	begin
		-----------------------------------------------------
		---Provide stimulus in this section. (not shown here) 
		-----------------------------------------------------
		wait for clock_period;
		reset_s <= '1';

		wait for clock_period;
		a_s <= std_logic_vector(to_unsigned(2, 16));
		b_s <= std_logic_vector(to_unsigned(2, 16));

		wait for clock_period;
		reset_s <= '0';
		en_s    <= '1';

		wait for clock_period;
		en_s <= '0';

		wait for 5 * clock_period;
		en_s <= '1';
		a_s  <= std_logic_vector(to_unsigned(3, 16));
		b_s  <= std_logic_vector(to_unsigned(4, 16));

		wait for clock_period;
		a_s <= std_logic_vector(to_unsigned(7, 16));
		b_s <= std_logic_vector(to_unsigned(2, 16));

		wait for 5 * clock_period;

		en_s <= '0';

		wait for 5 * clock_period;
		reset_s <= '1';

		wait for clock_period;
		reset_s <= '0';

		wait;
	end process;                        -- stimulus

end simulate;
