library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity conv_tb is
end entity;

architecture simulate OF conv_tb is
	----------------------------------------------------
	--- The parent design, MAC, is instantiated
	--- in this testbench. Note the component
	--- declaration and the instantiation.
	----------------------------------------------------

	constant X_Dim : integer := 300;
	constant Y_Dim : integer := 225;

	constant clock_period : time    := 20 ns;
	constant Xparallelism : integer := 15;
	constant Yparallelism : integer := 15;
	constant DataWidth    : integer := 16;
	constant WeightWidth  : integer := 16;
	constant RamDepth     : integer := 25000;

	component conv3x3_S1_P1_ctrl
		generic(
			g_Pox     : integer := 3;
			g_Poy     : integer := 4;
			g_DataW   : integer := 16;
			g_WeightW : integer := 16
		);
		port(
			i_clk         : in  std_logic;
			i_reset       : in  std_logic;
			i_buffer_line : in  std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
			-- i_kernel == 9 <-> number of kernel entries
			i_kernel      : in  std_logic_vector(9 * WeightWidth - 1 downto 0);
			o_readaddr    : out std_logic_vector(15 downto 0);
			o_readen      : out std_logic;
			i_start       : in  std_logic;
			i_en_padding  : in  std_logic;
			o_busy        : out std_logic;
			o_result      : out std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0)
		);
	end component conv3x3_S1_P1_ctrl;

	component ram_infer IS
		generic(
			Pox      : integer;
			Poy      : integer;
			DWidth   : integer;
			RamDepth : integer
		);
		port(
			clock         : in  std_logic;
			data          : in  std_logic_vector(Pox * Poy * DWidth - 1 DOWNTO 0);
			write_address : in  integer;
			read_address  : in  integer;
			we            : in  std_logic;
			q             : out std_logic_vector(Pox * Poy * DWidth - 1 DOWNTO 0)
		);
	end component;

	signal bram_wr_en      : std_logic;
	signal bram_wr_data    : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal bram_rd_data    : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal bram_wr_address : integer;
	signal bram_rd_address : integer;
	signal bram_cur_offset : integer := 0;

	signal clk_s         : std_logic;
	signal reset_s       : std_logic;
	signal buffer_line_s : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
	signal kernel_s      : std_logic_vector(9 * WeightWidth - 1 downto 0);
	signal readaddr_s    : std_logic_vector(15 downto 0);
	signal readen_s      : std_logic;
	signal start_s       : std_logic;
	signal busy_s        : std_logic;
	signal padding_s     : std_logic;
	signal result_s      : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);

	signal readaddr_temp_s : integer;

	file file_VECTORS : text;
	file file_RESULTS : text;
	signal bram_ready : std_logic;

begin

	uut : conv3x3_S1_P1_ctrl
		generic map(
			g_Pox     => Xparallelism,
			g_Poy     => Yparallelism,
			g_DataW   => DataWidth,
			g_WeightW => WeightWidth
		)
		port map(
			i_clk         => clk_s,
			i_reset       => reset_s,
			i_buffer_line => buffer_line_s,
			i_kernel      => kernel_s,
			o_readaddr    => readaddr_s,
			o_readen      => readen_s,
			i_start       => start_s,
			i_en_padding  => padding_s,
			o_busy        => busy_s,
			o_result      => result_s
		);

	brami : ram_infer
		generic map(
			Pox      => Xparallelism,
			Poy      => Yparallelism,
			DWidth   => DataWidth,
			RamDepth => RamDepth
		)
		port map(
			clock         => clk_s,
			data          => bram_wr_data,
			write_address => bram_wr_address,
			read_address  => bram_rd_address,
			we            => bram_wr_en,
			q             => bram_rd_data
		);

	clock_process : process
	begin
		clk_s <= '0';
		wait for clock_period / 2;
		clk_s <= '1';
		wait for clock_period / 2;
	end process;

	--kernel_s <= x"FFFE00000001FFFE00000002FFFF00000001";
	kernel_s        <= x"FFFE00000001FFFE00000002FFFF00000001";
	buffer_line_s   <= bram_rd_data;
	bram_rd_address <= to_integer(unsigned(readaddr_s)) + readaddr_temp_s;

	convolverFSM : process
		variable v_OLINE : line;
		variable ok      : boolean;
		variable Xpos    : integer := 0;
		variable YPos    : integer := 0;

		variable iterX     : integer := 0;
		variable iterY     : integer := 0;
		variable iterTotal : integer := 0;

		variable iterCount : integer := 0;
		variable offset    : integer := 0;
		variable temp      : integer := 0;

	begin
		readaddr_temp_s <= 0;
		wait until bram_ready = '1';

		file_open(file_RESULTS, "output_results.txt", write_mode);
		iterX     := (X_Dim + (Xparallelism - 1)) / Xparallelism;
		iterY     := (Y_Dim + (Yparallelism - 1)) / Yparallelism;
		iterTotal := iterX + iterY;
		offset    := 0;

		for iX in 1 to iterX loop
			for jY in 1 to iterY loop

				wait for clock_period;
				reset_s         <= '1';
				readaddr_temp_s <= offset;

				if (iX = 1) then
					padding_s <= '1';
				else
					padding_s <= '0';
				end if;

				wait for clock_period;
				reset_s <= '0';
				start_s <= '1';

				wait for clock_period;
				start_s <= '0';

				wait until busy_s = '0';
				wait for clock_period;

				hwrite(v_OLINE, result_s, left, Yparallelism * Xparallelism * DataWidth);
				writeline(file_RESULTS, v_OLINE);

				if (jY = iterY) then
					offset := offset + 4;
				else
					offset := offset + 2;
				end if;
				iterCount := iterCount + 1;

			end loop;
		end loop;
		wait;
	end process;                        -- convolverFSM

	---------------------------------------------------------------------------
	-- This procedure reads the file input_vectors.txt which is located in the
	-- simulation project area.
	-- It will read the data in and send it to the ripple-adder component
	-- to perform the operations.  The result is written to the
	-- output_results.txt file, located in the same directory.
	---------------------------------------------------------------------------
	process
		variable v_ILINE : line;
		variable v_OLINE : line;
		variable v_LINE  : std_logic_vector(Yparallelism * Xparallelism * DataWidth - 1 downto 0);
		variable v_SPACE : character;
	begin
		bram_ready      <= '0';
		bram_wr_en      <= '1';
		file_open(file_VECTORS, "bram.txt", read_mode);
		bram_wr_address <= 0;
		while not endfile(file_VECTORS) loop
			readline(file_VECTORS, v_ILINE);
			hread(v_ILINE, v_LINE);
			bram_wr_data    <= v_LINE;
			wait for clock_period;
			bram_wr_address <= bram_wr_address + 1;
		end loop;
		bram_wr_en      <= '0';
		bram_ready      <= '1';
		file_close(file_VECTORS);
		wait;
	end process;

end simulate;

