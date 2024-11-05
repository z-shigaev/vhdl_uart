 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity counter is
	generic
	(
		WIDTH	: natural := 8
	);
	port
	(
		clk	: in std_logic;
		res	: in std_logic;
		en	: in std_logic;
		dir	: in std_logic;
		q	: out std_logic_vector(WIDTH-1 downto 0)
	);
end entity;

architecture rtl of counter is

signal cnt: std_logic_vector(WIDTH-1 downto 0)	:=(others => '0');

begin
	--sync counter
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(res = '1') then
				cnt <= (others => '0');
			else
				if(en = '1') then
					if (dir = '1') then
						cnt <= cnt + '1';
					else
						cnt <= cnt - '1';
					end if;
				end if;
			end if;
		end if;
	end process;
	q <= cnt;

end rtl;

				