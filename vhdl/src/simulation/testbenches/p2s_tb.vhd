library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parallel2serial_tb is
end entity;

architecture simulate OF parallel2serial_tb is
----------------------------------------------------
--- The parent design, MAC, is instantiated
--- in this testbench. Note the component
--- declaration and the instantiation.
----------------------------------------------------

constant clock_period 	: time := 20 ns;

constant Xparallelism 	: integer := 5;
constant Yparallelism 	: integer := 5;
constant Fparallelism 	: integer := 1;
constant DataWidth 			: integer := 16;

component parallel2serial is
	generic(
	  g_ParallelWidth	: integer;
	  g_SerialWidth		: integer  
	);
	port (
	  i_clk      : in  std_logic;
	  i_reset    : in  std_logic;
	  i_start		 : in  std_logic;
	  o_busy 	 : out std_logic;
	  i_data     : in  std_logic_vector(g_ParallelWidth-1 downto 0);
	  o_data     : out std_logic_vector(g_SerialWidth-1 downto 0);
	  o_error    : out std_logic
	);
end component;


signal clk_s      : std_logic;
signal reset_s    : std_logic;
signal start_s    : std_logic;
signal ready_s    : std_logic;
signal data_par_s : std_logic_vector(Xparallelism*Yparallelism*DataWidth-1 downto 0);
signal data_ser_s : std_logic_vector(Xparallelism*DataWidth-1 downto 0);
signal error_s    : std_logic;

begin

uut: parallel2serial
	generic map(
	  g_ParallelWidth	=> Xparallelism*Yparallelism*DataWidth,
	  g_SerialWidth		=> Xparallelism*DataWidth
	)
	port map(
	  i_clk     => clk_s,
	  i_reset   => reset_s,
	  i_start		=> start_s,
	  o_busy 	=> ready_s,
	  i_data    => data_par_s,
	  o_data    => data_ser_s,
	  o_error   => error_s
	);


clock_process : process
begin
	clk_s <= '0';
	wait for clock_period/2;
	clk_s <= '1';
	wait for clock_period/2;
end process;



stimulus: process
begin
-----------------------------------------------------
---Provide stimulus in this section. (not shown here) 
-----------------------------------------------------
	wait for clock_period;
	reset_s <= '1';
	data_par_s <= x"FFB9FFAAFFABFFB7FFC0FFB7FFAAFFA7FFAEFFBCFFB2FFABFFA5FFA5FFBEFFAFFFB0FFA6FFA3FFC3FFAFFFB6FFACFFAAFFB5";

	wait for clock_period;
	reset_s <= '0';

	wait for 4*clock_period;
	start_s <= '1';

	wait for clock_period;
	start_s <= '0';

	wait for clock_period;
	

	wait until ready_s = '1';
	wait;	
end process; -- stimulus

end simulate;
