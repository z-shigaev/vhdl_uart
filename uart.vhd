library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Math_PACK.all;

entity uart is
generic
	(	
		SYSTEM_CLOCK_SPEED 	: natural := 100;	-- 100 MHz
		BIT_RATE_VALUE		: natural := 1;		-- 1 Mbit/s
		OVERSAMPLING_RATIO	: natural := 4;		-- ������� ������������� � 4 ���� ������ �������� �������� ������
		WORD_WIDTH			: natural := 8		-- ����� ��� ������
	);
	port
	(
		--�������� �����/������
		System_Clock		: in std_logic;
		Input_Data_Line		: in std_logic;
		IRQ					: out std_logic;
		DataBusOut			: out std_logic_vector(WORD_WIDTH-1 DOWNTO 0);
		
		--������ ��� ������������ ������ �������
		Nyquist_Sample_Enable_vp	: out std_logic;	-- ����� ������� �������������
		Received_Data_Bits_vp		: out std_logic;	-- ����� �������� ������������ ������ � Input_Data_Line � ��������� �������
		Working_State_Flag_vp		: out std_logic;	-- ���� ������ ������ � ������ ����� (Input_Data_Line = 1 - ����� ��������)
		Parity_Current_Value_vp		: out std_logic;	-- ��� �������� �������� ������
		Sample_Number_Counter_vp	: out std_logic;	-- ���� ��� ������ ���������� ������ ��������, ������������ ������� ������������ ������ � ����� Input_Data_Line � ��������� �������
		
		CLK_100_vp					: out std_logic;	-- 100 ��� ������
		Sample_Freq_vp				: out std_logic;	-- ������� ������������
		ES_vp						: out std_logic;	-- ����� � edge_sensor
		st_wait_start_vp			: out std_logic;
		st_check_start_vp			: out std_logic;
		st_start_yes_vp				: out std_logic;
		mode_vp						: out std_logic;
		shift_d_vp					: out std_logic_vector(WORD_WIDTH-1 DOWNTO 0);
		cnt_q_vp					: out std_logic_vector(5 DOWNTO 0);
		bit_locked_vp				: out std_logic;
		shift_register_clock_vp		: out std_logic;
		parity_vp					: out std_logic
		
	);
end entity;

architecture rtl of uart is
	-- CONSTANTS --
	CONSTANT NYQUIST_SAMPLING_SPEED 			: natural := BIT_RATE_VALUE*OVERSAMPLING_RATIO;			-- ������� �������������
	CONSTANT SYSTEM_TO_NYQUIST_PRESCALER_MODULE : natural := SYSTEM_CLOCK_SPEED/NYQUIST_SAMPLING_SPEED;	-- ����������� �������
	CONSTANT BIT_NUMBER_TO_BE_PROCESSED			: natural := WORD_WIDTH + 3;							-- ������ �������: ������ (8) + ��������� ��� (1) + ��� �������� (1) + �������� ��� (1)
	CONSTANT RELATIVE_PHASE						: natural := 2;											-- ����� ������ �������� NYQUIST_SAMPLING_SPEED ��� ������� �������� ���������� ����
	CONSTANT SAMPLE_NUMBER_COUNTER_SIZE 		: natural := f_log2(BIT_NUMBER_TO_BE_PROCESSED * OVERSAMPLING_RATIO);			-- ������ �������� ��� ���������� �������� ������������ ������� ������
	
	CONSTANT PRESCALER_RATIO					: natural := SYSTEM_TO_NYQUIST_PRESCALER_MODULE;								-- ��������� ���� ������������ ��� ��������
	CONSTANT PRESCALER_SIZE						: natural := f_log2(PRESCALER_RATIO);											-- ������ ��������
	
	-- SIGNALS --
	signal SYSTEM_CLK_100_s	: std_logic;		-- ���������� 100 ��� ������
	signal prescaler_s		: std_logic_vector(PRESCALER_SIZE-1 DOWNTO 0);
	signal pre_rst_s		: std_logic := '0';
	signal Sample_Freq_s	: std_logic := '0';	-- ������ �������������
	signal es_out_s			: std_logic := '0'; -- ����� � edge sensor
	signal cnt_en_s			: std_logic := '0';	-- ���������� ������ ��������
	signal cnt_res_s		: std_logic := '0'; -- ����� ��������
	signal cnt_q_s			: std_logic_vector(SAMPLE_NUMBER_COUNTER_SIZE-1 DOWNTO 0);	-- ����� ��������
	
	signal st_wait_start_s	: std_logic := '1'; -- ������ ������ �������� ���������� ����
	signal st_check_start_s	: std_logic	:= '0'; -- ������ ������ �������� ���������� ����
	signal st_start_yes_s	: std_logic := '0'; -- ������ ������ ��������� ��� �������
	signal st_parity_checking	:	std_logic := '0'; -- ������ ������ �������� ��������
	signal mode_trigger_q	: std_logic := '0'; -- ����� ������ ��������: 0 - ��������, 1 - ����
	signal mode_trigger_r	: std_logic := '0'; -- reset
	signal mode_trigger_s	: std_logic := '0'; -- set
	
	signal bit_locked_s		: std_logic := '0'; -- ������ ������������ ��������������� ����
	signal shift_register_clock:	std_logic := '0';	-- ��� ���������� ������ ��������
	--signal bit_nyquist_s	: std_logic_vector(PRESCALER_SIZE-1 DOWNTO 0);
	
	--signal shift_q			: std_logic_vector(WORD_WIDTH-1 DOWNTO 0);	-- ������ ���������� ��������
	signal shift_d			: std_logic_vector(WORD_WIDTH-1 DOWNTO 0);	-- ����� ���������� ��������
	
	--parity
	signal parity_in		: std_logic	:= '0';
	signal parity_out		: std_logic := '0';

	-- COMPONENTS --
	COMPONENT Main_PLL
		PORT
		(
			inclk0	: in std_logic := '0';
			c0		: out std_logic
		);
	END COMPONENT;

	COMPONENT edge_sensor
		port
		(
			clk	: in std_logic;
			d	: in std_logic;
			ena	: in std_logic;
			clr	: in std_logic;
			q3	: out std_logic
		);
	END COMPONENT;
	
	COMPONENT counter
		generic
			(WIDTH	: natural := SAMPLE_NUMBER_COUNTER_SIZE);
		port
		(
			clk	: in std_logic;
			res	: in std_logic;
			en	: in std_logic;
			dir	: in std_logic;
			q	: out std_logic_vector(WIDTH-1 downto 0)
		);
	END COMPONENT;
	
	COMPONENT D_trigger
		port
		(
			d	: in std_logic := '1';
			clk	: in std_logic;
			q	: out std_logic
		);
	END COMPONENT;
	
	COMPONENT SR_trigger
		port
		(
			--SR trigger
			R	: in std_logic;
			S	: in std_logic;
			clk_SR: in std_logic;
			Q_SR: out std_logic
		);
	END COMPONENT;

begin
-------------------------------- PLL ---------------------------------
	PLL: Main_PLL
		port map
		(
			inclk0 	=> System_Clock,
			c0 		=> SYSTEM_CLK_100_s
		);
		
---------------------------- EDGE SENSING ----------------------------
	ES_in: edge_sensor
		port map
		(
			clk => SYSTEM_CLK_100_s,
			d	=> not Input_Data_Line,
			ena	=> '1',
			clr	=> '0',
			q3	=> es_out_s
		);

---------------------------- COUNTERS --------------------------------
	cnt_1: counter
		port map
		(
			clk	=> Sample_Freq_s,
			res	=> cnt_res_s,
			en	=> cnt_en_s,
			dir	=> '1',
			q	=> cnt_q_s
		);
---------------------------- MODE ------------------------------------
	mode: SR_trigger
		port map
		(
			R	=> mode_trigger_r,
			S	=> mode_trigger_s,
			clk_SR	=> SYSTEM_CLK_100_s,
			Q_SR	=> mode_trigger_q
		);
	
---------------------------- STATUSES --------------------------------
	statuses: process(SYSTEM_CLK_100_s)
	begin
		if(rising_edge(SYSTEM_CLK_100_s)) then
			mode_trigger_s	<= '0';
			if(st_wait_start_s = '1') then
				if (es_out_s = '1') then
					st_wait_start_s 	<= '0';
					st_check_start_s 	<= '1';
					cnt_en_s 			<= '1';
				end if;
			end if;	
			if(st_check_start_s = '1') then
				if (cnt_q_s = 2) then
					if (Input_Data_Line = '0') then
						st_start_yes_s	<= '1';
					end if;
				elsif (cnt_q_s = 4) then
					if (st_start_yes_s = '1') then
						mode_trigger_s	<= '1';
					end if;
					st_check_start_s	<= '0';
					st_start_yes_s		<= '0';
				end if;
			end if;	
		end if;
	end process;
	

--------------------------- BIT LOCKING -----------------------------	
	bit_locked_signal: process(Sample_Freq_s)
	begin
		if(rising_edge(Sample_Freq_s)) then
			bit_locked_s <= '0';
			for i in 0 to (BIT_NUMBER_TO_BE_PROCESSED-1) loop
				if(cnt_q_s = std_logic_vector(to_unsigned((2+(i*OVERSAMPLING_RATIO)-1), 6))) then
					bit_locked_s <= '1';
				end if;
			end loop;
		end if;
	end process;

---------------------------- SHIFT REGISTER --------------------------
	d_trigger_0: D_trigger
		port map
		(
			d 	=> Input_Data_Line,
			--clk	=> shift_register_clock,
			clk	=> bit_locked_s and mode_trigger_q,
			q 	=> shift_d(0)
		);
	d_triggers: for i in 1 to (WORD_WIDTH-1) generate d_triggers: D_trigger
		port map
		(
			d	=> shift_d(i-1),
			--clk	=> shift_register_clock,
			clk	=> bit_locked_s and mode_trigger_q,
			q	=> shift_d(i)
		);
	end generate;
	
	shift_register_process: process(SYSTEM_CLK_100_s)
	begin
		if(rising_edge(SYSTEM_CLK_100_s)) then
			mode_trigger_r	<= '0';
			if(cnt_q_s > std_logic_vector(to_unsigned(RELATIVE_PHASE + OVERSAMPLING_RATIO*WORD_WIDTH, 6))) then
				mode_trigger_r	<= '1';
				shift_register_clock <= '0';
			else	
				shift_register_clock <= '0';
			end if;
			if(cnt_q_s > std_logic_vector(to_unsigned(RELATIVE_PHASE + OVERSAMPLING_RATIO*(WORD_WIDTH+1), 6))) then
				st_parity_checking <= '1';
			end if;
		end if;
	end process;
	
--	shift_register: process(Sample_Freq_s)
--	begin
--		if(rising_edge(Sample_Freq_s)) then
--			if()
---------------------------- PARITY CHECKING -------------------------
	parity_d_trigger: D_trigger
		port map
		(
			d	=> parity_in,
			clk	=> bit_locked_s and mode_trigger_q,
			q	=> parity_out
		);
	
	parity_in <= parity_out xor Input_Data_line;

---------------------------- PRESCALER -------------------------------
	Prescaler: process(SYSTEM_CLK_100_s)
	begin
		if(rising_edge(SYSTEM_CLK_100_s)) then
			prescaler_s <= prescaler_s + '1';
			pre_rst_s	<= '0';
			if (prescaler_s = std_logic_vector(to_unsigned(PRESCALER_RATIO-1, PRESCALER_SIZE))) then
				prescaler_s <= (others => '0');
				pre_rst_s 	<= '1';
			end if;
		end if;
	end process;
	Sample_Freq_s <= pre_rst_s;
	
--	Bit_locked_cnt: process(cnt_q_s)
--	begin
--		if(rising_edge(cnt_q_s)) then
--			bit_s <= prescaler_s + '1';

---------------------------- VIRTUAL PINS ----------------------------
	CLK_100_vp 		<= SYSTEM_CLK_100_s;
	Sample_Freq_vp	<= Sample_Freq_s;
	ES_vp			<= es_out_s;

	st_wait_start_vp	<= st_wait_start_s;
	st_check_start_vp	<= st_check_start_s;
	st_start_yes_vp		<= st_start_yes_s;
	mode_vp				<= mode_trigger_q;
	shift_d_vp			<= shift_d;
	cnt_q_vp			<= cnt_q_s;
	bit_locked_vp		<= bit_locked_s;
	shift_register_clock_vp	<= shift_register_clock;
	parity_vp			<= parity_out;
	
end rtl;
