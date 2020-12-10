library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity max_pool_array is
	generic(
		g_Pox       : integer;
		g_DataWidth : integer
	);
	port(
		i_clk    : in  std_logic;
		i_reset  : in  std_logic;
		i_enable : in  std_logic;
		i_clear  : in  std_logic;
		i_data   : in  std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
		o_result : out std_logic_vector(g_Pox*g_DataWidth-1 downto 0)
	);
end entity max_pool_array;

architecture RTL of max_pool_array is
	
	component max_pool
		generic(g_DataWidth : integer);
		port(
			i_clk    : in  std_logic;
			i_reset  : in  std_logic;
			i_enable : in  std_logic;
			i_clear  : in  std_logic;
			i_data   : in  std_logic_vector(g_DataWidth - 1 downto 0);
			o_result : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component max_pool;
	
begin
	
	genarr : for jj in g_Pox downto 1 generate
	begin
		mp : max_pool
			generic map(
				g_DataWidth => g_DataWidth
			)
			port map(
				i_clk => i_clk,
				i_reset => i_reset,
				i_enable => i_enable,
				i_clear => i_clear,
				i_data => i_data(jj*g_DataWidth-1 downto (jj-1)*g_DataWidth),
				o_result => o_result(jj*g_DataWidth-1 downto (jj-1)*g_DataWidth)
			);
	end generate genarr;

end architecture RTL;
