library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity controller is
	port(
		i_clk        : in  std_logic;
		i_reset      : in  std_logic;
		i_en_polling : in  std_logic;
		i_en_relu    : in  std_logic;
		i_en_bnorm   : in  std_logic;
		o_obuf_mode  : out std_logic;
		i_start      : in  std_logic;
		o_ready      : out std_logic;
		o_conv_start : out std_logic;
		i_conv_ready : in  std_logic;
		o_relu_on    : out std_logic;
		o_bnorm_on   : out std_logic;
		o_pool_start : out std_logic;
		i_pool_ready : in  std_logic
	);
end entity controller;

architecture RTL of controller is

	type state_type is (IDLE, CONVOLVE, POOL, CONVOLVE_START, POOL_START);
	signal state, next_state : state_type;

	signal reg_pooling_en : std_logic;
	signal reg_pooling    : std_logic;

	signal reg_relu_en : std_logic;
	signal reg_relu    : std_logic;

	signal reg_bnorm_en : std_logic;
	signal reg_bnorm    : std_logic;

begin

	poolreg : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_pooling <= '0';
			elsif reg_pooling_en = '1' then
				reg_pooling <= i_en_polling;
			end if;
		end if;
	end process poolreg;

	relureg : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_relu <= '0';
			elsif reg_relu_en = '1' then
				reg_relu <= i_en_relu;
			end if;
		end if;
	end process relureg;

	bnormreg : process(i_clk) is
	begin
		if rising_edge(i_clk) then
			if i_reset = '1' then
				reg_bnorm <= '0';
			elsif reg_bnorm_en = '1' then
				reg_bnorm <= i_en_bnorm;
			end if;
		end if;
	end process bnormreg;

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

	next_state_decode : process(state, i_start, i_conv_ready, i_pool_ready, reg_pooling)
	begin
		next_state <= IDLE;
		case (state) is
			when IDLE =>
				if (i_start = '1') then
					next_state <= CONVOLVE_START;
				else
					next_state <= IDLE;
				end if;
			when CONVOLVE_START =>
				next_state <= CONVOLVE;
			when CONVOLVE =>
				if (i_conv_ready = '1') then
					if (reg_pooling = '1') then
						next_state <= POOL_START;
					else
						next_state <= IDLE;
					end if;
				else
					next_state <= CONVOLVE;
				end if;
			when POOL_START =>
				next_state <= POOL;
			when POOL =>
				if (i_pool_ready = '1') then
					next_state <= IDLE;
				else
					next_state <= POOL;
				end if;
		end case;
	end process;

	output_decode : process(state, reg_relu, reg_bnorm)
	begin
		case (state) is
			when IDLE =>
				reg_pooling_en <= '1';
				reg_relu_en    <= '1';
				reg_bnorm_en   <= '1';
				o_conv_start   <= '0';
				o_pool_start   <= '0';
				o_obuf_mode    <= '0';
				o_ready        <= '1';
				o_relu_on      <= '0';
				o_bnorm_on     <= '0';
			when CONVOLVE_START =>
				reg_pooling_en <= '0';
				reg_relu_en    <= '0';
				reg_bnorm_en   <= '0';
				o_conv_start   <= '1';
				o_pool_start   <= '0';
				o_obuf_mode    <= '0';
				o_ready        <= '0';
				o_relu_on      <= reg_relu;
				o_bnorm_on     <= reg_bnorm;
			when CONVOLVE =>
				reg_pooling_en <= '0';
				reg_relu_en    <= '0';
				reg_bnorm_en   <= '0';
				o_conv_start   <= '0';
				o_pool_start   <= '0';
				o_obuf_mode    <= '0';
				o_ready        <= '0';
				o_relu_on      <= reg_relu;
				o_bnorm_on     <= reg_bnorm;
			when POOL_START =>
				reg_pooling_en <= '0';
				reg_relu_en    <= '0';
				reg_bnorm_en   <= '0';
				o_conv_start   <= '0';
				o_pool_start   <= '1';
				o_obuf_mode    <= '1';
				o_ready        <= '0';
				o_relu_on      <= '0';
				o_bnorm_on     <= '0';
			when POOL =>
				reg_pooling_en <= '0';
				reg_relu_en    <= '0';
				reg_bnorm_en   <= '0';
				o_conv_start   <= '0';
				o_pool_start   <= '0';
				o_obuf_mode    <= '1';
				o_ready        <= '0';
				o_relu_on      <= '0';
				o_bnorm_on     <= '0';
		end case;
	end process;

end architecture RTL;
