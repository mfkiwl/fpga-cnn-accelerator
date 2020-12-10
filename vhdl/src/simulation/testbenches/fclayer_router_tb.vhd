library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fclayer_router_tb is
end entity fclayer_router_tb;

architecture RTL of fclayer_router_tb is

	constant clock_period : time := 20 ns;

	constant g_Pox        : integer := 3;
	constant g_Poy        : integer := 3;
	constant g_Pof        : integer := 3;
	constant g_NumBuffers : integer := 3;
	constant g_DataW      : integer := 16;
	constant g_KernelSize : integer := 9;
	constant g_WeightW    : integer := 16;

	component fclayer_router
		generic(
			g_Pox        : in integer;
			g_Poy        : in integer;
			g_Pof        : in integer;
			g_NumBuffers : in integer;
			g_DataW      : in integer;
			g_KernelSize : in integer;
			g_WeightW    : in integer
		);
		port(
			i_clk                : in  std_logic;
			i_reset              : in  std_logic;
			i_xDim               : in  std_logic_vector(15 downto 0);
			i_yDim               : in  std_logic_vector(15 downto 0);
			i_numDataBufflines   : in  std_logic_vector(15 downto 0);
			i_numDElemPerBuffline : in  std_logic_vector(15 downto 0);
			i_numKernelBufflines : in  std_logic_vector(15 downto 0);
			i_iterfmap           : in  std_logic;
			i_iterpos            : in  std_logic;
			i_itertile           : in  std_logic;
			i_buffer_line        : in  std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
			i_kernels            : in  std_logic_vector(g_Pof * g_KernelSize * g_WeightW - 1 downto 0);
			o_dread_addr         : out std_logic_vector(15 downto 0);
			o_kread_addr         : out std_logic_vector(15 downto 0);
			o_ready              : out std_logic;
			o_mac_weights        : out std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
			o_mac_inputs         : out std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0)
		);
	end component fclayer_router;

	signal clk_s                : std_logic;
	signal reset_s              : std_logic;
	signal xDim_s               : std_logic_vector(15 downto 0);
	signal yDim_s               : std_logic_vector(15 downto 0);
	signal numDataBufflines_s   : std_logic_vector(15 downto 0);
	signal numKernelBufflines_s : std_logic_vector(15 downto 0);
	signal interpos_s           : std_logic;
	signal iterfmap_s            : std_logic;
	signal itertile_s           : std_logic;
	signal dread_addr_s         : std_logic_vector(15 downto 0);
	signal kread_addr_s         : std_logic_vector(15 downto 0);
	signal ready_s              : std_logic;
	signal mac_weights_s        : std_logic_vector(g_Pof * g_WeightW - 1 downto 0);
	signal mac_inputs_s         : std_logic_vector(g_Pof * g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal numDElemPerBuffline_s : std_logic_vector(15 downto 0);
	signal buffer_line_s        : std_logic_vector(g_Poy * g_Pox * g_DataW - 1 downto 0);
	signal kernels_s            : std_logic_vector(g_Pof * g_KernelSize * g_WeightW - 1 downto 0);

begin

	clock_driver : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process clock_driver;

	uut : fclayer_router
		generic map(
			g_Pox        => g_Pox,
			g_Poy        => g_Poy,
			g_Pof        => g_Pof,
			g_NumBuffers => g_NumBuffers,
			g_DataW      => g_DataW,
			g_KernelSize => g_KernelSize,
			g_WeightW    => g_WeightW
		)
		port map(
			i_clk                => clk_s,
			i_reset              => reset_s,
			i_xDim               => xDim_s,
			i_yDim               => yDim_s,
			i_numDataBufflines   => numDataBufflines_s,
			i_numDElemPerBuffline => numDElemPerBuffline_s,
			i_numKernelBufflines => numKernelBufflines_s,
			i_iterfmap           => iterfmap_s,
			i_iterpos            => interpos_s,
			i_itertile           => itertile_s,
			i_buffer_line        => buffer_line_s,
			i_kernels            => kernels_s,
			o_dread_addr         => dread_addr_s,
			o_kread_addr         => kread_addr_s,
			o_ready              => ready_s,
			o_mac_weights        => mac_weights_s,
			o_mac_inputs         => mac_inputs_s
		);

	test : process is
	begin
		reset_s              <= '1';
		xDim_s               <= std_logic_vector(to_unsigned(7, 16));
		yDim_s               <= std_logic_vector(to_unsigned(7, 16));
		numDataBufflines_s   <= std_logic_vector(to_unsigned(2, 16));
		numDElemPerBuffline_s <= std_logic_vector(to_unsigned(7, 16));
		numKernelBufflines_s <= std_logic_vector(to_unsigned(7, 16));
		interpos_s           <= '0';
		iterfmap_s            <= '0';
		itertile_s           <= '0';
		buffer_line_s <= x"000100020003000400050006000700080009";
		wait for clock_period;

		reset_s <= '0';
		wait for 10*clock_period;

		interpos_s <= '1';
		wait for 7 * clock_period;

		interpos_s <= '0';
		wait for 7 * clock_period;
		wait for clock_period;

		iterfmap_s  <= '0';
		interpos_s <= '1';

		wait for 7 * clock_period;

		iterfmap_s  <= '0';
		interpos_s <= '0';
		itertile_s <= '0';

		wait for 10 * clock_period;
		itertile_s <= '1';
		
		wait for clock_period;
		itertile_s <= '0';
		
		wait for 10*clock_period;
		iterfmap_s <= '1';
		
		wait for clock_period;
		iterfmap_s <= '0';
		wait;
	end process test;

end architecture RTL;
