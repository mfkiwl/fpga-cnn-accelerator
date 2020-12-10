library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_array is
	generic(
		g_Pox   : integer := 3;
		g_DataW : integer := 16
	);
	port(
		i_clk       : in  std_logic;
		i_reset     : in  std_logic;
		i_en        : in  std_logic;
		-- Initialize
		i_init_mode : in  std_logic;
		i_padding   : in  std_logic_vector(2 downto 0);
		i_init_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
		-- Feed data into rightmost register for shifting
		i_pixel     : in  std_logic_vector(g_DataW - 1 downto 0);
		-- Ingest data from FIFO
		i_fifo_mode : in  std_logic;
		i_fifo_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
		-- Output data buss
		o_data      : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
	);
end reg_array;

architecture rtl of reg_array is

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
	
	constant max_padding : integer := 3;

	signal data_in  : std_logic_vector((g_Pox + max_padding) * g_DataW - 1 downto 0);
	signal data_out : std_logic_vector((g_Pox + max_padding) * g_DataW - 1 downto 0);

begin

	-- Assign only the g_Pox registers to output. Ignore the last input-shift register.
	o_data <= data_out((g_Pox + 3) * g_DataW - 1 downto 3*g_DataW); -- 3 stands for max-padding size

	-- Create register structure (line-buffer).
	g1 : for ii in g_Pox + 3 downto 1 generate

		-- The left-most register should be initialized to 0 to add padding which differentiates it from the inner-regs. wiring.
		if3 : if ii = g_Pox + 3 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= (others => '0') when i_init_mode = '1' and (i_padding = "001" or i_padding = "010"  or i_padding = "100")
			                                                       else i_init_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_init_mode = '1' and i_padding = "000"
			                                                       else i_fifo_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_fifo_mode = '1'
			                                                       else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2));
		end generate;
		
		if2 : if ii = g_Pox + 2 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= (others => '0') when i_init_mode = '1' and (i_padding = "100"  or i_padding = "010")
																   else i_init_data(g_DataW * (ii - 2) - 1 downto g_DataW * (ii - 3)) when i_init_mode = '1' and (i_padding = "001")
																   else i_init_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_init_mode = '1' and (i_padding = "000")
			                                                       else i_fifo_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_fifo_mode = '1'
			                                                       else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2));
		end generate;		

		if1 : if ii = g_Pox + 1 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= (others => '0') when i_init_mode = '1' and (i_padding = "100")
																   else i_init_data(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2)) when i_init_mode = '1' and (i_padding = "010")
																   else i_init_data(g_DataW * (ii - 2) - 1 downto g_DataW * (ii - 3)) when i_init_mode = '1' and (i_padding = "001")
																   else i_init_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_init_mode = '1' and (i_padding = "000")
			                                                       else i_fifo_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_fifo_mode = '1'
			                                                       else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2));
		end generate;	
		
		-- Handle inner-reg wiring.
		if21 : if ii < g_Pox + 1 and ii > 3 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= i_init_data(g_DataW * ii - 1 downto g_DataW * (ii - 1)) when i_init_mode = '1' and i_padding = "100"
																   else i_init_data(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2)) when i_init_mode = '1' and i_padding = "010"
																   else i_init_data(g_DataW * (ii - 2) - 1 downto g_DataW * (ii - 3)) when i_init_mode = '1' and i_padding = "001"
			                                                       else i_init_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_init_mode = '1' and i_padding = "000"
			                                                       else i_fifo_data(g_DataW * (ii - 3) - 1 downto g_DataW * (ii - 4)) when i_fifo_mode = '1'
			                                                       else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2));
		end generate;

		-- Handle rightmost register wiring.
		if33 : if ii = 3 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= i_init_data(3*g_DataW - 1 downto 2*g_DataW) when i_init_mode = '1' and i_padding = "100"
																   else i_init_data(2*g_DataW - 1 downto g_DataW) when i_init_mode = '1' and i_padding = "010"
				  												   else i_init_data(g_DataW - 1 downto 0) when i_init_mode = '1' and i_padding = "001"
																   else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2)) when i_init_mode = '0' and (i_padding = "100" or i_padding = "010")
																   else i_pixel;																   
		end generate;
		
		if32 : if ii = 2 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= i_init_data(2*g_DataW - 1 downto g_DataW) when i_init_mode = '1' and i_padding = "100"
																   else i_init_data(g_DataW - 1 downto 0) when i_init_mode = '1' and i_padding = "010"
																   else data_out(g_DataW * (ii - 1) - 1 downto g_DataW * (ii - 2)) when i_init_mode = '0' and i_padding = "100"
																   else i_pixel;																   
		end generate;		

		if31 : if ii = 1 generate
			data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)) <= i_init_data(g_DataW - 1 downto 0) when i_init_mode = '1' and i_padding = "100" 
																   else i_pixel;
		end generate;
		
		
		-- Instantiate registers.
		ff : reg
			generic map(
				N => g_DataW
			)
			port map(
				i_clk   => i_clk,
				i_reset => i_reset,
				i_en    => i_en,
				i_a     => data_in(g_DataW * ii - 1 downto g_DataW * (ii - 1)),
				o_b     => data_out(g_DataW * ii - 1 downto g_DataW * (ii - 1))
			);
	end generate g1;
end rtl;
