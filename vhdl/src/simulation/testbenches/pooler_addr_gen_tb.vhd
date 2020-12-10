library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooler_addr_gen_tb is
end entity pooler_addr_gen_tb;

architecture RTL of pooler_addr_gen_tb is
	
	constant clock_period : time := 20 ns;
	
	constant g_Pox        : integer := 3;
	constant g_Poy        : integer := 3;
	constant g_Pof        : integer := 6;
	constant g_NumBuffers : integer := 3;
	constant g_DataW      : integer := 16;
	
	
	component pooler_addr_gen
		generic(
			g_Pox        : in integer;
			g_Poy        : in integer;
			g_Pof        : in integer;
			g_NumBuffers : in integer;
			g_DataW      : in integer
		);
		port(
			i_clk         : in  std_logic;
			i_reset       : in  std_logic;
			i_incr_rd     : in  std_logic;
			o_valid_rd    : out std_logic;
			i_incr_wr     : in  std_logic;
			i_xDim        : in  std_logic_vector(15 downto 0);
			i_yDim        : in  std_logic_vector(15 downto 0);
			i_outputid    : in  std_logic_vector(15 downto 0);
			o_line_wraddr : out std_logic_vector(15 downto 0);
			o_line1_raddr : out std_logic_vector(15 downto 0);
			o_line2_raddr : out std_logic_vector(15 downto 0);
			o_line3_raddr : out std_logic_vector(15 downto 0);
			o_line4_raddr : out std_logic_vector(15 downto 0)
		);
	end component pooler_addr_gen;
	
	signal clk_s 		 : std_logic;
	signal reset_s 		 : std_logic;
	signal incr_wr_s 	 : std_logic;
	signal valid_rd_s 	 : std_logic;
	signal incr_rd_s 	 : std_logic;
	signal xDim_s 		 : std_logic_vector(15 downto 0);
	signal yDim_s 		 : std_logic_vector(15 downto 0);
	signal line_wraddr_s : std_logic_vector(15 downto 0);
	signal line1_addr_s  : std_logic_vector(15 downto 0);
	signal line2_addr_s  : std_logic_vector(15 downto 0);
	signal line3_addr_s  : std_logic_vector(15 downto 0);
	signal line4_addr_s  : std_logic_vector(15 downto 0);
	signal outputid_s 	 : std_logic_vector(15 downto 0);
	
begin
	
	clock_driver : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process clock_driver;
	
	pag : pooler_addr_gen
		generic map(
			g_Pox        => g_Pox,
			g_Poy        => g_Poy,
			g_Pof        => g_Pof,
			g_NumBuffers => g_NumBuffers,
			g_DataW      => g_DataW
		)
		port map(
			i_clk => clk_s,
			i_reset => reset_s,
			i_incr_rd => incr_rd_s,
			o_valid_rd => valid_rd_s,
			i_incr_wr => incr_wr_s,
			i_xDim => xDim_s,
			i_yDim => yDim_s,
			i_outputid => outputid_s,
			o_line_wraddr => line_wraddr_s,
			o_line1_raddr => line1_addr_s,
			o_line2_raddr => line2_addr_s,
			o_line3_raddr => line3_addr_s,
			o_line4_raddr => line4_addr_s
		);
		
	test : process is
	begin
		
		xDim_s <= std_logic_vector(to_unsigned(12,16));
		yDim_s <= std_logic_vector(to_unsigned(12,16));
		incr_wr_s <= '0';
		incr_rd_s <= '0';
		reset_s <= '1';
		outputid_s <= std_logic_vector(to_unsigned(1,16));
		wait for clock_period;
		
		incr_wr_s <= '1';
		reset_s <= '0';
		wait for 15*clock_period;
		
		
		wait;
	end process test;		

end architecture RTL;
