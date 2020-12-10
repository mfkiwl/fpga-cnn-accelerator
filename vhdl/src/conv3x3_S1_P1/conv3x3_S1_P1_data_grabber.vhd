library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv3x3_S1_P1_data_grabber is
	generic(
		g_Pox               : in integer := 3;
		g_Poy               : in integer := 3;
		g_DataW             : in integer := 16;
		g_DataBramAddrWidth : in integer := 16
	);
	port(
		i_clk            : in  std_logic;
		i_reset          : in  std_logic;
		i_start          : in  std_logic;
		o_ready          : out std_logic;
		i_buffer_line    : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_readaddr       : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_readen         : out std_logic;
		-- Init Pixel Aggregates
		o_init_L0        : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_init_L2_C1     : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_init_L2_C2     : out std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		-- L1 Pixels
		o_pixels_L1_P1   : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		o_pixels_L1_P2   : out std_logic_vector(g_Poy * g_DataW - 1 downto 0);
		-- L3 Pixels
		o_pixel_L3_C1_P1 : out std_logic_vector(g_DataW - 1 downto 0);
		o_pixel_L3_C1_P2 : out std_logic_vector(g_DataW - 1 downto 0);
		o_pixel_L3_C2_P1 : out std_logic_vector(g_DataW - 1 downto 0);
		o_pixel_L3_C2_P2 : out std_logic_vector(g_DataW - 1 downto 0)
	);

end entity;

architecture rtl of conv3x3_S1_P1_data_grabber is

	component reg is
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

	type state_type is (IDLE, FETCH_L1, FETCH_L2, FETCH_L3, FETCH_L4, WAIT_L4);
	signal state, next_state : state_type;

	signal flipflop_en : std_logic_vector(3 downto 0);
	signal flipflop_0  : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal flipflop_1  : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal flipflop_2  : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal flipflop_3  : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
begin

	o_init_L0                                      <= flipflop_0;
	o_init_L2_C1(1 * g_Pox * g_DataW - 1 downto 0) <= flipflop_2(g_Poy * g_Pox * g_DataW - 1 downto (g_Poy - 1) * g_Pox * g_DataW);
	o_init_L2_C2(1 * g_Pox * g_DataW - 1 downto 0) <= flipflop_2((g_Poy - 1) * g_Pox * g_DataW - 1 downto (g_Poy - 2) * g_Pox * g_DataW);

	-- L1 Pixels
	g1 : for jj in g_Poy downto 1 generate
		o_pixels_L1_P1(jj * g_DataW - 1 downto (jj - 1) * g_DataW) <= flipflop_1(jj * g_Pox * g_DataW - 1 downto (jj * g_Pox - 1) * g_DataW);
		o_pixels_L1_P2(jj * g_DataW - 1 downto (jj - 1) * g_DataW) <= flipflop_1((jj * g_Pox - 1) * g_DataW - 1 downto (jj * g_Pox - 2) * g_DataW);
	end generate g1;

	-- L3 Pixels
	o_pixel_L3_C1_P1 <= flipflop_3(g_Poy * g_Pox * g_DataW - 1 downto (g_Poy * g_Pox - 1) * g_DataW);
	o_pixel_L3_C1_P2 <= flipflop_3((g_Poy * g_Pox - 1) * g_DataW - 1 downto (g_Poy * g_Pox - 2) * g_DataW);

	o_pixel_L3_C2_P1 <= flipflop_3((g_Poy - 1) * g_Pox * g_DataW - 1 downto ((g_Poy - 1) * g_Pox - 1) * g_DataW);
	o_pixel_L3_C2_P2 <= flipflop_3(((g_Poy - 1) * g_Pox - 1) * g_DataW - 1 downto ((g_Poy - 1) * g_Pox - 2) * g_DataW);

	Line0 : reg
		generic map(
			N => g_Poy * g_Pox * g_DataW
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_reset,
			i_en    => flipflop_en(0),
			i_a     => i_buffer_line,
			o_b     => flipflop_0
		);

	Line1 : reg
		generic map(
			N => g_Poy * g_Pox * g_DataW
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_reset,
			i_en    => flipflop_en(1),
			i_a     => i_buffer_line,
			o_b     => flipflop_1
		);

	Line2 : reg
		generic map(
			N => g_Poy * g_Pox * g_DataW
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_reset,
			i_en    => flipflop_en(2),
			i_a     => i_buffer_line,
			o_b     => flipflop_2
		);

	Line3 : reg
		generic map(
			N => g_Poy * g_Pox * g_DataW
		)
		port map(
			i_clk   => i_clk,
			i_reset => i_reset,
			i_en    => flipflop_en(3),
			i_a     => i_buffer_line,
			o_b     => flipflop_3
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

	next_state_decode : process(state, i_start)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= FETCH_L1;
				end if;
			when FETCH_L1 =>
				next_state <= FETCH_L2;
			when FETCH_L2 =>
				next_state <= FETCH_L3;
			when FETCH_L3 =>
				next_state <= FETCH_L4;
			when FETCH_L4 =>
				next_state <= WAIT_L4;
			when WAIT_L4 =>
				next_state <= IDLE;
		end case;
	end process;

	output_decode : process(state)
	begin
		case (state) is
			when IDLE =>
				o_readaddr  <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				o_readen    <= '0';
				o_ready     <= '1';
				flipflop_en <= "0000";
			when FETCH_L1 =>
				o_readaddr  <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				o_readen    <= '1';
				o_ready     <= '0';
				flipflop_en <= "0000";
			when FETCH_L2 =>
				o_readaddr  <= std_logic_vector(to_unsigned(1, g_DataBramAddrWidth));
				o_readen    <= '1';
				o_ready     <= '0';
				flipflop_en <= "0001";
			when FETCH_L3 =>
				o_readaddr  <= std_logic_vector(to_unsigned(2, g_DataBramAddrWidth));
				o_readen    <= '1';
				o_ready     <= '0';
				flipflop_en <= "0010";
			when FETCH_L4 =>
				o_readaddr  <= std_logic_vector(to_unsigned(3, g_DataBramAddrWidth));
				o_readen    <= '1';
				o_ready     <= '0';
				flipflop_en <= "0100";
			when WAIT_L4 =>
				o_readaddr  <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				o_readen    <= '0';
				o_ready     <= '1';
				flipflop_en <= "1000";
		end case;
	end process;

end rtl;
