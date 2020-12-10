LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use STD.textio.all;
use ieee.std_logic_textio.all;

ENTITY ram_infer IS
	GENERIC(
		WordWidth    : integer;
		RamDepth     : integer;
		InitFileName : string;
		DumpFileName : string
	);
	PORT(clock         : IN  std_logic;
	     data          : IN  std_logic_vector(WordWidth - 1 DOWNTO 0);
	     write_address : IN  integer;
	     read_address  : IN  integer;
	     we            : IN  std_logic;
	     q             : OUT std_logic_vector(WordWidth - 1 DOWNTO 0);
	     dump_size     : IN  integer;
	     dump_flag     : IN  std_logic
	    );
END ram_infer;
ARCHITECTURE rtl OF ram_infer IS
	TYPE mem IS ARRAY (0 TO RamDepth) OF std_logic_vector(WordWidth - 1 DOWNTO 0);
	signal ram_fill : natural := 0;

	impure function init_ram_hex return mem is
		file text_file       : text;
		variable text_line   : line;
		variable ram_content : mem;
		variable iter        : natural := 0;
	begin
		if InitFileName /= "None" then
			file_open(text_file, InitFileName, read_mode);
			while not endfile(text_file) loop
				readline(text_file, text_line);
				hread(text_line, ram_content(iter));
				iter := iter + 1;
			end loop;
		end if;
		return ram_content;
	end function;

	procedure dump_ram_hex(variable ramconent : in mem;
	                       signal dump_size : in integer) is
		file text_file     : text;
		variable text_line : line;
		variable iter      : natural := 0;
	begin
		if DumpFileName /= "None" then
			file_open(text_file, DumpFileName, write_mode);
			for i in 0 to dump_size - 1 loop
				hwrite(text_line, ramconent(i), left, WordWidth);
				writeline(text_file, text_line);
			end loop;
		end if;
	end procedure;

BEGIN
	PROCESS(clock, dump_flag, dump_size)
		variable ram_block : mem := init_ram_hex;
	BEGIN
		IF (clock'event AND clock = '1') THEN
			IF (we = '1') THEN
				ram_block(write_address) := data;
			END IF;
			q <= ram_block(read_address);
		END IF;
		
		if (dump_flag = '1')THEN
			dump_ram_hex(ram_block, dump_size);
		END IF;
	END PROCESS;

END rtl;
