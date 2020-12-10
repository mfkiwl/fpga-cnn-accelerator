library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_control is
	generic(
		g_DataBramAddrWidth   : in integer;
		g_KernelBramAddrWidth : in integer
	);
	port(
		i_clk                  : in  std_logic;
		i_reset                : in  std_logic;
		i_start                : in  std_logic;
		o_ready                : out std_logic;
		i_conv_busy            : in  std_logic;
		o_conv_start           : out std_logic;
		o_conv_reset           : out std_logic;
		i_p2s_busy             : in  std_logic;
		o_p2s_start            : out std_logic;
		i_kernelSize           : in  std_logic_vector(15 downto 0);
		i_iterX                : in  std_logic_vector(15 downto 0);
		i_iterY                : in  std_logic_vector(15 downto 0);
		i_convType             : in  std_logic_vector(15 downto 0);
		i_numConvblockBuflines : in  std_logic_vector(15 downto 0);
		i_numInputFmaps        : in  std_logic_vector(15 downto 0);
		i_fmapBuflines         : in  std_logic_vector(15 downto 0);
		i_tileIterations       : in  std_logic_vector(15 downto 0);
		o_padding_mode         : out std_logic_vector(2 downto 0);
		o_dread_base           : out std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
		o_kread_base           : out std_logic_vector(g_KernelBramAddrWidth - 1 downto 0)
	);
end entity;

architecture rtl of conv_control is

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

	signal clearX, clearY, clearFmap, clearTile : std_logic;
	signal iX, iY, iFmap                        : std_logic_vector(15 downto 0);
	signal iTile                                : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal enX, enY, enFmap, enTile             : std_logic;

	signal reset_data_pixel_offset_accumulator : std_logic;
	signal en_data_pixel_offset_accumulator    : std_logic;
	signal data_pixel_offset                   : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal data_pixel_offset_shift             : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);

	signal reset_data_fmap_accumulator     : std_logic;
	signal en_data_fmap_offset_accumulator : std_logic;
	signal data_fmap_offset                : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);
	signal data_fmap_offset_shift          : std_logic_vector(g_DataBramAddrWidth - 1 downto 0);

	signal reset_kernel_tileoffset_accumulator : std_logic;
	signal en_kernel_tileoffset_accumulator    : std_logic;
	signal kernel_tile_offset                  : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal kernel_tile_offset_shift            : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

	type state_type is (IDLE, INIT, CONV_START, WAIT_CONV, ITER_FMAP, ITER_X, ITER_Y, WAIT_P2S_INIT, WAIT_P2S_TILE, ITER_TILE);
	signal state, next_state : state_type;

	signal reset_kernel_fmap_accumulator     : std_logic;
	signal en_kernel_fmap_offset_accumulator : std_logic;
	signal kernel_fmap_offset_shift          : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);
	signal kernel_fmap_offset                : std_logic_vector(g_KernelBramAddrWidth - 1 downto 0);

begin

	o_kread_base   <= std_logic_vector(unsigned(kernel_tile_offset) + unsigned(kernel_fmap_offset));
	o_dread_base   <= std_logic_vector(unsigned(data_pixel_offset) + unsigned(data_fmap_offset));
	
	o_padding_mode <= "000" when i_convType = x"0001" else 
					  "001" when iX = x"0000" and i_convType = x"0002" else
	 				  "000"; 	

	iterTilectr : up_counter
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => clearTile,
			enable => enTile,
			cout   => iTile
		);

	iterFmapctr : up_counter
		generic map(
			g_DataWidth => 16
		)
		port map(
			clk    => i_clk,
			reset  => clearFmap,
			enable => enFmap,
			cout   => iFmap
		);

	iterXctr : up_counter
		generic map(
			g_DataWidth => 16
		)
		port map(
			clk    => i_clk,
			reset  => clearX,
			enable => enX,
			cout   => iX
		);

	iterYctr : up_counter
		generic map(
			g_DataWidth => 16
		)
		port map(
			clk    => i_clk,
			reset  => clearY,
			enable => enY,
			cout   => iY
		);

	data_pixeloffset_adder : accumulator
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => reset_data_pixel_offset_accumulator,
			enable => en_data_pixel_offset_accumulator,
			din    => data_pixel_offset_shift,
			q      => data_pixel_offset
		);

	data_fmapoffset_adder : accumulator
		generic map(
			g_DataWidth => g_DataBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => reset_data_fmap_accumulator,
			enable => en_data_fmap_offset_accumulator,
			din    => data_fmap_offset_shift,
			q      => data_fmap_offset
		);

	kernel_fmapoffset_adder : accumulator
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => reset_kernel_fmap_accumulator,
			enable => en_kernel_fmap_offset_accumulator,
			din    => kernel_fmap_offset_shift,
			q      => kernel_fmap_offset
		);

	kernel_tileoffset_adder : accumulator
		generic map(
			g_DataWidth => g_KernelBramAddrWidth
		)
		port map(
			clk    => i_clk,
			reset  => reset_kernel_tileoffset_accumulator,
			enable => en_kernel_tileoffset_accumulator,
			din    => kernel_tile_offset_shift,
			q      => kernel_tile_offset
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

	next_state_decode : process(state, i_start, iX, iY, i_iterX, i_iterY, i_conv_busy, i_p2s_busy, iFmap, i_numInputFmaps, iTile, i_tileIterations)
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
				next_state <= CONV_START;
			when CONV_START =>
				next_state <= WAIT_CONV;
			when WAIT_CONV =>
				if (i_conv_busy = '0') then
					if unsigned(iFmap) < unsigned(i_numInputFmaps) - 1 then
						next_state <= ITER_FMAP;
					elsif (unsigned(iY) = unsigned(i_iterY) - 1) then
						next_state <= ITER_X;
					else
						next_state <= ITER_Y;
					end if;
				else
					next_state <= WAIT_CONV;
				end if;
			when ITER_FMAP =>
				next_state <= CONV_START;
			when ITER_Y =>
				next_state <= WAIT_P2S_INIT;
			when ITER_X =>
				if (unsigned(iX) = unsigned(i_iterX) - 1) then
					next_state <= WAIT_P2S_TILE;
				else
					next_state <= WAIT_P2S_INIT;
				end if;
			when WAIT_P2S_INIT =>
				if (i_p2s_busy = '0') then
					next_state <= INIT;
				else
					next_state <= WAIT_P2S_INIT;
				end if;
			when WAIT_P2S_TILE =>
				if (i_p2s_busy = '0') then
					next_state <= ITER_TILE;
				else
					next_state <= WAIT_P2S_TILE;
				end if;
			when ITER_TILE =>
				if (unsigned(iTile) = unsigned(i_tileIterations) - 1) then
					next_state <= IDLE;
				else
					next_state <= INIT;
				end if;
		end case;
	end process;

	output_decode : process(state, i_fmapBuflines, i_numInputFmaps)
	begin
		case (state) is
			when IDLE =>
				o_ready                             <= '1';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= (others => '0');
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '1';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '1';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '1';
				-- Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '1';
				o_conv_start                        <= '0';
				clearX                              <= '1';
				clearY                              <= '1';
				clearFmap                           <= '1';
				clearTile                           <= '1';
				o_conv_reset                        <= '1';
				o_p2s_start                         <= '0';
			when INIT =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= (others => '0');
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '1';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '1';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '1';
				o_p2s_start                         <= '0';
			when CONV_START =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= (others => '0');
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '1';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '0';
			when WAIT_CONV =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= (others => '0');
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '0';
			when ITER_FMAP =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '1';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= (others => '0');
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= std_logic_vector(to_unsigned(to_integer(unsigned(i_fmapBuflines)), g_DataBramAddrWidth));
				en_data_fmap_offset_accumulator     <= '1';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= std_logic_vector(to_unsigned(to_integer(unsigned(i_kernelSize)), g_KernelBramAddrWidth));
				en_kernel_fmap_offset_accumulator   <= '1';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '0';
			when ITER_Y =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '1';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= std_logic_vector(to_unsigned(to_integer(unsigned(i_numConvblockBuflines)), g_DataBramAddrWidth));
				en_data_pixel_offset_accumulator    <= '1';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '1';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '1';
			when ITER_X =>
				o_ready                             <= '0';
				enX                                 <= '1';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= std_logic_vector(to_unsigned(to_integer(unsigned(i_numConvblockBuflines)), g_DataBramAddrWidth));
				en_data_pixel_offset_accumulator    <= '1';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '1';
				clearFmap                           <= '1';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '1';
			when WAIT_P2S_INIT =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '0';
			when WAIT_P2S_TILE =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '0';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '0';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '0';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '0';
				--Tile Iterations 
				kernel_tile_offset_shift            <= (others => '0');
				en_kernel_tileoffset_accumulator    <= '0';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '0';
				clearY                              <= '0';
				clearFmap                           <= '0';
				clearTile                           <= '0';
				o_conv_reset                        <= '0';
				o_p2s_start                         <= '0';
			when ITER_TILE =>
				o_ready                             <= '0';
				enX                                 <= '0';
				enY                                 <= '0';
				enFmap                              <= '0';
				enTile                              <= '1';
				-- XY Block Pos Iterations
				data_pixel_offset_shift             <= std_logic_vector(to_unsigned(0, g_DataBramAddrWidth));
				en_data_pixel_offset_accumulator    <= '0';
				reset_data_pixel_offset_accumulator <= '1';
				-- Fmap Iterations
				data_fmap_offset_shift              <= (others => '0');
				en_data_fmap_offset_accumulator     <= '0';
				reset_data_fmap_accumulator         <= '1';
				kernel_fmap_offset_shift            <= (others => '0');
				en_kernel_fmap_offset_accumulator   <= '0';
				reset_kernel_fmap_accumulator       <= '1';
				--Tile Iterations 
				kernel_tile_offset_shift            <= std_logic_vector(to_unsigned(to_integer(unsigned(i_kernelSize)) * to_integer(unsigned(i_numInputFmaps)), g_KernelBramAddrWidth));
				en_kernel_tileoffset_accumulator    <= '1';
				reset_kernel_tileoffset_accumulator <= '0';
				o_conv_start                        <= '0';
				clearX                              <= '1';
				clearY                              <= '1';
				clearFmap                           <= '1';
				clearTile                           <= '0';
				o_conv_reset                        <= '1';
				o_p2s_start                         <= '0';
		end case;
	end process;

end rtl;
