library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooling_register_tb is
end entity pooling_register_tb;

architecture RTL of pooling_register_tb is
	
	constant clock_period : time := 20 ns;
	
	constant g_Pox : integer := 4;
	constant g_DataWidth : integer := 16;	
	
	component pooler_registers
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
	end component;	
	
	component max_pool
		generic(g_DataWidth : integer);
		port(
			i_clk    : in  std_logic;
			i_reset  : in  std_logic;
			i_enable : in  std_logic;
			i_data   : in std_logic_vector(g_DataWidth - 1 downto 0);
			o_result  : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component max_pool;
	
	signal clk 		: std_logic;
	signal reset 	: std_logic;
	signal wrdata 	: std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
	signal wrlineen : std_logic_vector(3 downto 0);
	signal line1 	: std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
	signal line2 	: std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
	signal line3 	: std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
	signal line4 	: std_logic_vector(g_Pox*g_DataWidth-1 downto 0);
	
	signal mp_en	: std_logic;
	signal mp_data 	: std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
	signal mp_resut : std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
	
begin

	uut: pooler_registers
		generic map(
			g_Pox       => g_Pox,
			g_DataWidth => g_DataWidth
		)
		port map(
			i_clk      => clk,
			i_reset    => reset,
			i_wrdata   => wrdata,
			i_wrlineen => wrlineen,
			o_line1    => line1,
			o_line2    => line2,
			o_line3    => line3,
			o_line4    => line4
		);
		
	g1 : for jj in g_Pox downto 1 generate
		maxpool : component max_pool
		generic map(
			g_DataWidth => g_DataWidth
		)
		port map(
			i_clk    => clk,
			i_reset  => reset,
			i_enable => mp_en,
			i_data   => mp_data(jj*g_DataWidth -1 downto (jj-1)*g_DataWidth),
			o_result  => mp_resut(jj*g_DataWidth -1 downto (jj-1)*g_DataWidth)
		);
	end generate g1;



		
	clock_driver : process
	begin
		clk <= '0';
		wait for clock_period / 2;
		clk <= '1';
		wait for clock_period / 2;
	end process clock_driver;

	test : process is
	begin
		reset <= '1';
		wait for clock_period;
		
		reset <= '0';
		wait for clock_period;
		
		wrdata <= x"0011001200130014";
		wrlineen <= "0001";
		
		wait for clock_period;
		mp_en <= '1';
		mp_data <= x"0011001200130014";
		
		wrdata <= x"0015001600170018";
		wrlineen <= "0010";
		
		wait for clock_period;
		wrdata <= x"0021002200230024";
		wrlineen <= "0100";
		mp_data <= line2;
		
		wait for clock_period;
		wrdata <= x"0025002600270028";
		wrlineen <= "1000";		
		mp_data <= line3;
		
		wait for clock_period;	
		mp_data <= line4;
		
		wait for clock_period;	
		mp_en <= '0';
								
		wait;
	end process test;
		

end architecture RTL;
