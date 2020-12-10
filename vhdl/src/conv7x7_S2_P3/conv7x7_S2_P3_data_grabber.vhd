library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv7x7_S2_P3_data_grabber is
	generic(
		g_Pox               : in integer := 3;
		g_Poy               : in integer := 3;
		g_DataW             : in integer := 16;
		g_DataBramAddrWidth : in integer := 16
	);
	port(
		i_clk              : in  std_logic;
		i_reset            : in  std_logic;
		i_start            : in  std_logic;
		o_busy             : out std_logic;
		i_buffer_line      : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_readaddr         : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_readen           : out std_logic;
		-- Read init line
		i_init_line_rd     : in  std_logic;
		o_init_line_data   : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		i_init_pixels_rd   : in  std_logic;
		o_init_pixels_data : out std_logic_vector(g_Pox * g_DataW - 1 downto 0);
		i_pixels_rd        : in  std_logic;
		o_pixels_data      : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		i_pixel_rd         : in  std_logic;
		o_pixel_data       : out std_logic_vector(g_DataW - 1 downto 0)
	);

end entity;

architecture rtl of conv7x7_S2_P3_data_grabber is

	constant rows_per_convblock : integer := (6 + g_Pox - 1) / g_Pox + 1;

	component up_counter
		generic(g_DataWidth : in integer);
		port(
			clk    : in  std_logic;
			reset  : in  std_logic;
			enable : in  std_logic;
			cout   : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component up_counter;

	component accumulator
		generic(g_DataWidth : integer);
		port(
			clk    : in  std_logic;
			reset  : in  std_logic;
			enable : in  std_logic;
			din    : in  std_logic_vector(g_DataWidth - 1 downto 0);
			q      : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component accumulator;

	component fifo
		generic(
			g_WIDTH : natural;
			g_DEPTH : integer
		);
		port(
			i_rst     : in  std_logic;
			i_clk     : in  std_logic;
			i_wr_en   : in  std_logic;
			i_wr_data : in  std_logic_vector(g_WIDTH - 1 downto 0);
			o_full    : out std_logic;
			i_rd_en   : in  std_logic;
			o_rd_data : out std_logic_vector(g_WIDTH - 1 downto 0);
			o_empty   : out std_logic
		);
	end component fifo;

	signal blockCtr_en, lineBaseCtr_en, lineOffsetCtr_en, posCtr_en, colCtr_en, rowCtr_en       : std_logic;
	signal blockCtr_clr, lineBaseCtr_clr, lineOffsetCtr_clr, posCtr_clr, colCtr_clr, rowCtr_clr : std_logic;
	signal blockCtr, posCtr, colCtr, rowCtr                                                     : std_logic_vector(7 downto 0);
	signal lineBaseCtr, lineOffsetCtr                                                           : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);

	signal wr_en      : std_logic;
	signal wr_address : natural := 0;
	signal rd_address : natural := 0;

	signal line_counter_en : std_logic;
	signal line_counter    : std_logic_vector(7 downto 0);

	type state_type is (IDLE, ITER_POS_INIT, ITER_LINE_INIT, ITER_MACROBLOCK_INIT, WAIT_DATA_INIT_MACROBLOCK, INTERMEDIATE_STATE, ITER_LINE, ITER_BLOCK, WAIT_DATA_BLOCK, ITER_MACROBLOCK, WAIT_DATA_MACROBLOCK, ITER_POS, WAIT_DATA_LINE, WAIT_DATA_INIT_LINE, WAIT_IDLE, PRE_ITER_LINE_INIT, PRE_ITER_LINE, WAIT_DATA_INTERMEDIATE_STATE);
	signal state, next_state : state_type;

	signal initLineFifo_wren, pixelsFifo_wren, initPixelsFifo_wren, pixelFifo_wren : std_logic;

	-- i_buffer_line
	signal pixels_s      : std_logic_vector(g_Poy * g_DataW - 1 downto 0);
	signal init_pixels_s : std_logic_vector(g_Pox * g_DataW - 1 downto 0);
	signal pixel_s       : std_logic_vector(g_DataW - 1 downto 0);

begin

	--- - - - - - - - - - - - - - - - - - - - -
	--- Output fifos
	--- - - - - - - - - - - - - - - - - - - - -	
	initLineFifo : component fifo
		generic map(
			g_WIDTH => g_Poy * g_Pox * g_DataW,
			g_DEPTH => 2
		)
		port map(
			i_rst     => i_reset,
			i_clk     => i_clk,
			i_wr_en   => initLineFifo_wren,
			i_wr_data => i_buffer_line,
			o_full    => open,
			i_rd_en   => i_init_line_rd,
			o_rd_data => o_init_line_data,
			o_empty   => open
		);

	pixelsFifo : component fifo
		generic map(
			g_WIDTH => g_Poy * g_DataW,
			g_DEPTH => 14
		)
		port map(
			i_rst     => i_reset,
			i_clk     => i_clk,
			i_wr_en   => pixelsFifo_wren,
			i_wr_data => pixels_s,
			o_full    => open,
			i_rd_en   => i_pixels_rd,
			o_rd_data => o_pixels_data,
			o_empty   => open
		);

	initPixelsFifo : component fifo
		generic map(
			g_WIDTH => g_Pox * g_DataW,
			g_DEPTH => 6
		)
		port map(
			i_rst     => i_reset,
			i_clk     => i_clk,
			i_wr_en   => initPixelsFifo_wren,
			i_wr_data => init_pixels_s,
			o_full    => open,
			i_rd_en   => i_init_pixels_rd,
			o_rd_data => o_init_pixels_data,
			o_empty   => open
		);

	pixelFifo : component fifo
		generic map(
			g_WIDTH => g_DataW,
			g_DEPTH => 32
		)
		port map(
			i_rst     => i_reset,
			i_clk     => i_clk,
			i_wr_en   => pixelFifo_wren,
			i_wr_data => pixel_s,
			o_full    => open,
			i_rd_en   => i_pixel_rd,
			o_rd_data => o_pixel_data,
			o_empty   => open
		);

	--- - - - - - - - - - - - - - - - - - - - -
	--- Output signals 
	--- - - - - - - - - - - - - - - - - - - - -
	-- bram read address 
	o_readaddr <= std_logic_vector(unsigned(lineBaseCtr) + unsigned(lineOffsetCtr));

	-- pixels data
	g1 : for jj in g_Poy downto 1 generate
		pixels_s(jj * g_DataW - 1 downto (jj - 1) * g_DataW) <= i_buffer_line((jj * g_Pox - to_integer(unsigned(posCtr))) * g_DataW - 1 downto (jj * g_Pox - to_integer(unsigned(posCtr)) - 1) * g_DataW);
	end generate g1;

	-- single pixel value
	init_pixels_s <= i_buffer_line((g_Poy - to_integer(unsigned(blockCtr))) * g_Pox * g_DataW - 1 downto (g_Poy - to_integer(unsigned(blockCtr)) - 1) * g_Pox * g_DataW);

	pixel_s <= i_buffer_line((g_Poy - to_integer(unsigned(blockCtr))) * g_Pox * g_DataW - to_integer(unsigned(posCtr)) * g_DataW - 1 downto (g_Poy - to_integer(unsigned(blockCtr))) * g_Pox * g_DataW - (to_integer(unsigned(posCtr)) + 1) * g_DataW);

	--- - - - - - - - - - - - - - - - - - - - -
	--- Loop coutners
	--- - - - - - - - - - - - - - - - - - - - -		
	cctr : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => colCtr_clr,
			enable => colCtr_en,
			cout   => colCtr
		);

	rctr : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => rowCtr_clr,
			enable => rowCtr_en,
			cout   => rowCtr
		);

	bctr : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => blockCtr_clr,
			enable => blockCtr_en,
			cout   => blockCtr
		);

	lbacc : component accumulator
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => lineBaseCtr_clr,
			enable => lineBaseCtr_en,
			din    => std_logic_vector(to_unsigned(rows_per_convblock, g_DataBramAddrWidth)),
			q      => lineBaseCtr
		);

	loctr : component up_counter
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => lineOffsetCtr_clr,
			enable => lineOffsetCtr_en,
			cout   => lineOffsetCtr
		);

	pctr : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => posCtr_clr,
			enable => posCtr_en,
			cout   => posCtr
		);

	sync_proc : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_reset = '1') then
				state <= IDLE;
			else
				state <= next_state;
			end if;
		end if;
	end process;

	next_state_decode : process(state, blockCtr, colCtr, posCtr, i_start, rowCtr)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= PRE_ITER_LINE_INIT;
				end if;
				
				
			-- Macroblock iterations
			when ITER_MACROBLOCK_INIT =>
				next_state <= WAIT_DATA_INIT_MACROBLOCK;
			when WAIT_DATA_INIT_MACROBLOCK =>
				next_state <= PRE_ITER_LINE_INIT;

			-- Line iterations
			when PRE_ITER_LINE_INIT =>
				next_state <= WAIT_DATA_INIT_LINE;			
			when ITER_LINE_INIT =>
				next_state <= WAIT_DATA_INIT_LINE;
			when WAIT_DATA_INIT_LINE =>
				next_state <= ITER_POS_INIT;

			-- Pos iterations
			when ITER_POS_INIT =>
				if unsigned(colCtr) >= 5 then
					if unsigned(rowCtr) >= 1 then
						next_state <= INTERMEDIATE_STATE;
					else
						next_state <= ITER_MACROBLOCK_INIT;
					end if;
				elsif unsigned(posCtr) = g_Pox - 2 then
					next_state <= ITER_LINE_INIT;
				else
					next_state <= ITER_POS_INIT;
				end if;

			-- Intermediate state between stride part and ordinary part
			when INTERMEDIATE_STATE =>
				next_state <= WAIT_DATA_INTERMEDIATE_STATE;
			when WAIT_DATA_INTERMEDIATE_STATE =>
				next_state <= PRE_ITER_LINE;				
				

			-- ORdinary rows
			when ITER_MACROBLOCK =>
				next_state <= WAIT_DATA_MACROBLOCK;
			when WAIT_DATA_MACROBLOCK =>
				next_state <= PRE_ITER_LINE;
				
			when ITER_BLOCK =>
				next_state <= WAIT_DATA_BLOCK;
			when WAIT_DATA_BLOCK =>
				next_state <= PRE_ITER_LINE;				

			when PRE_ITER_LINE =>
				next_state <= WAIT_DATA_LINE;		
			when ITER_LINE =>
				next_state <= WAIT_DATA_LINE;
			when WAIT_DATA_LINE =>
				next_state <= ITER_POS;



			when ITER_POS =>
				if unsigned(colCtr) >= 3 then
					if unsigned(rowCtr) >= 6 then
						next_state <= WAIT_IDLE;
					elsif unsigned(blockCtr) = g_Poy - 1 then
						next_state <= ITER_MACROBLOCK;
					else
						next_state <= ITER_BLOCK;
					end if;
				elsif unsigned(posCtr) = g_Pox - 2 then
					next_state <= ITER_LINE;
				else
					next_state <= ITER_POS;
				end if;

			when WAIT_IDLE =>
				next_state <= IDLE;
		end case;
	end process;

	output_decode : process(state)
	begin
		case (state) is
		when IDLE =>			
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '1';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '1';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '1';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '1';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '1';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';	
			when PRE_ITER_LINE_INIT =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '1';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '1';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '1';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';				
			when ITER_LINE_INIT =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '1';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '1';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '1';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when ITER_POS_INIT =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '1';
				posCtr_clr        <= '0';
				colCtr_en         <= '1';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '1';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when ITER_MACROBLOCK_INIT =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '1';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '1';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '1';
				rowCtr_en         <= '1';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '1';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when WAIT_DATA_INIT_MACROBLOCK =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when INTERMEDIATE_STATE =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '1';
				lineBaseCtr_en    <= '1';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '1';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '1';
				rowCtr_en         <= '1';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '1';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';		
				
			when PRE_ITER_LINE =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '1';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '1';
				pixelFifo_wren 		<= '0';						
			when ITER_LINE =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '1';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '1';
			when ITER_POS =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '1';
				posCtr_clr        <= '0';
				colCtr_en         <= '1';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '1';
			when ITER_BLOCK =>
				o_busy            <= '0';
				blockCtr_en       <= '1';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '1';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '1';
				rowCtr_en         <= '1';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '1';
			when WAIT_DATA_BLOCK =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when ITER_MACROBLOCK =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '1';
				lineBaseCtr_en    <= '1';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '1';
				posCtr_en         <= '0';
				posCtr_clr        <= '1';
				colCtr_en         <= '0';
				colCtr_clr        <= '1';
				rowCtr_en         <= '1';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '1';
			when WAIT_DATA_LINE =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when WAIT_DATA_INIT_LINE =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when WAIT_DATA_MACROBLOCK =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';
			when WAIT_DATA_INTERMEDIATE_STATE =>
				o_busy            <= '1';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '0';				
			when WAIT_IDLE =>
				o_busy            <= '0';
				blockCtr_en       <= '0';
				blockCtr_clr      <= '0';
				lineBaseCtr_en    <= '0';
				lineBaseCtr_clr   <= '0';
				lineOffsetCtr_en  <= '0';
				lineOffsetCtr_clr <= '0';
				posCtr_en         <= '0';
				posCtr_clr        <= '0';
				colCtr_en         <= '0';
				colCtr_clr        <= '0';
				rowCtr_en         <= '0';
				rowCtr_clr        <= '0';
				-- FIFO
				initLineFifo_wren 	<= '0';
				pixelsFifo_wren		<= '0';
				initPixelsFifo_wren <= '0';
				pixelFifo_wren 		<= '1';
		end case;
	end process;

end rtl;
