library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity max_pool is
	generic( 
		g_DataWidth : integer
	);
	port(
		i_clk    : in  std_logic;
		i_reset  : in  std_logic;
		i_enable : in  std_logic;
		i_clear	 : in std_logic;
		i_data   : in std_logic_vector(g_DataWidth-1 downto 0);
		o_result  : out std_logic_vector(g_DataWidth-1 downto 0)
	);
end entity max_pool;

architecture RTL of max_pool is

	signal poolreg : std_logic_vector(g_DataWidth-1 downto 0);

begin
	
	o_result <= poolreg;

	pooling : process (i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				poolreg <= (others => '0');
			else
				if i_enable = '1' then
					if i_clear = '1' or signed(i_data) > signed(poolreg) then
						poolreg <= i_data;
					else
						poolreg <= poolreg;
					end if;
				end if;
			end if;
		end if;
	end process pooling;
	
		
end architecture RTL;
