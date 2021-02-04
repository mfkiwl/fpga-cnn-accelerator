library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram is
   generic (DATA_WIDTH : positive;
            RAM_WIDTH  : positive);
   port (
      clk     : in  std_logic;
      rst     : in  std_logic;          -- reset is optional, not used here
      din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      wr_en   : in  std_logic;
      rd_en   : in  std_logic;
      wr_addr : in  std_logic_vector(RAM_WIDTH - 1 downto 0);
      rd_addr : in  std_logic_vector(RAM_WIDTH - 1 downto 0);
      dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end dpram;

--library synplify; -- uncomment this line when using Synplify       
architecture rtl of dpram is

   type memory_type is array (2**RAM_WIDTH - 1 downto 0) of
      std_logic_vector(DATA_WIDTH - 1 downto 0);
   signal memory   : memory_type;
   signal lrd_addr : std_logic_vector(RAM_WIDTH - 1 downto 0);
-- Enable syn_ramstyle attribute when using Xilinx to enable block ram
-- otherwise you get embedded CLB ram.
-- attribute syn_ramstyle : string;
-- attribute syn_ramstyle of memory : signal is "block_ram";

begin
   -- Generic ram, good synthesis programs will make block ram out of it...
   process(clk)
   begin
      if rising_edge(clk) then
         if wr_en = '1' then
            memory(to_integer(unsigned(wr_addr))) <= din;
         end if;
      end if;
   end process;

   process(clk)
   begin
      if rising_edge(clk) then
         if rd_en = '1' then
            dout <= memory(to_integer(unsigned(rd_addr)));
         end if;
      end if;
   end process;
   
end rtl;
