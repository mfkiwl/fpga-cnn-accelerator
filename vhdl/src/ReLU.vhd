library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ReLU is
	generic(
		g_Pox : integer;
		g_DataW : integer
	);
	port(
		i_en : in std_logic;
		i_data : in std_logic_vector(g_Pox*g_DataW-1 downto 0);
		o_data : out std_logic_vector(g_Pox*g_DataW-1 downto 0)
	);
end entity ReLU;

architecture RTL of ReLU is
begin
	
	ReLUgen : for jj in g_Pox downto 1 generate
		o_data(jj*g_DataW-1 downto (jj-1)*g_DataW) <= i_data(jj*g_DataW-1 downto (jj-1)*g_DataW) when (i_en = '1' and signed(i_data(jj*g_DataW-1 downto (jj-1)*g_DataW)) > 0) or i_en = '0' else (others => '0');
	end generate ReLUgen;

end architecture RTL;
