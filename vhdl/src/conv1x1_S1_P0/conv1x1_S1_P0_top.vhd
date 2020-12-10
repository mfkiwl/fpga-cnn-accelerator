library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv1x1_S1_P0_top is
	generic(
		g_Pox                 : in integer := 3;
		g_Poy                 : in integer := 3;
		g_Pof                 : in integer := 3;
		g_DataW               : in integer := 16;
		g_WeightW             : in integer := 16;
		g_DataBramAddrWidth   : in integer := 16;
		g_KernelBramAddrWidth : in integer := 16
	);
	port(
		i_clk              : in  std_logic;
		i_reset            : in  std_logic;
		i_start            : in  std_logic;
		o_busy             : out std_logic;
		i_padding_mode     : in  std_logic_vector(2 downto 0);
		i_buffer_line      : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_readaddr_data    : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_readen_data      : out std_logic;
		i_kernels          : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_readaddr_kernels : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		o_readen_kernels   : out std_logic;
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
end entity conv1x1_S1_P0_top;

architecture rtl of conv1x1_S1_P0_top is

	type state_type is (IDLE, WAIT_INIT, CONVOLVE);
	signal state, next_state : state_type;

begin

	o_pe_padding <= i_padding_mode;
	o_mac_weight <= i_kernels;
	o_init_data  <= i_buffer_line;

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

	output_decode : process(state)
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
				o_pixel        <= (others => '0');
				o_readaddr_kernels <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
				o_readaddr_data	   <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
			when WAIT_INIT =>
				o_busy         <= '1';
				o_reg_en       <= (others => '1');
				o_init_mode    <= (others => '1');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '0';
				o_pixel        <= (others => '0');
				o_readaddr_kernels <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
				o_readaddr_data	   <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
			when CONVOLVE =>
				o_busy         <= '1';
				o_reg_en       <= (others => '0');
				o_init_mode    <= (others => '0');
				o_fifo_wr_en   <= (others => '0');
				o_fifo_rd_en   <= (others => '0');
				o_fifo_mode    <= (others => '0');
				o_mac_en       <= '1';
				o_pixel        <= (others => '0');
				o_readaddr_kernels <= std_logic_vector(to_unsigned(0, g_KernelBramAddrWidth));
				o_readaddr_data	   <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
		end case;
	end process;

	next_state_decode : process(state, i_start)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= WAIT_INIT;
				end if;
			when WAIT_INIT =>
				next_state <= CONVOLVE;
			when CONVOLVE =>
				next_state <= IDLE;
		end case;
	end process;

end rtl;
