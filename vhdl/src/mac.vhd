library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac is
	generic( 
		g_DataW 	: in integer := 16;
		g_WeightW : in integer := 16
	);
	port (
		i_clk				: in  std_logic;
		i_reset			: in  std_logic;
		i_en				: in  std_logic;
		i_data			: in  std_logic_vector(g_DataW-1 downto 0);
		i_weight		: in  std_logic_vector(g_WeightW-1 downto 0);		
		o_accum_out	: out std_logic_vector(g_DataW-1 downto 0)
	);
	
end entity;

architecture rtl of mac is

	-- Declare registers for intermediate values
	signal adder_out : signed(g_DataW+g_WeightW-1 downto 0);

begin
	
	process (i_clk)
	begin
		if (rising_edge(i_clk)) then
			if (i_reset = '1') then
				adder_out <= (others => '0');			
			elsif i_en='1' then		
				-- Store accumulation result in a register
				adder_out <= signed(adder_out +  signed(i_data)*signed(i_weight));
			end if;
		end if;
	end process;
	
	-- Output accumulation result
	o_accum_out <= std_logic_vector(adder_out(g_DataW-1 downto 0));
	
end rtl;