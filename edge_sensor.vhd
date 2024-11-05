
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity edge_sensor is
	port
	(
		clk	: in std_logic;
		d	: in std_logic;
		ena	: in std_logic;
		clr	: in std_logic;
		q3	: out std_logic
	);
end entity;

architecture rtl of edge_sensor is
		
signal q1	: std_logic := '0';
signal q2	: std_logic := '0';

begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (clr = '1') then
				q1 <= '0';
				q2 <= '0';
				q3 <= '0';
			else
				if (ena = '1') then
					q1 <= d;
					q2 <= q1;
					q3 <= q1 and not q2;
				end if;
			end if;
		end if;
	end process;
	
end rtl;
	