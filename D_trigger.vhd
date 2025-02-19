
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned;

entity D_trigger is
	port
	(
		d	: in std_logic := '1';
		clk	: in std_logic;
		q	: out std_logic
	);

end entity;

architecture rtl of D_trigger is

begin
	process(clk)
	begin
		if(rising_edge(clk)) then
			q <= d;
		end if;
	end process;
	
end rtl;