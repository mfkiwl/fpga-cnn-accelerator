library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity processing_element_tb is
end entity;

architecture simulate of processing_element_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------
  file file_VECTORS : text;
  file file_RESULTS : text;

	constant clock_period : time := 20 ns;
	constant Xparallelism : integer := 3;
	constant Yparallelism : integer := 3;
	constant DataWidth : integer := 16;


	component processing_element is
		generic(
			g_Pox 		 : integer := 3;
			g_Poy 		 : integer := 3;
			g_DataW 	 : integer := 16;
			g_WeightW  : integer := 16;
			g_FifoSize : integer := 9
			);
		port( 
			i_clk   			: in  std_logic; 
			i_reset 			: in  std_logic;
			i_reg_en 			: in  std_logic_vector(g_Poy-1 downto 0);
			i_padding 		: in  std_logic_vector(g_Poy-1 downto 0);
			i_init_mode		: in  std_logic_vector(g_Poy-1 downto 0);
			i_init_data		: in  std_logic_vector(g_Poy*g_Pox*g_DataW-1  downto 0);
			i_pixel  			: in  std_logic_vector(g_Poy*g_DataW-1  downto 0);
			i_fifo_wr_en  : in  std_logic_vector(g_Poy-1 downto 0);
			i_fifo_rd_en  : in  std_logic_vector(g_Poy-1 downto 0);
			i_fifo_mode  	: in  std_logic_vector(g_Poy-1 downto 0);
			i_mac_en			: in  std_logic;
			i_weight			: in  std_logic_vector(g_WeightW-1 downto 0);
			o_data 	 			: out std_logic_vector(g_Poy*g_Pox*g_DataW-1 downto 0)
			);
	end component processing_element;

	signal clk   			: std_logic; 
	signal reset 			: std_logic;
	signal reg_en			: std_logic_vector(Yparallelism - 1 downto 0);
	signal init_mode	: std_logic_vector(Yparallelism - 1 downto 0);
	signal init_data	: std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1  downto 0);
	signal pixel  		: std_logic_vector(Yparallelism * DataWidth - 1  downto 0);
	signal fifo_wr_en : std_logic_vector(Yparallelism - 1 downto 0);
	signal fifo_rd_en : std_logic_vector(Yparallelism - 1 downto 0);
	signal fifo_mode  : std_logic_vector(Yparallelism - 1 downto 0);
	signal padding    : std_logic_vector(Yparallelism - 1 downto 0);

	signal mac_en			: std_logic;
	signal weight			: std_logic_vector(DataWidth-1 downto 0);

	signal data 	 		: std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);



begin
	uut: processing_element 
		generic map(
				g_Pox 	=> Xparallelism,
				g_Poy 	=> Yparallelism,
				g_DataW => DataWidth,
				g_WeightW  => DataWidth,
				g_FifoSize => 9
		)
		port map( 
			i_clk   			=> clk,
			i_reset 			=> reset,
			i_reg_en			=> reg_en,
			i_padding			=> padding,
			i_init_mode		=> init_mode,
			i_init_data		=> init_data,
			i_pixel  			=> pixel,
			i_fifo_wr_en  => fifo_wr_en,
			i_fifo_rd_en  => fifo_rd_en,
			i_fifo_mode  	=> fifo_mode,
			i_mac_en			=> mac_en,
			i_weight			=> weight,
			o_data 	 			=> data
		);
	
	clock_process : process
	begin
		clk <= '0';
		wait for clock_period/2;
		clk <= '1';
		wait for clock_period/2;
	end process;

  stimul: process
    variable v_OLINE     : line;
		variable ok : boolean; 
	  file stimulus : text open read_mode is "stimulus.txt";
	  variable stimulus_line : line;

		variable buffer1    : std_logic_vector(4*Xparallelism*DataWidth-1 downto 0);
		variable buffer2    : std_logic_vector(4*Xparallelism*DataWidth-1 downto 0);
		variable buffer3    : std_logic_vector(4*Xparallelism*DataWidth-1 downto 0);
  begin
 
		-----------------------------------------------------
		--- Read input file. Open write location.
		-----------------------------------------------------
    file_open(file_RESULTS, "output_results.txt", write_mode);

		-----------------------------------------------------
		--- Stimulus
		-----------------------------------------------------

			--readline(file_VECTORS, v_ILINE);
      --read(v_ILINE, v_ADD_TERM1);
      --read(v_ILINE, v_SPACE);           -- read in the space character
      --read(v_ILINE, v_ADD_TERM2);

			readline(stimulus, stimulus_line);
			hread(stimulus_line, buffer1);

			readline(stimulus, stimulus_line);
			hread(stimulus_line, buffer2);

			readline(stimulus, stimulus_line);
			hread(stimulus_line, buffer3);


			wait for clock_period;
			reset <= '1';
			reg_en <= (others => '0');
			init_mode <= (others => '0');
			init_data <= (others => '0');
			pixel <= (others => '0');
			fifo_wr_en <= (others => '0');
			fifo_rd_en <= (others => '0');
			fifo_mode <= (others => '0');
			mac_en <= '1';
			weight <= x"0001";
			padding <= (others => '1');


			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);
			reset <= '0';
			reg_en <= "111";
			init_mode <= "111";

			init_data <= buffer1(4*Xparallelism*DataWidth-1 downto 3*Xparallelism*DataWidth) &
										buffer2(4*Xparallelism*DataWidth-1 downto 3*Xparallelism*DataWidth) &
											buffer3(4*Xparallelism*DataWidth-1 downto 3*Xparallelism*DataWidth);
			

			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			
			fifo_wr_en <= "11-";
			init_mode <= "000";
			init_data <= (others=>'0');
			pixel <= buffer1(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth) & 
								buffer2(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth) &
									buffer3(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth);

			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0002";
			pixel <= buffer1(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth) & 
								buffer2(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth) &
									buffer3(3*Xparallelism*DataWidth-1 downto (3*Xparallelism-1)*DataWidth);

			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0003";
			fifo_rd_en <= "11-";
			fifo_mode <= "110";
			init_mode <= "001";
			init_data <= std_logic_vector(to_unsigned(0,16) & to_unsigned(0,16) & to_unsigned(0,16) & 
																			to_unsigned(0,16) & to_unsigned(0,16) & to_unsigned(0,16)) & 
																	 			buffer1(2*Xparallelism*DataWidth-1 downto 1*Xparallelism*DataWidth);
			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0004";
			init_mode <= "000";
			init_data <= (others=>'0');
			pixel <= std_logic_vector(to_unsigned(0,16) & to_unsigned(0,16)) & buffer1(1*Xparallelism*DataWidth-1 downto (1*Xparallelism-1)*DataWidth);

			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0005";
			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			init_mode <= "001";
			init_data <= std_logic_vector(to_unsigned(0,16) & to_unsigned(0,16) & to_unsigned(0,16) & 
																			to_unsigned(0,16) & to_unsigned(0,16) & to_unsigned(0,16)) & 
																				buffer2(2*Xparallelism*DataWidth-1 downto 1*Xparallelism*DataWidth);
			weight <= x"0006";	

			wait for clock_period;
			hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0007";
			init_mode <= "000";
			init_data <= (others=>'0');
			pixel <= std_logic_vector(to_unsigned(0,16) & to_unsigned(0,16)) & buffer2(1*Xparallelism*DataWidth-1 downto (1*Xparallelism-1)*DataWidth);

			wait for clock_period;
      hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			weight <= x"0008";
			wait for clock_period;
	    hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);


			weight <= x"0009";
			wait for clock_period;
	    hwrite(v_OLINE, data, right, DataWidth*Xparallelism*Yparallelism);
      writeline(file_RESULTS, v_OLINE);

			reset <= '1';
			wait;	
		
    --file_close(file_VECTORS);
    file_close(file_RESULTS);
	end process; -- stimulus
end simulate;
