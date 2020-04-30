library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity multiplier_dec is
generic (
	input_size		: integer := 5);
port (
--	seg_out3	: out std_logic_vector(6 downto 0);
	seg_out2	: out std_logic_vector(6 downto 0);
	seg_out1	: out std_logic_vector(6 downto 0);
	seg_out0	: out std_logic_vector(6 downto 0);
	product					: out unsigned(2*input_size-1 downto 0);	-- result of the multiplication
	data_ready				: out std_logic;	-- signal indicating the multiplication is complete
	input_1					: in unsigned(input_size - 1 downto 0);
	input_2 				: in unsigned(input_size - 1 downto 0);
	start 					: in std_logic;
	reset 					: in std_logic;
	clk 					: in std_logic);
end multiplier_dec;

architecture behavior of multiplier_dec is

component dec_to_7_seg
port (
	dec 			: in std_logic_vector(3 downto 0);
	seven_seg 		: out std_logic_vector( 6 downto 0));
end component;

component binary_bcd
port (
    clk: in std_logic;
    binary_in: in std_logic_vector(2*input_size-1 downto 0);
    bcd0, bcd1, bcd2: out std_logic_vector(3 downto 0));
end component;

--signal seg_3	: std_logic_vector(6 downto 0);
signal seg_2	: std_logic_vector(6 downto 0);
signal seg_1	: std_logic_vector(6 downto 0);
signal seg_0	: std_logic_vector(6 downto 0);

--signal dec_in_3	: std_logic_vector(3 downto 0);
signal dec_in_2	: std_logic_vector(3 downto 0);
signal dec_in_1	: std_logic_vector(3 downto 0);
signal dec_in_0	: std_logic_vector(3 downto 0);

type state_type is(init, load, right_shift, done);
signal state, nxt_state	: state_type;

-- Control Signals
signal shift				: std_logic;
signal add					: std_logic;
signal load_data			: std_logic;

-- Data Signals
constant maxcount			: integer := input_size - 1;
signal input_1_reg			: unsigned(input_size - 1 downto 0) := (others => '0');
signal sum					: unsigned(input_size downto 0) := (others => '0');
signal product_reg			: unsigned(2*input_size - 1 downto 0) := (others => '0');
signal product_7seg			:std_logic_vector(2*input_size - 1 downto 0) := (others => '0');
signal count 				: integer range 0 to maxcount + 1 := 0;
signal start_count_lead		: std_logic := '0';
signal start_count_follow	: std_logic := '0';
signal start_count			: std_logic := '0';

begin

	bcd : binary_bcd
		port map (clk, product_7seg,dec_in_0,dec_in_1,dec_in_2);
--	seg3 : dec_to_7_seg	
--		port map (dec_in_3,seg_3);
	seg2 : dec_to_7_seg 
		port map (dec_in_2,seg_2);
	seg1 : dec_to_7_seg	
		port map (dec_in_1,seg_1);
	seg0 : dec_to_7_seg 
		port map (dec_in_0,seg_0);
	
	dec_7seg: process(product_reg)
	begin
		product_7seg <= std_logic_vector(product_reg);	
		
--		seg_out3 <= seg_3;
		seg_out2 <= seg_2;
		seg_out1 <= seg_1;
		seg_out0 <= seg_0;
	end process dec_7seg;

	state_proc: process(clk)
		begin
		if rising_edge(clk) then
			if(reset = '0') then
				state <= init;
			else
				state <= nxt_state;
			end if;
		end if;
	end process state_proc;
	
	state_machine: process(state, start, start_count, count, product_reg(0))
		begin
		-- initialize nxt_state and control signals
		nxt_state <= state;
		shift <= '0';
		add <= '0';
		load_data <= '0';
		data_ready <= '0';
		
		case state is
			when init =>
				if(start_count = '1') then
					nxt_state <= load;	
				else
					nxt_state <= init;
				end if;
			when load =>
				load_data <= '1';
				nxt_state <= right_shift;
			when right_shift =>
				shift <= '1';
				if(count /= maxcount) then
					nxt_state <= right_shift;
				else
					nxt_state <= done;
				end if;
				if(product_reg(0) = '1') then
					add <= '1';
				end if;
			when done =>
				data_ready <= '1';
				if(start = '0') then
					nxt_state <= init;
				else
					nxt_state <= done;
				end if;
			when others =>
				nxt_state <= init;
		end case;
	end process state_machine;
	
	-- start_count = '1' on the rising edge of the start input
	start_count <= start_count_lead and (not start_count_follow);
	
	-- Process that starts the state machine on the rising edge of our clock
	start_count_proc: process(clk)
		begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				start_count_lead <= '0';
				start_count_follow <= '0';
			else
				start_count_lead <= start;
				start_count_follow <= start_count_lead;
			end if;
		end if;
	end process start_count_proc;
	
	-- create counter to keep track of the adds and shifts
	count_proc: process(clk)
		begin
		if(rising_edge(clk)) then
			if((start_count = '1') or (reset = '0')) then
				count <= 0;	
			elsif(state = right_shift) then
				count <= count + 1;
			end if;
		end if;
	end process count_proc;
	
	-- calculate the sum of the multiplication and the upper bits of the product register
	sum <= ('0' & product_reg(2*input_size - 1 downto input_size)) + ('0' & input_1_reg);

	-- shifting
	mult_proc: process(clk)
		begin
		if(rising_edge(clk)) then
			if(reset = '0') then
				product_reg <= (others => '0');
				input_1_reg <= (others => '0');
			elsif(load_data = '1') then
				product_reg(input_size*2 - 1 downto input_size) <= (others => '0');
				product_reg(input_size -1 downto 0) <= input_2;
				input_1_reg <= input_1;
			elsif(add = '1') then
				product_reg <= sum(input_size downto 0) & product_reg(input_size - 1 downto 1);
			elsif(shift = '1') then	
				product_reg <= '0' & product_reg(input_size*2 - 1 downto 1);
			end if;
		end if;
	end process mult_proc;
	
	product <= product_reg;
end behavior;