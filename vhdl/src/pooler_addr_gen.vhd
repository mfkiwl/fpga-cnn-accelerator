library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooler_addr_gen is
	generic(
		g_Pox                 : in integer := 3;
		g_Poy                 : in integer := 3;
		g_Pof                 : in integer := 3;
		g_NumBuffers          : in integer := 3;
		g_DataW               : in integer := 16;
		g_OutputBramAddrWidth : in integer := 16
	);
	port(
		i_clk         : in  std_logic;
		i_reset       : in  std_logic;
		i_incr_rd     : in  std_logic;
		o_valid_rd    : out std_logic;
		i_incr_wr     : in  std_logic;
		i_xDim        : in  std_logic_vector(15 downto 0);
		i_yDim        : in  std_logic_vector(15 downto 0);
		i_addroffset  : in  std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
		o_line_wraddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
		o_line1_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
		o_line2_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
		o_line3_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
		o_line4_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0)
	);
end entity pooler_addr_gen;

architecture RTL of pooler_addr_gen is

	constant Pof_per_Obuf : integer := g_Pof / g_NumBuffers;

	-- Count columns
	signal reg_col1     : integer;
	signal reg_col2     : integer;
	signal reg_col1_ctr : integer;
	signal reg_col2_ctr : integer;

	-- Mark end of column
	signal end_of_col1 : std_logic;
	signal end_of_col2 : std_logic;

	-- Count blocks
	signal reg_block1     : integer;
	signal reg_block2     : integer;
	signal reg_block1_ctr : integer;
	signal reg_block2_ctr : integer;

	-- Count wraddr
	signal reg_wraddr     : integer;
	signal reg_wraddr_ctr : integer;

begin

	end_of_col1 <= '0' when reg_col1_ctr < to_integer(unsigned(i_yDim)) - 2 else '1';
	end_of_col2 <= '0' when reg_col2_ctr < to_integer(unsigned(i_yDim)) - 2 else '1';

	o_valid_rd <= '0' when reg_col2 * g_Pox > to_integer(unsigned(i_xDim)) else '1';

	wraddr : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_wraddr     <= to_integer(unsigned(i_addroffset)) * (Pof_per_Obuf - 1) * g_Poy;
				reg_wraddr_ctr <= 0;
			else
				if i_incr_wr = '1' then
					if reg_wraddr_ctr + 1 < g_Poy then
						reg_wraddr_ctr <= reg_wraddr_ctr + 1;
						reg_wraddr     <= reg_wraddr + 1;
					else
						reg_wraddr     <= reg_wraddr + (Pof_per_Obuf - 1) * g_Poy + 1;
						reg_wraddr_ctr <= 0;
					end if;
				end if;
			end if;
		end if;
	end process wraddr;

	col1 : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_col1     <= 0;
				reg_col1_ctr <= 0;
			else
				if i_incr_rd = '1' then
					if reg_col1_ctr + 2 < to_integer(unsigned(i_yDim)) then
						reg_col1_ctr <= reg_col1_ctr + 2;
						reg_col1     <= reg_col1;
					else
						reg_col1     <= reg_col1 + 2;
						reg_col1_ctr <= 0;
					end if;
				end if;
			end if;
		end if;
	end process col1;

	col2 : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_col2     <= 1;
				reg_col2_ctr <= 0;
			else
				if i_incr_rd = '1' then
					if reg_col2_ctr + 2 < to_integer(unsigned(i_yDim)) then
						reg_col2_ctr <= reg_col2_ctr + 2;
						reg_col2     <= reg_col2;
					else
						reg_col2     <= reg_col2 + 2;
						reg_col2_ctr <= 0;
					end if;
				end if;
			end if;
		end if;
	end process col2;

	block1 : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_block1     <= to_integer(unsigned(i_addroffset));
				reg_block1_ctr <= 0;
			else
				if i_incr_rd = '1' then
					if end_of_col1 = '1' then
						reg_block1     <= to_integer(unsigned(i_addroffset));
						reg_block1_ctr <= 0;
					elsif reg_block1_ctr + 2 < g_Poy then
						reg_block1_ctr <= reg_block1_ctr + 2;
						reg_block1     <= reg_block1;
					else
						reg_block1     <= reg_block1 + Pof_per_Obuf;
						reg_block1_ctr <= reg_block1_ctr + 2 - g_Poy;
					end if;
				end if;
			end if;
		end if;
	end process block1;

	block2 : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_block2     <= to_integer(unsigned(i_addroffset));
				reg_block2_ctr <= 1;
			else
				if i_incr_rd = '1' then
					if end_of_col2 = '1' then
						reg_block2     <= to_integer(unsigned(i_addroffset));
						reg_block2_ctr <= 1;
					elsif reg_block2_ctr + 2 < g_Poy then
						reg_block2_ctr <= reg_block2_ctr + 2;
						reg_block2     <= reg_block2;
					else
						reg_block2     <= reg_block2 + Pof_per_Obuf;
						reg_block2_ctr <= reg_block2_ctr + 2 - g_Poy;
					end if;
				end if;
			end if;
		end if;
	end process block2;

	o_line1_raddr <= std_logic_vector(to_unsigned(reg_col1 * to_integer(unsigned(i_yDim)) * Pof_per_Obuf + reg_block1 * g_Poy + reg_block1_ctr, g_OutputBramAddrWidth));
	o_line2_raddr <= std_logic_vector(to_unsigned(reg_col2 * to_integer(unsigned(i_yDim)) * Pof_per_Obuf + reg_block1 * g_Poy + reg_block1_ctr, g_OutputBramAddrWidth));
	o_line3_raddr <= std_logic_vector(to_unsigned(reg_col1 * to_integer(unsigned(i_yDim)) * Pof_per_Obuf + reg_block2 * g_Poy + reg_block2_ctr, g_OutputBramAddrWidth));
	o_line4_raddr <= std_logic_vector(to_unsigned(reg_col2 * to_integer(unsigned(i_yDim)) * Pof_per_Obuf + reg_block2 * g_Poy + reg_block2_ctr, g_OutputBramAddrWidth));

	o_line_wraddr <= std_logic_vector(to_unsigned(reg_wraddr, g_OutputBramAddrWidth));

end architecture RTL;
