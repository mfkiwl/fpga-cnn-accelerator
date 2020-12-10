library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv3x3_S1_P1_ctrl is
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
		i_clk            : in  std_logic;
		i_reset          : in  std_logic;
		-- i_kernel == 9 <-> number of kernel entries
		i_kernel         : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		i_start          : in  std_logic;
		i_padding_mode   : in  std_logic_vector(2 downto 0);
		-- dread 
		o_kread_addr     : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		-- data grabber interface
		i_grabber_ready  : in  std_logic;
		i_init_L0        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		i_init_L2_C1     : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		i_init_L2_C2     : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		i_pixels_L1_P1   : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		i_pixels_L1_P2   : in  std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		i_pixel_L3_C1_P1 : in  std_logic_vector(g_DataW - 1 downto 0);
		i_pixel_L3_C1_P2 : in  std_logic_vector(g_DataW - 1 downto 0);
		i_pixel_L3_C2_P1 : in  std_logic_vector(g_DataW - 1 downto 0);
		i_pixel_L3_C2_P2 : in  std_logic_vector(g_DataW - 1 downto 0);
		o_busy           : out std_logic;
		o_mac_en         : out std_logic;
		o_mac_weight     : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_reg_en         : out std_logic_vector(g_Poy - 1 downto 0);
		o_pe_padding     : out std_logic_vector(2 downto 0);
		o_init_mode      : out std_logic_vector(g_Poy - 1 downto 0);
		o_init_data      : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_pixel          : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		o_fifo_wr_en     : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_rd_en     : out std_logic_vector(g_Poy - 1 downto 0);
		o_fifo_mode      : out std_logic_vector(g_Poy - 1 downto 0)
	);

end entity;

architecture rtl of conv3x3_S1_P1_ctrl is

	--	signal data : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);

	signal padding_reg_en : std_logic;
	signal padding_reg    : std_logic;

	type state_type is (IDLE, PREFETCH_BUFLINE, WAIT_INIT, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10);
	signal state, next_state : state_type;

begin

	--	o_result   <= data;
	o_pe_padding <= i_padding_mode;
	o_mac_weight <= i_kernel;

	padding_ff : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_reset = '1') then
				padding_reg <= '0';
			elsif (padding_reg_en = '1') then
				padding_reg <= i_padding_mode(0);
			end if;
		end if;
	end process;

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

	output_decode : process(state, i_init_L0, i_init_L2_C1, i_init_L2_C2, i_pixel_L3_C1_P1, i_pixel_L3_C1_P2, i_pixel_L3_C2_P1, i_pixel_L3_C2_P2, i_pixels_L1_P1, i_pixels_L1_P2, padding_reg)
	begin
		case (state) is
			when IDLE =>
				o_busy         <= '0';
				o_reg_en       <= (others => '0');
				o_init_mode    <= (others => '0');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '0';
				padding_reg_en <= '1';
				o_init_data    <= (others => '0');
				o_pixel        <= (others => '0');
				o_kread_addr   <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
			when PREFETCH_BUFLINE =>
				o_busy         <= '1';
				o_reg_en       <= (others => '0');
				o_init_mode    <= (others => '0');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '0';
				padding_reg_en <= '0';
				o_init_data    <= (others => '0');
				o_pixel        <= (others => '0');
				o_kread_addr   <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
			when WAIT_INIT =>
				o_busy         <= '1';
				o_reg_en       <= (others => '1');
				o_init_mode    <= (others => '1');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '0';
				padding_reg_en <= '0';
				if (padding_reg = '1') then
					o_init_data <= i_init_L0;
					o_pixel     <= (others => '0');
				else
					o_init_data <= i_init_L0;
					o_pixel     <= i_pixels_L1_P1;
				end if;
				o_kread_addr   <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
			when S1 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '1');
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '0');
				o_fifo_mode     <= (others => '0');
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				if (padding_reg = '1') then
					o_init_data <= (others => '0');
					o_pixel     <= i_pixels_L1_P1;
				else
					o_init_data <= (others => '0');
					o_pixel     <= i_pixels_L1_P2;
				end if;
				o_kread_addr    <= std_logic_vector(to_unsigned(1, g_KernelBramAddrWidth));
			when S2 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '1');
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '0');
				o_fifo_mode     <= (others => '0');
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				o_init_data     <= (others => '0');
				o_pixel         <= (others => '0');
				o_kread_addr    <= std_logic_vector(to_unsigned(2, g_KernelBramAddrWidth));
			when S3 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_init_mode(0)  <= '1';
				o_fifo_wr_en    <= (others => '1');
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				if (padding_reg = '1') then
					o_init_data <= i_init_L2_C1;
					o_pixel     <= (others => '0');
				else
					o_init_data                   <= i_init_L2_C1;
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C1_P1;
				end if;
				o_kread_addr    <= std_logic_vector(to_unsigned(3, g_KernelBramAddrWidth));
			when S4 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '1');
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				if (padding_reg = '1') then
					o_init_data                   <= (others => '0');
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C1_P1;
				else
					o_init_data                   <= (others => '0');
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C1_P2;
				end if;
				o_kread_addr    <= std_logic_vector(to_unsigned(4, g_KernelBramAddrWidth));
			when S5 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '1');
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				o_init_data     <= (others => '0');
				o_pixel         <= (others => '0');
				o_kread_addr    <= std_logic_vector(to_unsigned(5, g_KernelBramAddrWidth));
			when S6 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_init_mode(0)  <= '1';
				o_fifo_wr_en    <= (others => '1'); -- Split assignment into 2 rows to obey VHDL rules.
				o_fifo_wr_en(0) <= '0';
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				if (padding_reg = '1') then
					o_init_data <= i_init_L2_C2;
					o_pixel     <= (others => '0');
				else
					o_init_data                   <= i_init_L2_C2;
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C2_P1;
				end if;
				o_kread_addr    <= std_logic_vector(to_unsigned(6, g_KernelBramAddrWidth));
			when S7 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '0');
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				if (padding_reg = '1') then
					o_init_data                   <= (others => '0');
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C2_P1;
				else
					o_init_data                   <= (others => '0');
					o_pixel                       <= (others => '0');
					o_pixel(g_DataW - 1 downto 0) <= i_pixel_L3_C2_P2;
				end if;
				o_kread_addr    <= std_logic_vector(to_unsigned(7, g_KernelBramAddrWidth));
			when S8 =>
				o_busy          <= '1';
				o_reg_en        <= (others => '1');
				o_init_mode     <= (others => '0');
				o_fifo_wr_en    <= (others => '0');
				o_fifo_rd_en    <= (others => '1');
				o_fifo_rd_en(0) <= '0';
				o_fifo_mode     <= (others => '1');
				o_fifo_mode(0)  <= '0';
				o_mac_en        <= '1';
				padding_reg_en  <= '0';
				o_init_data     <= (others => '0');
				o_pixel         <= (others => '0');
				o_kread_addr    <= std_logic_vector(to_unsigned(8, g_KernelBramAddrWidth));
			when S9 =>
				o_busy         <= '1';
				o_reg_en       <= (others => '1');
				o_init_mode    <= (others => '0');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '1';
				padding_reg_en <= '0';
				o_init_data    <= (others => '0');
				o_pixel        <= (others => '0');
				o_kread_addr   <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
			when others =>
				o_busy         <= '0';
				o_reg_en       <= (others => '1');
				o_init_mode    <= (others => '0');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '0';
				padding_reg_en <= '0';
				o_init_data    <= (others => '0');
				o_pixel        <= (others => '0');
		end case;
	end process;

	next_state_decode : process(state, i_start, i_grabber_ready)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= PREFETCH_BUFLINE;
				end if;
			when PREFETCH_BUFLINE =>
				if (i_grabber_ready = '1') then
					next_state <= WAIT_INIT;
				else
					next_state <= PREFETCH_BUFLINE;
				end if;
			when WAIT_INIT =>
				next_state <= S1;
			when S1 =>
				next_state <= S2;
			when S2 =>
				next_state <= S3;
			when S3 =>
				next_state <= S4;
			when S4 =>
				next_state <= S5;
			when S5 =>
				next_state <= S6;
			when S6 =>
				next_state <= S7;
			when S7 =>
				next_state <= S8;
			when S8 =>
				next_state <= S9;
			when S9 =>
				next_state <= S10;
			when S10 =>
				next_state <= IDLE;
		end case;
	end process;

end rtl;
