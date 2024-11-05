 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned;

entity SR_trigger is
	port
	(
		--SR trigger
		R	: in std_logic;
		S	: in std_logic;
		clk_SR: in std_logic;
		Q_SR: out std_logic
	);

end entity;

architecture rtl of SR_trigger is

begin
	
	SR_FF: process(clk_SR)
	begin
		if(rising_edge(clk_SR)) then
			if(S = '1') then
				Q_SR <= '1';
			elsif (R = '1') then
				Q_SR <= '0';
			end if;
		end if;
	end process SR_FF;
end rtl;