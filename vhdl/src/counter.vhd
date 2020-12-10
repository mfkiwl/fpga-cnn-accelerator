library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity up_counter is
	generic(
		g_DataWidth : in integer := 16
	);
	port(
		clk    : in  std_logic;         -- Input clock
		reset  : in  std_logic;         -- Input reset
		enable : in  std_logic;         -- Enable counting
		cout   : out std_logic_vector(g_DataWidth - 1 downto 0) -- Output of the counter
	);
end entity;

architecture rtl of up_counter is
	signal count : std_logic_vector(g_DataWidth - 1 downto 0);
begin
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				count <= (others => '0');
			elsif (enable = '1') then
				count <= count + 1;
			end if;
		end if;
	end process;
	cout <= count;
end architecture;
