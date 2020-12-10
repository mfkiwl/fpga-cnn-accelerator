library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter is
	generic(
		g_Depth	: integer;
		g_DataW : integer
	);
	port(
		i_clk      : in std_logic;
		i_reset    : in std_logic;
		i_init	   : in std_logic;
		i_initdata : in std_logic_vector(g_Depth*g_DataW-1 downto 0);
		i_shift	   : in std_logic;
		o_output   : out std_logic_vector(g_DataW-1 downto 0)
	);
end entity shifter;

architecture RTL of shifter is
	signal shifter_reg : std_logic_vector(g_DataW*g_Depth-1 downto 0);
begin

	sft : process (i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				shifter_reg <= (others => '0');				
			else
				if i_init = '1' then
					shifter_reg <= i_initdata;
				elsif i_shift = '1' then
					shifter_reg(g_Depth*g_DataW-1 downto g_DataW) <= shifter_reg((g_Depth-1)*g_DataW-1 downto 0);
				else
					shifter_reg <= shifter_reg;
				end if;
			end if;
		end if;
	end process sft;
	
	o_output <= shifter_reg(g_Depth*g_DataW-1 downto (g_Depth-1)*g_DataW);

end architecture RTL;
