library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parallel2serial is
	generic(
		g_ParallelWidth       : integer;
		g_SerialWidth         : integer;
		g_OutputBramAddrWidth : integer
	);
	port(
		i_clk   : in  std_logic;
		i_reset : in  std_logic;
		i_start : in  std_logic;
		o_busy  : out std_logic;
		i_data  : in  std_logic_vector(g_ParallelWidth - 1 downto 0);
		o_data  : out std_logic_vector(g_SerialWidth - 1 downto 0);
		o_wren  : out std_logic;
		o_waddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0)
	);
end parallel2serial;

architecture rtl of parallel2serial is
	signal r_ready  : std_logic;
	signal r_count  : integer range 0 to g_ParallelWidth;
	signal r_wraddr : integer;
begin

	o_busy  <= not r_ready;
	o_data  <= i_data(r_count - 1 downto r_count - g_SerialWidth) when r_count > 0 else (others => '0');
	o_waddr <= std_logic_vector(to_unsigned(r_wraddr, g_OutputBramAddrWidth));

	p_paralle2serial : process(i_clk)
	begin
		if (rising_edge(i_clk)) then
			if (i_reset = '1') then
				r_count  <= 0;
				r_ready  <= '1';
				o_wren   <= '0';
				r_wraddr <= 0;
			else
				if (i_start = '1') then
					r_count  <= g_ParallelWidth;
					r_ready  <= '0';
					o_wren   <= '1';
					r_wraddr <= r_wraddr;
				elsif (r_count > g_SerialWidth) then
					r_count  <= r_count - g_SerialWidth;
					r_ready  <= '0';
					o_wren   <= '1';
					r_wraddr <= r_wraddr + 1;
				elsif (r_count = g_SerialWidth) then
					r_count  <= r_count - g_SerialWidth;
					r_ready  <= '1';
					o_wren   <= '1';
					r_wraddr <= r_wraddr + 1;
				else
					r_count  <= 0;
					r_ready  <= '1';
					o_wren   <= '0';
					r_wraddr <= r_wraddr;
				end if;
			end if;
		end if;
	end process p_paralle2serial;
end rtl;
