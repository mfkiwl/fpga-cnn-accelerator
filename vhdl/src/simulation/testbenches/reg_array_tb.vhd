library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_array_tb is
end entity;

architecture simulate OF reg_array_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------

	constant clock_period : time    := 20 ns;
	constant Xparallelism : integer := 5;

	component reg_array
		generic(
			g_Pox   : integer;
			g_DataW : integer
		);
		port(
			i_clk       : in  std_logic;
			i_reset     : in  std_logic;
			i_en        : in  std_logic;
			i_init_mode : in  std_logic;
			i_padding   : in  std_logic_vector(2 downto 0);
			i_init_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			i_pixel     : in  std_logic_vector(g_DataW - 1 downto 0);
			i_fifo_mode : in  std_logic;
			i_fifo_data : in  std_logic_vector(g_Pox * g_DataW - 1 downto 0);
			o_data      : out std_logic_vector(g_Pox * g_DataW - 1 downto 0)
		);
	end component reg_array;

	-- Clock, Reset and Enable.
	signal clk_s   : std_logic;
	signal reset_s : std_logic;
	signal en_s    : std_logic;

	-- Init control and input data
	signal init_mode_s : std_logic;
	signal padding_s   : std_logic_vector(2 downto 0) := "001";
	signal init_data_s : std_logic_vector(Xparallelism * 16 - 1 downto 0);

	-- Rightmost shif input
	signal pixel_s : std_logic_vector(16 - 1 downto 0);

	-- Fifo control and data
	signal fifo_mode_s : std_logic;
	signal fifo_data_s : std_logic_vector(Xparallelism * 16 - 1 downto 0);

	-- Output data
	signal data_s : std_logic_vector(Xparallelism * 16 - 1 downto 0);

begin
	uut : reg_array
		generic map(
			g_Pox   => Xparallelism,
			g_DataW => 16
		)
		port map(
			i_clk       => clk_s,
			i_reset     => reset_s,
			i_en        => en_s,
			i_init_mode => init_mode_s,
			i_padding   => padding_s,
			i_init_data => init_data_s,
			i_pixel     => pixel_s,
			i_fifo_mode => fifo_mode_s,
			i_fifo_data => fifo_data_s,
			o_data      => data_s
		);

	clock_process : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process;

	stimulus : process
	begin
		-----------------------------------------------------
		---Provide stimulus in this section. (not shown here) 
		-----------------------------------------------------
		wait for clock_period;
		reset_s     <= '1';
		en_s        <= '0';
		padding_s   <= "000";
		init_mode_s <= '0';
		init_data_s <= (others => '0');
		pixel_s     <= (others => '0');
		fifo_mode_s <= '0';
		fifo_data_s <= (others => '0');

		wait for clock_period;
		reset_s <= '0';

		wait for clock_period;
		init_mode_s <= '1';
		padding_s   <= "100";
		en_s        <= '1';
		init_data_s <= std_logic_vector(to_unsigned(5, 16) & to_unsigned(6, 16) & to_unsigned(7, 16) & to_unsigned(8, 16) & to_unsigned(9, 16));

--		wait for clock_period;
--		padding_s   <= "010";
--		
--		wait for clock_period;
--		padding_s   <= "001";
				
		wait for clock_period;
		en_s        <= '1';
		init_mode_s <= '0';
--		padding_s   <= "000";
		pixel_s     <= x"DADA";

		wait for clock_period;
		pixel_s <= x"BABA";

		wait for clock_period;
		fifo_mode_s <= '1';
		fifo_data_s <= x"11112222333344445555";

		wait for clock_period;
		fifo_data_s <= x"6666777788889999AAAA";

		wait for clock_period;
		fifo_data_s <= x"BBBBCCCCDDDDEEEEFFFF";

		wait for clock_period;
		fifo_data_s <= x"00000000000000000000";

		wait for clock_period;
		fifo_data_s <= x"FFFFFFFFFFFFFFFFFFFF";

		wait for clock_period;
		fifo_mode_s <= '0';

		wait for 5 * clock_period;
		en_s    <= '0';
		reset_s <= '1';

		wait for clock_period;
		reset_s <= '0';

		wait;
	end process;                        -- stimulus

end simulate;
