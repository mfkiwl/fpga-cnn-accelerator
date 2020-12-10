library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg is
	generic(N : integer := 8);
	port(
		i_clk   : in  std_logic;
		i_reset : in  std_logic;
		i_en    : in  std_logic;
		i_a     : in  std_logic_vector(N - 1 downto 0);
		o_b     : out std_logic_vector(N - 1 downto 0));
end reg;

architecture behav of reg is
begin
	process(i_clk)
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				o_b <= (others => '0');
			elsif i_en = '1' then
				o_b <= i_a;
			end if;
		end if;
	end process;
end behav;
