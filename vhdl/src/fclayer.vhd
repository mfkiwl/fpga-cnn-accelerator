library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fclayer is
	generic(
		g_Pox                 : in integer;
		g_Poy                 : in integer;
		g_Pof                 : in integer;
		g_DataW               : in integer;
		g_WeightW             : in integer;
		g_DataBramAddrWidth   : in integer;
		g_KernelBramAddrWidth : in integer
	);
	port(
		i_clk                : in  std_logic;
		i_reset              : in  std_logic;
		i_start              : in  std_logic;
		o_ready              : out std_logic;
		i_numInputFmaps      : in  std_logic_vector(15 downto 0);
		i_flatdim            : in  std_logic_vector(15 downto 0);
		i_data_bufnumlines   : in  std_logic_vector(15 downto 0);
		i_kernel_bufnumlines : in  std_logic_vector(15 downto 0);
		i_xDim               : in  std_logic_vector(15 downto 0);
		i_yDim               : in  std_logic_vector(15 downto 0);
		i_tileIterations     : in  std_logic_vector(15 downto 0);
		i_buffer_line        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_dread_base         : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		i_kernels            : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_kread_base         : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
		o_dbram_rd_en        : out std_logic;
		o_mac_reset          : out std_logic;
		o_mac_en             : out std_logic_vector(g_Pof * g_Poy * g_Pox - 1 downto 0);
		o_mac_weight         : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
		o_mac_input          : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);
		o_p2s_start          : out std_logic;
		i_p2s_busy           : in  std_logic
	);
end entity fclayer;

architecture rtl of fclayer is

	component up_counter
		generic(g_DataWidth : in integer);
		port(
			clk    : in  std_logic;
			reset  : in  std_logic;
			enable : in  std_logic;
			cout   : out std_logic_vector(g_DataWidth - 1 downto 0)
		);
	end component up_counter;

	component fclayer_router
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_DataW               : in integer;
			g_WeightW             : in integer;
			g_DataBramAddrWidth   : in integer;
			g_KernelBramAddrWidth : in integer
		);
		port(
			i_clk                : in  std_logic;
			i_reset              : in  std_logic;
			i_xDim               : in  std_logic_vector(15 downto 0);
			i_yDim               : in  std_logic_vector(15 downto 0);
			i_flatdim            : in  std_logic_vector(15 downto 0);
			i_data_bufnumlines   : in  std_logic_vector(15 downto 0);
			i_kernel_bufnumlines : in  std_logic_vector(15 downto 0);
			i_iterpos            : in  std_logic;
			i_itertile           : in  std_logic;
			i_buffer_line        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_kernels            : in  std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_dread_addr         : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
			o_kread_addr         : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
			o_ready              : out std_logic;
			o_mac_weights        : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_mac_inputs         : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0)
		);
	end component fclayer_router;

	signal clearPos, clearTile : std_logic;
	signal iPos                : std_logic_vector(15 downto 0);
	signal iTile               : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal enPos, enTile       : std_logic;

	signal mac_en_s : std_logic;

	signal iterpos_s, intertile_s         : std_logic;
	signal router_ready_s, router_reset_s : std_logic;

	type state_type is (IDLE, INIT, MAC, WAIT_P2S, ITER_TILE, START_P2S, ITER_POS, WAIT_ROUTER, WAIT_ROUTER_TILE, WAIT_ROUTER_IPOS);
	signal state, next_state : state_type;

begin

	router : component fclayer_router
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_DataW               => g_DataW,
			g_WeightW             => g_WeightW,
			g_DataBramAddrWidth   => g_DataBramAddrWidth,
			g_KernelBramAddrWidth => g_KernelBramAddrWidth
		)
		port map(
			i_clk                => i_clk,
			i_reset              => router_reset_s,
			i_xDim               => i_xDim,
			i_yDim               => i_yDim,
			i_flatdim            => i_flatdim,
			i_data_bufnumlines   => i_data_bufnumlines,
			i_kernel_bufnumlines => i_kernel_bufnumlines,
			i_iterpos            => iterpos_s,
			i_itertile           => intertile_s,
			i_buffer_line        => i_buffer_line,
			i_kernels            => i_kernels,
			o_dread_addr         => o_dread_base,
			o_kread_addr         => o_kread_base,
			o_ready              => router_ready_s,
			o_mac_weights        => o_mac_weight,
			o_mac_inputs         => o_mac_input
		);

	iterPos : up_counter
		generic map(
			g_DataWidth => 16
		)
		port map(
			clk    => i_clk,
			reset  => clearPos,
			enable => enPos,
			cout   => iPos
		);

	iterTile : up_counter
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => clearTile,
			enable => enTile,
			cout   => iTile
		);

	macen : for jj in g_Pof downto 1 generate
		o_mac_en(jj * g_Poy * g_Pox - 1)                                 <= mac_en_s;
		o_mac_en(jj * g_Poy * g_Pox - 2 downto (jj - 1) * g_Poy * g_Pox) <= (others => '0');
	end generate macen;

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

	next_state_decode : process(state, i_start, iTile, i_p2s_busy, i_tileIterations, iPos, router_ready_s, i_flatdim)
	begin
		next_state <= IDLE;
		case (state) is
			-- Initialization sequence
			when IDLE =>
				if i_start = '1' then
					next_state <= WAIT_ROUTER;
				else
					next_state <= IDLE;
				end if;
			when WAIT_ROUTER =>
				if router_ready_s = '1' then
					next_state <= INIT;
				else
					next_state <= WAIT_ROUTER;
				end if;
			when INIT =>
				next_state <= WAIT_ROUTER_IPOS;

			-- Iterate over Positions 
			when WAIT_ROUTER_IPOS =>
				if router_ready_s = '1' then
					next_state <= MAC;
				else
					next_state <= WAIT_ROUTER_IPOS;
				end if;
			when MAC =>
				if unsigned(iPos) < unsigned(i_flatdim) - 1 then
					next_state <= ITER_POS;
				else
					next_state <= START_P2S;
				end if;
			when ITER_POS =>
				next_state <= WAIT_ROUTER_IPOS;
			-- Transfer data to obuf using p2s serializer
			when START_P2S =>
				next_state <= WAIT_P2S;
			when WAIT_P2S =>
				if (i_p2s_busy = '0') then
					next_state <= ITER_TILE;
				else
					next_state <= WAIT_P2S;
				end if;
			-- Iterate over tiles
			when WAIT_ROUTER_TILE =>
				if router_ready_s = '1' then
					next_state <= ITER_TILE;
				else
					next_state <= WAIT_ROUTER_TILE;
				end if;
			when ITER_TILE =>
				if (unsigned(iTile) < unsigned(i_tileIterations) - 1) then
					next_state <= INIT;
				else
					next_state <= IDLE;
				end if;
		end case;
	end process;

	output_decode : process(state)
	begin
		case (state) is

			-- Initialization sequence
			when IDLE =>
				o_p2s_start    <= '0';
				o_ready        <= '1';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '1';
				enPos          <= '0';
				clearTile      <= '1';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '1';
			when WAIT_ROUTER =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '1';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';
			when INIT =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';

			-- Iterate over Positions 								
			when WAIT_ROUTER_IPOS =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';
			when MAC =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '1';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';
			when ITER_POS =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '1';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '1';
				intertile_s    <= '0';
				router_reset_s <= '0';
			-- Transfer data to obuf using p2s serializer	
			when START_P2S =>
				o_p2s_start    <= '1';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';
			when WAIT_P2S =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';

			-- Iterate over tiles
			when WAIT_ROUTER_TILE =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '0';
				mac_en_s       <= '0';
				clearPos       <= '0';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '0';
				iterpos_s      <= '0';
				intertile_s    <= '0';
				router_reset_s <= '0';
			when ITER_TILE =>
				o_p2s_start    <= '0';
				o_ready        <= '0';
				o_mac_reset    <= '1';
				mac_en_s       <= '0';
				clearPos       <= '1';
				enPos          <= '0';
				clearTile      <= '0';
				enTile         <= '1';
				iterpos_s      <= '0';
				intertile_s    <= '1';
				router_reset_s <= '0';
		end case;
	end process;

end rtl;
