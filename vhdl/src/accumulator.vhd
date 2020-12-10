library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity accumulator is
	generic(g_DataWidth : integer := 16);
	port(
		clk    : in  std_logic;
		reset  : in  std_logic;
		enable : in  std_logic;
		din    : in  std_logic_vector(g_DataWidth - 1 downto 0);
		q      : out std_logic_vector(g_DataWidth - 1 downto 0)
	);
end accumulator;

architecture bhv of accumulator is
	signal tmp: std_logic_vector(g_DataWidth - 1 downto 0);
begin
	process (clk)
	begin
		if rising_edge(clk) then
			if (reset='1') then
				tmp <= (others => '0');
			elsif (enable = '1') then
				tmp <= tmp + din;
			end if;
		end if;
	end process;
	q <= tmp;
end bhv;
