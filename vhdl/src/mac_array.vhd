library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_array is
	generic(
		g_Pox     : integer;
		g_Poy     : integer;
		g_DataW   : integer;
		g_WeightW : integer
	);
	port(
		i_clk    : in  std_logic;
		i_reset  : in  std_logic;
		i_mac_en : in  std_logic_vector(g_Pox * g_Poy - 1 downto 0);
		i_data   : in  std_logic_vector(g_Pox * g_Poy * g_DataW - 1 downto 0);
		i_weight : in  std_logic_vector(g_WeightW - 1 downto 0);
		o_result : out std_logic_vector(g_Pox * g_Poy * g_DataW - 1 downto 0)
	);
end entity mac_array;

architecture RTL of mac_array is

	component mac
		generic(
			g_DataW   : in integer;
			g_WeightW : in integer
		);
		port(
			i_clk       : in  std_logic;
			i_reset     : in  std_logic;
			i_en        : in  std_logic;
			i_data      : in  std_logic_vector(g_DataW - 1 downto 0);
			i_weight    : in  std_logic_vector(g_WeightW - 1 downto 0);
			o_accum_out : out std_logic_vector(g_DataW - 1 downto 0)
		);
	end component mac;

begin

	gen_macs : for ii in g_Pox * g_Poy downto 1 generate
		mac_inst : mac
			generic map(
				g_DataW   => g_DataW,
				g_WeightW => g_WeightW
			)
			port map(
				i_clk       => i_clk,
				i_en        => i_mac_en(ii - 1),
				i_reset     => i_reset,
				i_data      => i_data(ii * g_DataW - 1 downto (ii - 1) * g_DataW),
				i_weight    => i_weight,
				o_accum_out => o_result(ii * g_DataW - 1 downto (ii - 1) * g_DataW)
			);
	end generate gen_macs;

end architecture RTL;
