library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fclayer_router is
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
end entity fclayer_router;

architecture RTL of fclayer_router is

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

	component shifter
		generic(
			g_Depth : integer;
			g_DataW : integer
		);
		port(
			i_clk      : in  std_logic;
			i_reset    : in  std_logic;
			i_init     : in  std_logic;
			i_initdata : in  std_logic_vector(g_Depth * g_DataW - 1 downto 0);
			i_shift    : in  std_logic;
			o_output   : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component shifter;

	-- linePos Counter 
	signal dlinePos                  : std_logic_vector(15 downto 0);
	signal dlinePos_clr, dlinePos_en : std_logic;

	-- Data-address accumulators
	signal dlineAddrOffset_clr, dlineAddrOffset_en : std_logic;
	signal dlineAddrOffset, dlineAddrOffset_shift  : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);

	signal dtileDataAddrOffset_clr, dtileDataAddrOffset_en : std_logic;
	signal dtileDataAddrOffset, dtileDataAddrOffset_shift  : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);

	-- Kernel-address accumulators
	signal klineAddrOffset_clr, klineAddrOffset_en : std_logic;
	signal klineAddrOffset, klineAddrOffset_shift  : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

	signal ktileAddrOffset_clr, ktileAddrOffset_en : std_logic;
	signal ktileAddrOffset, ktileAddrOffset_shift  : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

	signal dshift_init    : std_logic;
	signal kvalid, dvalid : std_logic;
	signal dshift_en      : std_logic;
	signal dshift_curdata : std_logic_vector(g_DataW - 1 downto 0);

	type data_state is (dRESET, dINIT, dIDLE, ITER_dLINE, ITER_dPOS, ITER_dTILE, WAIT_dBRAM, WAIT_dSHIFTER);
	signal dstate, next_dstate : data_state;

	type kernel_state is (kRESET, kINIT, kIDLE, ITER_kPOS, ITER_kTILE, WAIT_kBRAM, WAIT_kSHIFTER);
	signal kstate, next_kstate : kernel_state;

begin

	dlinePosCtr : up_counter
		generic map(
			g_DataWidth => 16
		)
		port map(
			clk    => i_clk,
			reset  => dlinePos_clr,
			enable => dlinePos_en,
			cout   => dlinePos
		);

	dataLineAddr : accumulator
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => dlineAddrOffset_clr,
			enable => dlineAddrOffset_en,
			din    => dlineAddrOffset_shift,
			q      => dlineAddrOffset
		);

	dataTileAddr : accumulator
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => dtileDataAddrOffset_clr,
			enable => dtileDataAddrOffset_en,
			din    => dtileDataAddrOffset_shift,
			q      => dtileDataAddrOffset
		);

	kernelLineAddr : accumulator
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => klineAddrOffset_clr,
			enable => klineAddrOffset_en,
			din    => klineAddrOffset_shift,
			q      => klineAddrOffset
		);

	kernelTileAddr : accumulator
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => ktileAddrOffset_clr,
			enable => ktileAddrOffset_en,
			din    => ktileAddrOffset_shift,
			q      => ktileAddrOffset
		);

	-- Combine signals from both FSMs below
	o_ready <= dvalid and kvalid;

	-- - - - - - - - - - - - - - - - - - 
	-- Data Addresses Generation FSM
	-- - - - - - - - - - - - - - - - - - -
	o_dread_addr              <= std_logic_vector(unsigned(dlineAddrOffset));
	dlineAddrOffset_shift     <= std_logic_vector(to_unsigned(1, g_DataBramAddrWidth));
	dtileDataAddrOffset_shift <= std_logic_vector(to_unsigned(to_integer(unsigned(i_data_bufnumlines)), g_DataBramAddrWidth));

	sync_dproc : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_reset = '1') then
				dstate <= dRESET;
			else
				dstate <= next_dstate;
			end if;
		end if;
	end process;

	next_dstate_decode : process(dstate, dlinePos, i_iterpos, i_itertile)
	begin
		case (dstate) is
			when dRESET =>
				next_dstate <= dINIT;
			when dINIT =>
				next_dstate <= dIDLE;
			when dIDLE =>
				if i_iterpos = '1' then
					next_dstate <= ITER_dPOS;
				elsif i_itertile = '1' then
					next_dstate <= ITER_dTILE;
				else
					next_dstate <= dIDLE;
				end if;
			when ITER_dPOS =>
				if unsigned(dlinePos) = to_unsigned(g_Pox * g_Poy, 16) - 1 then
					next_dstate <= ITER_dLINE;
				else
					next_dstate <= dIDLE;
				end if;
			when ITER_dLINE =>
				next_dstate <= WAIT_dBRAM;
			when ITER_dTILE =>
				next_dstate <= WAIT_dBRAM;
			when WAIT_dBRAM =>
				next_dstate <= WAIT_dSHIFTER;
			when WAIT_dSHIFTER =>
				next_dstate <= dIDLE;
		end case;
	end process;

	doutput_decode : process(dstate)
	begin
		case (dstate) is
			when dRESET =>
				dlinePos_clr            <= '1';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '1';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '1';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '0';
				dshift_en               <= '0';
				dvalid                  <= '0';
			when dINIT =>
				dlinePos_clr            <= '0';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '1';
				dshift_en               <= '0';
				dvalid                  <= '0';
			when dIDLE =>
				dlinePos_clr            <= '0';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '0';
				dshift_en               <= '0';
				dvalid                  <= '1';
			when ITER_dPOS =>
				dlinePos_clr            <= '0';
				dlinePos_en             <= '1';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '0';
				dshift_en               <= '1';
				dvalid                  <= '0';
			when ITER_dLINE =>
				dlinePos_clr            <= '1';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '1';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '0';
				dshift_en               <= '0';
				dvalid                  <= '0';
			when ITER_dTILE =>
				dlinePos_clr            <= '1';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '1';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '1';
				dshift_init             <= '0';
				dshift_en               <= '0';
				dvalid                  <= '0';
			when WAIT_dBRAM =>
				dlinePos_clr            <= '0';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '0';
				dshift_en               <= '0';
				dvalid                  <= '0';
			when WAIT_dSHIFTER =>
				dlinePos_clr            <= '0';
				dlinePos_en             <= '0';
				dlineAddrOffset_clr     <= '0';
				dlineAddrOffset_en      <= '0';
				dtileDataAddrOffset_clr <= '0';
				dtileDataAddrOffset_en  <= '0';
				dshift_init             <= '1';
				dshift_en               <= '0';
				dvalid                  <= '0';
		end case;
	end process;

	-- - - - - - - - - - - - - - - - - - 
	-- Kernel Addresses Generation FSM
	-- - - - - - - - - - - - - - - - - - -	

	o_kread_addr          <= std_logic_vector(unsigned(klineAddrOffset) + unsigned(ktileAddrOffset));
	klineAddrOffset_shift <= std_logic_vector(to_unsigned(1, g_KernelBramAddrWidth));
	ktileAddrOffset_shift <= std_logic_vector(to_unsigned(to_integer(unsigned(i_kernel_bufnumlines)), g_KernelBramAddrWidth));

	sync_kproc : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if (i_reset = '1') then
				kstate <= kRESET;
			else
				kstate <= next_kstate;
			end if;
		end if;
	end process;

	next_lstate_decode : process(kstate, i_iterpos, i_itertile)
	begin
		case (kstate) is
			when kRESET =>
				next_kstate <= kINIT;
			when kINIT =>
				next_kstate <= kIDLE;
			when kIDLE =>
				if i_iterpos = '1' then
					next_kstate <= ITER_kPOS;
				elsif i_itertile = '1' then
					next_kstate <= ITER_kTILE;
				else
					next_kstate <= kIDLE;
				end if;
			when ITER_kPOS =>
				next_kstate <= WAIT_kBRAM;
			when ITER_kTILE =>
				next_kstate <= WAIT_kBRAM;
			when WAIT_kBRAM =>
				next_kstate <= WAIT_kSHIFTER;
			when WAIT_kSHIFTER =>
				next_kstate <= kIDLE;
		end case;
	end process;

	koutput_decode : process(kstate)
	begin
		case (kstate) is
			when kRESET =>
				klineAddrOffset_clr <= '1';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '1';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '0';
			when kINIT =>
				klineAddrOffset_clr <= '0';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '0';
			when kIDLE =>
				klineAddrOffset_clr <= '0';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '1';
			when ITER_kPOS =>
				klineAddrOffset_clr <= '0';
				klineAddrOffset_en  <= '1';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '0';
			when ITER_kTILE =>
				klineAddrOffset_clr <= '1';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '1';
				kvalid              <= '0';
			when WAIT_kBRAM =>
				klineAddrOffset_clr <= '0';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '0';
			when WAIT_kSHIFTER =>
				klineAddrOffset_clr <= '0';
				klineAddrOffset_en  <= '0';
				ktileAddrOffset_clr <= '0';
				ktileAddrOffset_en  <= '0';
				kvalid              <= '0';
		end case;
	end process;

	-- - - - - - - - - - - - - - - - - - - 
	-- Shifters
	-- - - - - - - - - - - - - - - - - - -
	o_mac_weights <= i_kernels;

	dataShift : shifter
		generic map(
			g_Depth => g_Pox * g_Poy,
			g_DataW => g_DataW
		)
		port map(
			i_clk      => i_clk,
			i_reset    => i_reset,
			i_init     => dshift_init,
			i_initdata => i_buffer_line,
			i_shift    => dshift_en,
			o_output   => dshift_curdata
		);

	macdata : for jj in g_Pof * g_Poy * g_Pox downto 1 generate
		o_mac_inputs(jj * g_DataW - 1 downto (jj - 1) * g_DataW) <= dshift_curdata;
	end generate macdata;

end architecture RTL;
