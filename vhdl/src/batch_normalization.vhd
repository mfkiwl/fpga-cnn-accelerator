library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity batch_normalization is
	generic(
		g_Pox   : integer;
		g_DataW : integer
	);
	port(
		i_en    : in  std_logic;
		i_alpha : in  std_logic_vector(15 downto 0);
		i_beta  : in  std_logic_vector(15 downto 0);
		i_data  : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
		o_data  : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
	);
end entity batch_normalization;

architecture RTL of batch_normalization is
begin

	ReLUgen : for jj in g_Pox downto 1 generate
	
		o_data(jj * g_DataW - 1 downto (jj - 1) * g_DataW) <= std_logic_vector(to_signed(to_integer(signed(i_alpha)*signed(i_data(jj * g_DataW - 1 downto (jj - 1) * g_DataW)) + signed(i_beta)), g_DataW)) when i_en = '1' 
															  else i_data(jj * g_DataW - 1 downto (jj - 1) * g_DataW);
	end generate ReLUgen;

end architecture RTL;
