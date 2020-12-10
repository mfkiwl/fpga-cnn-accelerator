library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv7x7_S2_P3_ctrl is
	generic(
		g_Pox                 : integer := 3;
		g_Poy                 : integer := 3;
		g_Pof                 : integer := 3;
		g_DataW               : integer := 16;
		g_WeightW             : integer := 16;
		g_DataBramAddrWidth   : integer := 16;
		g_KernelBramAddrWidth : integer := 16
	);
	port(
		i_clk              : in  std_logic;
		i_reset            : in  std_logic;
		-- control and status
		i_start            : in  std_logic;
		i_padding_mode     : in  std_logic_vector(2 downto 0);
		o_busy             : out std_logic;
		-- kernel read interface
		i_kernel           : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_kread_addr       : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		-- data grabber interface
		o_grabber_start    : out std_logic;
		i_grabber_busy     : in  std_logic;
		o_init_line_rd     : out std_logic;
		i_init_line_data   : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_init_pixels_rd   : out std_logic;
		i_init_pixels_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
		o_pixels_rd        : out std_logic;
		i_pixels_data      : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		o_pixel_rd         : out std_logic;
		i_pixel_data       : in  std_logic_vector(g_DataW - 1 downto 0);
		-- PE and MAC signals
		o_mac_en           : out std_logic;
		o_mac_weight       : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_reg_en           : out std_logic_vector(g_Poy - 1 downto 0);
		o_pe_padding       : out std_logic_vector(2 downto 0);
		o_init_mode        : out std_logic_vector(g_Poy - 1 downto 0);
		o_init_data        : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_pixel            : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		o_fifo_wr_en       : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_rd_en       : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_mode        : out std_logic_vector(g_Poy - 1 downto 0)
	);

end entity;

architecture rtl of conv7x7_S2_P3_ctrl is

	component up_counter
		generic(g_DataWidth : in integer);
		port(
			clk    : in  std_logic;
			reset  : in  std_logic;
			enable : in  std_logic;
			cout   : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component up_counter;

	type state_type is (IDLE, START_DGRABBER, STRIDEBLOCK_INIT, STRIDEBLOCK_PIXELS, STRIDEBLOCK_WAIT_1, ORDBLOCK_INIT, ORDBLOCK_PIXEL, ORDBLOCK_WAIT, WAIT_DGRABBER, INTERMEDIATE, WAIT_IDLE, STRIDEBLOCK_WAIT_2);
	signal state, next_state : state_type;

	signal pixelCtr_clr, blockCtr_clr : std_logic;
	signal pixelCtr_en, blockCtr_en   : std_logic;
	signal pixelCtr, blockCtr         : std_logic_vector(7 downto 0);

	signal kreadAddr_clr : std_logic;
	signal kreadAddr_en  : std_logic;
	signal kreadAddr     : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

	signal padding_reg_en : std_logic;
	signal padding_reg    : std_logic_vector(2 downto 0);

begin

	padding_ff : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_reset = '1') then
				padding_reg <= (others => '0');
			elsif (padding_reg_en = '1') then
				padding_reg <= i_padding_mode;
			end if;
		end if;
	end process;

	o_kread_addr <= kreadAddr;
	o_pe_padding <= padding_reg;
	o_mac_weight <= i_kernel;

	kreadAddrCtr_inst : component up_counter
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => kreadAddr_clr,
			enable => kreadAddr_en,
			cout   => kreadAddr
		);

	pixelCtr_inst : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => pixelCtr_clr,
			enable => pixelCtr_en,
			cout   => pixelCtr
		);

	blockCtr_inst : component up_counter
		generic map(
			g_DataWidth => 8
		)
		port map(
			clk    => i_clk,
			reset  => blockCtr_clr,
			enable => blockCtr_en,
			cout   => blockCtr
		);

	--	o_result   <= data;

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

	next_state_decode : process(state, i_start, i_grabber_busy, blockCtr, pixelCtr)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if i_start = '1' then
					next_state <= START_DGRABBER;
				end if;
			when START_DGRABBER =>
				next_state <= WAIT_DGRABBER;
			when WAIT_DGRABBER =>
				if i_grabber_busy = '0' then
					next_state <= STRIDEBLOCK_INIT;
				else
					next_state <= WAIT_DGRABBER;
				end if;
			when STRIDEBLOCK_INIT =>
				next_state <= STRIDEBLOCK_PIXELS;
			when STRIDEBLOCK_PIXELS =>
				if unsigned(pixelCtr) >= 4 then
					next_state <= STRIDEBLOCK_WAIT_1;
				else
					next_state <= STRIDEBLOCK_PIXELS;
				end if;
			when STRIDEBLOCK_WAIT_1 =>  -- initla 
				if unsigned(pixelCtr) >= 5 then
					next_state <= STRIDEBLOCK_WAIT_2;
				else
					next_state <= STRIDEBLOCK_WAIT_1;
				end if;
			when STRIDEBLOCK_WAIT_2 =>  	
				if unsigned(blockCtr) >= 2 then
					next_state <= INTERMEDIATE;
				else
					next_state <= STRIDEBLOCK_INIT;
				end if;

			when INTERMEDIATE =>
				next_state <= ORDBLOCK_PIXEL;

			when ORDBLOCK_INIT =>
				next_state <= ORDBLOCK_PIXEL;
			when ORDBLOCK_PIXEL =>
				if unsigned(pixelCtr) >= 4 then
					next_state <= ORDBLOCK_WAIT;
				else
					next_state <= ORDBLOCK_PIXEL;
				end if;
			when ORDBLOCK_WAIT =>
				if unsigned(pixelCtr) >= 5 then
					if unsigned(blockCtr) >= 7 then
						next_state <= WAIT_IDLE;
					else
						next_state <= ORDBLOCK_INIT;
					end if;
				else
					next_state <= ORDBLOCK_WAIT;
				end if;

			when WAIT_IDLE =>
				next_state <= IDLE;

		end case;
	end process;

	output_decode : process(state, i_init_line_data, i_pixels_data, i_init_pixels_data, i_pixel_data)
	begin
		case (state) is
			when IDLE =>
				--status
				o_busy           <= '0';
				padding_reg_en   <= '1';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '1';
				blockCtr_clr     <= '1';
				kreadAddr_clr    <= '1';
				pixelCtr_en      <= '0';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '0';
				-- PE interface
				o_reg_en         <= (others => '0');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '0');
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '0';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');
			when START_DGRABBER =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '1';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '0';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '0';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '0';
				-- PE interface
				o_reg_en         <= (others => '0');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '0');
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '0';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');
			when WAIT_DGRABBER =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '0';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '0';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '0';
				-- PE interface
				o_reg_en         <= (others => '0');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '0');
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '0';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');
			when STRIDEBLOCK_INIT =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '1';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '1';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '1';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '0';
				blockCtr_en      <= '1';
				kreadAddr_en     <= '1';
				-- PE interface
				o_reg_en         <= (others => '1');
				o_init_mode      <= (others => '1');
				o_fifo_wr_en     <= (others => '0');
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '0';
				o_init_data      <= i_init_line_data;
				o_pixel          <= i_pixels_data;
			when STRIDEBLOCK_PIXELS =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '1';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '0';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '1';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '1';
				-- PE interface
				o_reg_en         <= (others => '1');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '1');
				o_fifo_wr_en(0)  <= '0';
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '1';
				o_init_data      <= (others => '0');
				o_pixel          <= i_pixels_data;
			when STRIDEBLOCK_WAIT_1 =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '0';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '1';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '1';
				-- PE interface
				o_reg_en         <= (others => '1');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '1');
				o_fifo_wr_en(0)  <= '0';
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '1';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');

			when STRIDEBLOCK_WAIT_2 =>
				--status
				o_busy           <= '1';
				padding_reg_en   <= '0';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '0';
				blockCtr_clr     <= '0';
				kreadAddr_clr    <= '0';
				pixelCtr_en      <= '1';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '0';
				-- PE interface
				o_reg_en         <= (others => '1');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '1');
				o_fifo_wr_en(0)  <= '0';
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '1';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');				

			when INTERMEDIATE =>
				--status
				o_busy                                    <= '1';
				padding_reg_en                            <= '0';
				-- Data grabber interface
				o_grabber_start                           <= '0';
				o_init_line_rd                            <= '0';
				o_init_pixels_rd                          <= '1';
				o_pixels_rd                               <= '0';
				o_pixel_rd                                <= '1';
				-- Counters
				pixelCtr_clr                              <= '1';
				blockCtr_clr                              <= '0';
				kreadAddr_clr                             <= '0';
				pixelCtr_en                               <= '0';
				blockCtr_en                               <= '1';
				kreadAddr_en                              <= '1';
				-- PE interface
				o_reg_en                                  <= (others => '1');
				o_init_mode                               <= (others => '0');
				o_init_mode(0)                            <= '1';
				o_fifo_wr_en                              <= (others => '0');
				o_fifo_wr_en(0)                           <= '0';
				o_fifo_rd_en                              <= (others => '1');
				o_fifo_rd_en(0)                           <= '0';
				o_fifo_mode                               <= (others => '1');
				o_fifo_mode(0)                            <= '0';
				o_mac_en                                  <= '0';
				o_init_data                               <= (others => '0');
				o_init_data(g_Pox * g_DataW - 1 downto 0) <= i_init_pixels_data;
				o_pixel                                   <= (others => '0');
				o_pixel(g_DataW - 1 downto 0)             <= i_pixel_data;

			when ORDBLOCK_INIT =>
				--status
				o_busy                                    <= '1';
				padding_reg_en                            <= '0';
				-- Data grabber interface
				o_grabber_start                           <= '0';
				o_init_line_rd                            <= '0';
				o_init_pixels_rd                          <= '1';
				o_pixels_rd                               <= '0';
				o_pixel_rd                                <= '1';
				-- Counters
				pixelCtr_clr                              <= '1';
				blockCtr_clr                              <= '0';
				kreadAddr_clr                             <= '0';
				pixelCtr_en                               <= '0';
				blockCtr_en                               <= '1';
				kreadAddr_en                              <= '1';
				-- PE interface
				o_reg_en                                  <= (others => '1');
				o_init_mode                               <= (others => '0');
				o_init_mode(0)                            <= '1';
				o_fifo_wr_en                              <= (others => '1');
				o_fifo_wr_en(0)                           <= '0';
				o_fifo_rd_en                              <= (others => '1');
				o_fifo_rd_en(0)                           <= '0';
				o_fifo_mode                               <= (others => '1');
				o_fifo_mode(0)                            <= '0';
				o_mac_en                                  <= '1';
				o_init_data                               <= (others => '0');
				o_init_data(g_Pox * g_DataW - 1 downto 0) <= i_init_pixels_data;
				o_pixel                                   <= (others => '0');
				o_pixel(g_DataW - 1 downto 0)             <= i_pixel_data;
			when ORDBLOCK_PIXEL =>
				--status
				o_busy                        <= '1';
				padding_reg_en                <= '0';
				-- Data grabber interface
				o_grabber_start               <= '0';
				o_init_line_rd                <= '0';
				o_init_pixels_rd              <= '0';
				o_pixels_rd                   <= '0';
				o_pixel_rd                    <= '1';
				-- Counters
				pixelCtr_clr                  <= '0';
				blockCtr_clr                  <= '0';
				kreadAddr_clr                 <= '0';
				pixelCtr_en                   <= '1';
				blockCtr_en                   <= '0';
				kreadAddr_en                  <= '1';
				-- PE interface
				o_reg_en                      <= (others => '1');
				o_init_mode                   <= (others => '0');
				o_fifo_wr_en                  <= (others => '1');
				o_fifo_wr_en(0)               <= '0';
				o_fifo_rd_en                  <= (others => '1');
				o_fifo_rd_en(0)               <= '0';
				o_fifo_mode                   <= (others => '1');
				o_fifo_mode(0)                <= '0';
				o_mac_en                      <= '1';
				o_init_data                   <= (others => '0');
				o_pixel                       <= (others => '0');
				o_pixel(g_DataW - 1 downto 0) <= i_pixel_data;
			when ORDBLOCK_WAIT =>
				--status
				o_busy                        <= '1';
				padding_reg_en                <= '0';
				-- Data grabber interface
				o_grabber_start               <= '0';
				o_init_line_rd                <= '0';
				o_init_pixels_rd              <= '0';
				o_pixels_rd                   <= '0';
				o_pixel_rd                    <= '0';
				-- Counters
				pixelCtr_clr                  <= '0';
				blockCtr_clr                  <= '0';
				kreadAddr_clr                 <= '0';
				pixelCtr_en                   <= '1';
				blockCtr_en                   <= '0';
				kreadAddr_en                  <= '1';
				-- PE interface
				o_reg_en                      <= (others => '1');
				o_init_mode                   <= (others => '0');
				o_fifo_wr_en                  <= (others => '1');
				o_fifo_wr_en(0)               <= '0';
				o_fifo_rd_en                  <= (others => '1');
				o_fifo_rd_en(0)               <= '0';
				o_fifo_mode                   <= (others => '1');
				o_fifo_mode(0)                <= '0';
				o_mac_en                      <= '1';
				o_init_data                   <= (others => '0');
				o_pixel(g_DataW - 1 downto 0) <= i_pixel_data;

			when WAIT_IDLE =>
				--status
				o_busy           <= '0';
				padding_reg_en   <= '1';
				-- Data grabber interface
				o_grabber_start  <= '0';
				o_init_line_rd   <= '0';
				o_init_pixels_rd <= '0';
				o_pixels_rd      <= '0';
				o_pixel_rd       <= '0';
				-- Counters
				pixelCtr_clr     <= '1';
				blockCtr_clr     <= '1';
				kreadAddr_clr    <= '1';
				pixelCtr_en      <= '0';
				blockCtr_en      <= '0';
				kreadAddr_en     <= '0';
				-- PE interface
				o_reg_en         <= (others => '0');
				o_init_mode      <= (others => '0');
				o_fifo_wr_en     <= (others => '0');
				o_fifo_rd_en     <= (others => '0');
				o_fifo_mode      <= (others => '0');
				o_mac_en         <= '1';
				o_init_data      <= (others => '0');
				o_pixel          <= (others => '0');
		end case;
	end process;

end rtl;
