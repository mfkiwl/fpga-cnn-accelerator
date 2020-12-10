library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooler is
	generic(
		g_Pox                 : in integer := 3;
		g_Poy                 : in integer := 3;
		g_Pof                 : in integer := 3;
		g_NumBuffers          : in integer := 3;
		g_DataW               : in integer := 16;
		g_OutputBramAddrWidth : in integer := 16
	);
	port(
		i_clk               : in  std_logic;
		i_reset             : in  std_logic;
		i_start             : in  std_logic;
		o_ready             : out std_logic;
		i_xDim              : in  std_logic_vector(15 downto 0);
		i_yDim              : in  std_logic_vector(15 downto 0);
		i_numOutbufFmaps    : in  std_logic_vector(15 downto 0);
		i_outFmapBuflines   : in  std_logic_vector(15 downto 0);
		i_tileIterations    : in  std_logic_vector(15 downto 0);
		i_buffer_line       : in  std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
		o_outbuf_rd_address : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
		o_outbuf_rd_en      : out std_logic_vector(g_NumBuffers - 1 downto 0);
		o_buffer_line       : out std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
		o_outbuf_wr_address : out std_logic_vector(g_NumBuffers * g_OutputBramAddrWidth - 1 downto 0);
		o_outbuf_wr_en      : out std_logic_vector(g_NumBuffers - 1 downto 0)
	);
end entity pooler;

architecture RTL of pooler is

	component max_pool_array
		generic(
			g_Pox       : integer;
			g_DataWidth : integer
		);
		port(
			i_clk    : in  std_logic;
			i_reset  : in  std_logic;
			i_enable : in  std_logic;
			i_clear  : in  std_logic;
			i_data   : in  std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
			o_result : out std_logic_vector(g_Pox * g_DataWidth - 1 downto 0)
		);
	end component max_pool_array;

	component pooler_registers
		generic(
			g_Pox       : integer;
			g_DataWidth : integer
		);
		port(
			i_clk      : in  std_logic;
			i_reset    : in  std_logic;
			i_wrdata   : in  std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
			i_wrlineen : in  std_logic_vector(3 downto 0);
			o_line1    : out std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
			o_line2    : out std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
			o_line3    : out std_logic_vector(g_Pox * g_DataWidth - 1 downto 0);
			o_line4    : out std_logic_vector(g_Pox * g_DataWidth - 1 downto 0)
		);
	end component pooler_registers;

	component pooler_addr_gen
		generic(
			g_Pox                 : in integer;
			g_Poy                 : in integer;
			g_Pof                 : in integer;
			g_NumBuffers          : in integer;
			g_DataW               : in integer;
			g_OutputBramAddrWidth : in integer
		);
		port(
			i_clk         : in  std_logic;
			i_reset       : in  std_logic;
			i_incr_rd     : in  std_logic;
			o_valid_rd    : out std_logic;
			i_incr_wr     : in  std_logic;
			i_xDim        : in  std_logic_vector(15 downto 0);
			i_yDim        : in  std_logic_vector(15 downto 0);
			i_addroffset  : in  std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
			o_line_wraddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
			o_line1_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
			o_line2_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
			o_line3_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
			o_line4_raddr : out std_logic_vector(g_OutputBramAddrWidth - 1 downto 0)
		);
	end component pooler_addr_gen;

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

	-- iter counters
	signal clearFmap, clearTile : std_logic;
	signal iFmap, iTile         : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0); -- TODO: if OutputBRAM smaller than kernelBRAM -> overflow
	signal enFmap, enTile       : std_logic;

	-- tile address accumulator
	signal enTileAddrOffset, clearTileAddrOffset : std_logic;
	signal tileAddrOffset                        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);

	-- max-pool array
	signal poolers_en_s     : std_logic;
	signal poolers_datain_s : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal poolers_clear_s  : std_logic;

	-- pooling-regs 
	signal regarr_wrlineen : std_logic_vector(3 downto 0);
	signal regarr_line1    : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal regarr_line2    : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal regarr_line3    : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);
	signal regarr_line4    : std_logic_vector(g_NumBuffers * g_Pox * g_DataW - 1 downto 0);

	-- addrgen
	signal addrgen_reset           : std_logic;
	signal addrgen_fmap_addroffset : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal addrgen_ovalid          : std_logic;
	signal addrgen_incr_wr         : std_logic;
	signal addrgen_incr_rd         : std_logic;
	signal addrgen_raddr_l1        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal addrgen_raddr_l2        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal addrgen_raddr_l3        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal addrgen_raddr_l4        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);

	-- outbuf 
	signal outbuf_rd_en          : std_logic;
	signal outbuf_wr_en          : std_logic;
	signal outbuf_rd_addr_offset : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal outbuf_rd_addr        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal outbuf_wr_addr_offset : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	signal outbuf_wr_addr        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);
	
	--Temporary signals
	signal outFmapBuflines_s        : std_logic_vector(g_OutputBramAddrWidth - 1 downto 0);

	-- FSM
	type state_type is (IDLE, INIT, INIT_REQUEST_L1, INIT_WRITE_L1, INIT_WRITE_L2, INIT_POOL1, POOL1, POOL2, POOL3, POOL4, FINAL_WR_OBUF, ITER_FMAP, ITER_TILE);
	signal state, next_state : state_type;

begin

	addrgen_fmap_addroffset <= iFmap;

	outbuf_rd_addr <= std_logic_vector(unsigned(outbuf_rd_addr_offset) + unsigned(tileAddrOffset));
	outbuf_wr_addr <= std_logic_vector(unsigned(outbuf_wr_addr_offset) + unsigned(tileAddrOffset));
	
	outFmapBuflines_s <= std_logic_vector(to_unsigned(to_integer(unsigned(i_outFmapBuflines)), g_OutputBramAddrWidth));

	iterTilectr : up_counter
		generic map(
			g_DataWidth => g_OutputBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => clearTile,
			enable => enTile,
			cout   => iTile
		);

	iterFmapctr : up_counter
		generic map(
			g_DataWidth => g_OutputBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => clearFmap,
			enable => enFmap,
			cout   => iFmap
		);

	tileOffset : component accumulator
		generic map(
			g_DataWidth => g_OutputBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => clearTileAddrOffset,
			enable => enTileAddrOffset,
			din    => outFmapBuflines_s,
			q      => tileAddrOffset
		);

	gen_wr : for jj in g_NumBuffers downto 1 generate
	begin
		o_outbuf_rd_en(jj - 1)                                                                      <= outbuf_rd_en;
		o_outbuf_wr_en(jj - 1)                                                                      <= outbuf_wr_en;
		o_outbuf_rd_address(jj * g_OutputBramAddrWidth - 1 downto (jj - 1) * g_OutputBramAddrWidth) <= outbuf_rd_addr;
		o_outbuf_wr_address(jj * g_OutputBramAddrWidth - 1 downto (jj - 1) * g_OutputBramAddrWidth) <= outbuf_wr_addr;
	end generate;

	g1 : for jj in g_NumBuffers downto 1 generate
	begin
		mp : max_pool_array
			generic map(
				g_Pox       => g_Pox,
				g_DataWidth => g_DataW
			)
			port map(
				i_clk    => i_clk,
				i_reset  => i_reset,
				i_enable => poolers_en_s,
				i_clear  => poolers_clear_s,
				i_data   => poolers_datain_s(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				o_result => o_buffer_line(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW)
			);

		poolregs : pooler_registers
			generic map(
				g_Pox       => g_Pox,
				g_DataWidth => g_DataW
			)
			port map(
				i_clk      => i_clk,
				i_reset    => i_reset,
				i_wrdata   => i_buffer_line(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				i_wrlineen => regarr_wrlineen,
				o_line1    => regarr_line1(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				o_line2    => regarr_line2(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				o_line3    => regarr_line3(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW),
				o_line4    => regarr_line4(jj * g_Pox * g_DataW - 1 downto (jj - 1) * g_Pox * g_DataW)
			);
	end generate;
	
	addrgen : component pooler_addr_gen
		generic map(
			g_Pox                 => g_Pox,
			g_Poy                 => g_Poy,
			g_Pof                 => g_Pof,
			g_NumBuffers          => g_NumBuffers,
			g_DataW               => g_DataW,
			g_OutputBramAddrWidth => g_OutputBramAddrWidth
		)
		port map(
			i_clk         => i_clk,
			i_reset       => addrgen_reset,
			i_incr_rd     => addrgen_incr_rd,
			o_valid_rd    => addrgen_ovalid,
			i_incr_wr     => addrgen_incr_wr,
			i_xDim        => i_xDim,
			i_yDim        => i_yDim,
			i_addroffset  => addrgen_fmap_addroffset,
			o_line_wraddr => outbuf_wr_addr_offset,
			o_line1_raddr => addrgen_raddr_l1,
			o_line2_raddr => addrgen_raddr_l2,
			o_line3_raddr => addrgen_raddr_l3,
			o_line4_raddr => addrgen_raddr_l4
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

	next_state_decode : process(state, i_start, addrgen_ovalid, iFmap, iTile, i_numOutbufFmaps, i_tileIterations)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= INIT;
				else
					next_state <= IDLE;
				end if;
			when INIT =>
				next_state <= INIT_REQUEST_L1;
			when INIT_REQUEST_L1 =>
				next_state <= INIT_WRITE_L1;
			when INIT_WRITE_L1 =>
				next_state <= INIT_WRITE_L2;
			when INIT_WRITE_L2 =>
				next_state <= INIT_POOL1;
			when INIT_POOL1 =>
				next_state <= POOL2;
			when POOL1 =>
				next_state <= POOL2;
			when POOL2 =>
				next_state <= POOL3;
			when POOL3 =>
				next_state <= POOL4;
			when POOL4 =>
				if addrgen_ovalid = '1' then
					next_state <= POOL1;
				else
					next_state <= FINAL_WR_OBUF;
				end if;
			when FINAL_WR_OBUF =>
				next_state <= ITER_FMAP;
			when ITER_FMAP =>
				if (unsigned(iFmap) = unsigned(i_numOutbufFmaps) - 1) then
					next_state <= ITER_TILE;
				else
					next_state <= INIT;
				end if;
			when ITER_TILE =>
				if (unsigned(iTile) = unsigned(i_tileIterations) - 1) then
					next_state <= IDLE;
				else
					next_state <= INIT;
				end if;
		end case;
	end process;

	output_decode : process(state, addrgen_raddr_l1, addrgen_raddr_l2, addrgen_raddr_l3, addrgen_raddr_l4, regarr_line1, regarr_line2, regarr_line3, regarr_line4)
	begin
		case (state) is
			when IDLE =>
				addrgen_reset         <= '1';
				clearFmap             <= '1';
				clearTile             <= '1';
				clearTileAddrOffset   <= '1';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '0';
				outbuf_rd_addr_offset <= (others => '0');
				regarr_wrlineen       <= "0000";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '1';
			when INIT =>
				addrgen_reset         <= '1';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '0';
				outbuf_rd_addr_offset <= (others => '0');
				regarr_wrlineen       <= "0000";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when INIT_REQUEST_L1 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l1;
				regarr_wrlineen       <= "0000";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when INIT_WRITE_L1 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l2;
				regarr_wrlineen       <= "0001";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when INIT_WRITE_L2 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l3;
				regarr_wrlineen       <= "0010";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when INIT_POOL1 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '1';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l4;
				regarr_wrlineen       <= "0100";
				poolers_datain_s      <= regarr_line1;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '1';
				outbuf_wr_en          <= '1';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when POOL1 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '1';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l4;
				regarr_wrlineen       <= "0100";
				poolers_datain_s      <= regarr_line1;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '1';
				outbuf_wr_en          <= '1';
				addrgen_incr_wr       <= '1';
				o_ready               <= '0';
			when POOL2 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l1;
				regarr_wrlineen       <= "1000";
				poolers_datain_s      <= regarr_line2;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when POOL3 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l2;
				regarr_wrlineen       <= "0001";
				poolers_datain_s      <= regarr_line3;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when POOL4 =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l3;
				regarr_wrlineen       <= "0010";
				poolers_datain_s      <= regarr_line4;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when FINAL_WR_OBUF =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '1';
				outbuf_rd_en          <= '1';
				outbuf_rd_addr_offset <= addrgen_raddr_l4;
				regarr_wrlineen       <= "0100";
				poolers_datain_s      <= regarr_line1;
				poolers_en_s          <= '1';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '1';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when ITER_FMAP =>
				addrgen_reset         <= '0';
				clearFmap             <= '0';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '1';
				enTile                <= '0';
				enTileAddrOffset	  <= '0';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '0';
				outbuf_rd_addr_offset <= (others => '0');
				regarr_wrlineen       <= "0000";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
			when ITER_TILE =>
				addrgen_reset         <= '0';
				clearFmap             <= '1';
				clearTile             <= '0';
				clearTileAddrOffset   <= '0';
				enFmap                <= '0';
				enTile                <= '1';
				enTileAddrOffset	  <= '1';
				addrgen_incr_rd       <= '0';
				outbuf_rd_en          <= '0';
				outbuf_rd_addr_offset <= (others => '0');
				regarr_wrlineen       <= "0000";
				poolers_datain_s      <= (others => '0');
				poolers_en_s          <= '0';
				poolers_clear_s       <= '0';
				outbuf_wr_en          <= '0';
				addrgen_incr_wr       <= '0';
				o_ready               <= '0';
		end case;
	end process;

end architecture RTL;
