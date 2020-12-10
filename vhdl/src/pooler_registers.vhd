library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooler_registers is
	generic( 
		g_Pox : integer;
		g_DataWidth : integer
	);
	port(
		i_clk      : in  std_logic;
		i_reset    : in  std_logic;
		i_wrdata   : in  std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
		i_wrlineen : in  std_logic_vector(3 downto 0);
		o_line1    : out std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
		o_line2    : out std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
		o_line3    : out std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
		o_line4    : out std_logic_vector(g_Pox*g_DataWidth-1 downto 0)
		
	);
end entity pooler_registers;

architecture RTL of pooler_registers is
	
	component reg
		generic(
			N : integer := 8
		);
		port(
			i_clk   : in  std_logic;
			i_reset : in  std_logic;
			i_en    : in  std_logic;
			i_a     : in  std_logic_vector(N - 1 downto 0);
			o_b     : out std_logic_vector(N - 1 downto 0)
		);
	end component reg;
	
	TYPE reg_array IS ARRAY(4*g_Pox-1 downto 0) of std_logic_vector(g_DataWidth-1 downto 0);
	signal reg_outputs : reg_array;
	
begin
	

	g2 : for kk in 0 to 4*g_Pox-1 generate
		ff : reg
			generic map(
				N => g_DataWidth
			)
			port map(
				i_clk   => i_clk,
				i_reset => i_reset,
				i_en    => i_wrlineen(kk/g_Pox),
				i_a     => i_wrdata((g_Pox - (kk mod g_Pox))*g_DataWidth-1 downto (g_Pox - (kk mod g_Pox) - 1)*g_DataWidth),
				o_b     => reg_outputs(kk)
			);
	end generate g2;
	
	
	g3 : for kk in g_Pox downto 1 generate	
		o_line1(kk*g_DataWidth-1 downto (kk-1)*g_DataWidth) <= reg_outputs((g_Pox-kk)*2); 
		o_line2(kk*g_DataWidth-1 downto (kk-1)*g_DataWidth) <= reg_outputs((g_Pox-kk)*2 +1); 
		o_line3(kk*g_DataWidth-1 downto (kk-1)*g_DataWidth) <= reg_outputs((2*g_Pox-kk)*2); 
		o_line4(kk*g_DataWidth-1 downto (kk-1)*g_DataWidth) <= reg_outputs((2*g_Pox-kk)*2 +1); 
	end generate g3;
					

	

end architecture RTL;
