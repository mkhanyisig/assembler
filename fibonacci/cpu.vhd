-- Mkhanyisi Gamedze
-- CS232 Lab 7
-- stacker.vhd

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cpu is

	port (
		 clk   : in  std_logic;                       -- main clock
		 reset : in  std_logic;                       -- reset button
		
		 -- for CPU testbench signals
		 PCview : out std_logic_vector( 7 downto 0);  -- debugging outputs
		 IRview : out std_logic_vector(15 downto 0);
		 RAview : out std_logic_vector(15 downto 0);
		 RBview : out std_logic_vector(15 downto 0);
		 RCview : out std_logic_vector(15 downto 0);
		 RDview : out std_logic_vector(15 downto 0);
		 REview : out std_logic_vector(15 downto 0);

		 iport : in  std_logic_vector(7 downto 0);    -- input port
		 oport : out std_logic_vector(15 downto 0));  -- output port
   

end entity;


architecture rtl of cpu is
	-- create components
	component ProgramROM
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component;
	
	component dataRAM
		PORT
		(
			address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			wren		: IN STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component;
	
	component alu
		port 
		(
			 srcA : in  unsigned(15 downto 0);         -- input A
			 srcB : in  unsigned(15 downto 0);         -- input B
			 op   : in  std_logic_vector(2 downto 0);  -- operation
			 cr   : out std_logic_vector(3 downto 0);  -- condition outputs
			 dest : out unsigned(15 downto 0)        -- output value
	  );
	end component;
	
	-- internal signals
	signal counter : unsigned(2 downto 0);
	-- needed internal signals
	-- registers
	signal RA : std_logic_vector(15 downto 0); -- register A
	signal RB : std_logic_vector(15 downto 0); -- register B
	signal RC : std_logic_vector(15 downto 0); -- register C
	signal RD : std_logic_vector(15 downto 0); -- register D
	signal RE : std_logic_vector(15 downto 0); -- register E
	signal IR : std_logic_vector(15 downto 0); -- instruction register 
	signal PC : std_logic_vector(7 downto 0); -- program counter
	signal MBR : std_logic_vector(15 downto 0); -- memory buffer register 
	signal stack_ptr : std_logic_vector(15 downto 0); -- stack pointer
	signal MAR : std_logic_vector(7 downto 0); -- memory address
	signal cr : std_logic_vector(3 downto 0); -- condition register (4 bits)
	
	-- ALU signals
	signal alu1 : unsigned(15 downto 0); -- input 1
	signal alu2 : unsigned(15 downto 0); -- input 2
	signal alu_out : unsigned(15 downto 0); -- alu output
	
	-- output port register
	signal OUTREG : std_logic_vector(15 downto 0); -- output port register signal
	signal ROMOUT : std_logic_vector(15 downto 0); -- ROM output data wire
	signal RAMOUT : std_logic_vector(15 downto 0); -- RAM output data wire
	signal RAM_we : std_logic; -- RAM write enable wire
	signal alu_op : std_logic_vector(2 downto 0); -- opcode selection bit ALU
	signal alu_cr : std_logic_vector(3 downto 0);  -- condition bits for ALU input
	

	-- 9 states needed, so 16 states total using 4 bits
	signal state : std_logic_vector(3 downto 0);
	
begin
	-- concurrent assignements (for cpu testbench so we can see output)
	PCview <= PC;
	IRview <= IR;
	RAview <= RA;
	RBview <= RB;
	RCview <= RC;
	RDview <= RD;
	REview <= RE;
	oport <= OUTREG;
	
	
	-- port mapping
	prom : ProgramROM
		port map 
		(
			address => PC,
			clock => clk,
			q => ROMOUT
		);
	
	dram : dataRAM
		port map 
		(
			address => MAR,
			clock => clk,
			data => MBR,
			wren => RAM_we,
			q => RAMOUT
		);
		
	calu : alu
		port map 
		(
			srcA => alu1,
			srcB => alu2,
			op => alu_op,
			cr => alu_cr,
			dest => alu_out
		);
	
	process(clk,reset)
	begin 
		if reset ='0' then
			-- default values (everything gets zeros unless otherwise)
			RA <= (others => '0');
			RB <= (others => '0');
			RC <= (others => '0');
			RD <= (others => '0');
			RE <= (others => '0');
			IR <= (others => '0');
			MBR <= (others => '0');
			MAR <= (others => '0');
			PC <= (others => '0');
			counter <= (others => '0');
			OUTREG <= (others => '0');
			cr <= (others => '0');
			stack_ptr <= (others => '0');
			state <= "0000"; -- startup state
		elsif (rising_edge(clk)) then 
			case state is
				-- 9 states cases
				when "0000" => -- startup
					-- after 8 clock cycles, move to fetch state
					if counter < 7 then -- count up till count is 8 each cycle
						counter <= counter + 1; -- add one
					else
						state <= "0001"; -- move to fetch state
					end if;	
				when "0001" => -- fetch
					IR <= ROMOUT;
					PC <= std_logic_vector(unsigned(PC) +1);-- increment PC
					state <= "0010"; -- move to execute setup state below
				when "0010" => -- execute setup
					alu_op <= IR(14 downto 12);
					-- execute setup for each of the state instructions
					case IR(15 downto 12) is 
						when "0000" => -- load from RAM
							if IR(11) = '0' then -- not set , just low bits of IR
								MAR <= IR(7 downto 0); -- RAM address into MAR
								MBR <= IR;
							else -- use 8 low bits of IR plus register E
								MAR <= std_logic_vector(unsigned(IR(7 downto 0))+unsigned(RE(7 downto 0)));
								
								MBR <= std_logic_vector(unsigned(IR)+unsigned(RE));
							end if;
						when "0001" => -- store to RAM (same as load from RAM)
							if IR(11) = '0' then -- not set , just low bits of IR
								MAR <= IR(7 downto 0); -- RAM address into MAR
								MBR <= IR;
							else -- use 8 low bits of IR plus register E
								MAR <= std_logic_vector(unsigned(IR(7 downto 0))+unsigned(RE(7 downto 0)));
								
								MBR <= std_logic_vector(unsigned(IR)+unsigned(RE));
							end if;
						when "0010" => -- Unconditional Branch
							PC <= IR(7 downto 0);
						when "0011" => -- branches
							-- check condition glag
							case IR(11 downto 10) is
								when "00" => -- Conditional Branch
										if cr(0) = '1' then 
											PC <= IR(7 downto 0);
										elsif cr(1) = '1' then 
											PC <= IR(7 downto 0);
										elsif cr(2) = '1' then 
											PC <= IR(7 downto 0);
										elsif cr(3) = '1' then 
											PC <= IR(7 downto 0);
										else 
											-- do nothing
										end if;
								
								when "01" => -- call
									PC <= IR(7 downto 0);
									MAR <= stack_ptr(7 downto 0);
									MBR <= "0000" & cr & PC;
									stack_ptr <= std_logic_vector(unsigned(stack_ptr)+1);
								when "10" => -- return 
									MAR <= stack_ptr(7 downto 0);
									stack_ptr <= std_logic_vector(unsigned(stack_ptr)-1);
								when "11" => -- exit 
									state <= "1000"; -- halt state
								when others => 
									-- do nothing
							end case;
						when "0100" => -- push
							MAR <= stack_ptr(7 downto 0);
							stack_ptr <= std_logic_vector(unsigned(stack_ptr)+1);
							-- put the value specified in the source bits into the MBR
							case IR(11 downto 9) is -- push from proper src according to table C
								when "000" => -- RA
									MBR <= RA;
								when "001" => -- RB
									MBR <= RB;
								when "010" => -- RC
									MBR <= RC;
								when "011" => -- RD
									MBR <= RD;
								when "100" => -- RE	
									MBR <= RE;
								when "101" => -- stack pointer
									MBR <= stack_ptr;
								when "110" => -- Program counter 
									MBR <= "00000000" & PC;
								when "111" => -- Condition Register
									MBR <= "000000000000" & cr;
								when others =>
									-- do nothing
							end case;
								
						when "0101" => -- pop
							MAR <= std_logic_vector(unsigned(stack_ptr(7 downto 0))-1);
							stack_ptr <= std_logic_vector(unsigned(stack_ptr)-1);
						
						when "0110" => -- store to output
							-- not needed yet
							--case IR(11 downto 9) is -- Source - table D
								--when "000" => -- RA
									--OUTREG <= RA;
								--when "001" => -- RB
									--OUTREG <= RB;
								--when "010" => -- RC
									--OUTREG <= RC;
								--when "011" => -- RD
									--OUTREG <= RD;
								--when "100" => -- RE
									--OUTREG <= RE;
								--when "101" => -- Stack pointer
									--OUTREG <= stack_ptr;
								--when "110" => -- program counter
									--OUTREG <= "00000000" & PC;
								--when others => -- IR
									--OUTREG <= IR;
							--end case;
								
								
						when "0111" => -- load from input
							-- not needed
							-- not sure which register input to read from
							case IR(11 downto 9) is -- table B
								when "000" => -- RA
									-- RA <= ;
								when "001" => -- RB
									-- RB <=;
								when "010" => -- RC
									-- RC <= ;
								when "011" => -- RD
									-- RD <= ;
								when "100" => -- RE
									-- RE <= ;
								when "101" => -- SP
									-- stack_ptr <= ;
								when others => 
									-- do nothing
							end case;
								
						when "1000" => -- Add
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others =>
									-- do nothing
							end case;
							
							case IR(11 downto 9) is -- srcB (table E)
								when "000" => -- RA
									alu2 <= unsigned(RA);
								when "001" => -- RB
									alu2 <= unsigned(RB);
								when "010" => -- RC
									alu2 <= unsigned(RC);
								when "011" => -- RD
									alu2 <= unsigned(RD);
								when "100" => -- RE
									alu2 <= unsigned(RE);
								when "101" => -- stack pointer
									alu2 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu2 <= (others => '0');
								when "111" => -- ones
									alu2 <= (others => '1');
								when others => 
							end case;
								
						when "1001" => -- Subtract
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others => 
									-- do nothing
							end case;
							
							case IR(11 downto 9) is -- srcB (table E)
								when "000" => -- RA
									alu2 <= unsigned(RA);
								when "001" => -- RB
									alu2 <= unsigned(RB);
								when "010" => -- RC
									alu2 <= unsigned(RC);
								when "011" => -- RD
									alu2 <= unsigned(RD);
								when "100" => -- RE
									alu2 <= unsigned(RE);
								when "101" => -- stack pointer
									alu2 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu2 <= (others => '0');
								when "111" => -- ones
									alu2 <= (others => '1');
								when others => 
									-- do nothing
							end case;
						when "1010" => -- AND
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others => 
									-- do nothing
							end case;
							
							case IR(11 downto 9) is -- srcB (table E)
								when "000" => -- RA
									alu2 <= unsigned(RA);
								when "001" => -- RB
									alu2 <= unsigned(RB);
								when "010" => -- RC
									alu2 <= unsigned(RC);
								when "011" => -- RD
									alu2 <= unsigned(RD);
								when "100" => -- RE
									alu2 <= unsigned(RE);
								when "101" => -- stack pointer
									alu2 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu2 <= (others => '0');
								when "111" => -- ones
									alu2 <= (others => '1');
								when others => 
									-- do nothing
							end case;
						when "1011" => -- OR
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others =>
									-- do nothing
							end case;
							
							case IR(11 downto 9) is -- srcB (table E)
								when "000" => -- RA
									alu2 <= unsigned(RA);
								when "001" => -- RB
									alu2 <= unsigned(RB);
								when "010" => -- RC
									alu2 <= unsigned(RC);
								when "011" => -- RD
									alu2 <= unsigned(RD);
								when "100" => -- RE
									alu2 <= unsigned(RE);
								when "101" => -- stack pointer
									alu2 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu2 <= (others => '0');
								when "111" => -- ones
									alu2 <= (others => '1');
								when others => 
									-- do nothing
							end case;
						when "1100" => -- Exclusive or (xor)
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others => 
									-- do nothing
							end case;
							
							case IR(11 downto 9) is -- srcB (table E)
								when "000" => -- RA
									alu2 <= unsigned(RA);
								when "001" => -- RB
									alu2 <= unsigned(RB);
								when "010" => -- RC
									alu2 <= unsigned(RC);
								when "011" => -- RD
									alu2 <= unsigned(RD);
								when "100" => -- RE
									alu2 <= unsigned(RE);
								when "101" => -- stack pointer
									alu2 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu2 <= (others => '0');
								when "111" => -- ones
									alu2 <= (others => '1');
								when others => 
									-- do nothing
							end case;
				
						when "1101" => -- shift
							-- setup srcA
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others => 
									-- do nothing
								
							end case;
							
							alu2(0) <= IR(11); -- direction bit
							
							
						when "1110" => -- rotate 
							-- setup srcA
							case IR(11 downto 9) is -- srcA (table E)
								when "000" => -- RA
									alu1 <= unsigned(RA);
								when "001" => -- RB
									alu1 <= unsigned(RB);
								when "010" => -- RC
									alu1 <= unsigned(RC);
								when "011" => -- RD
									alu1 <= unsigned(RD);
								when "100" => -- RE
									alu1 <= unsigned(RE);
								when "101" => -- stack pointer
									alu1 <= unsigned(stack_ptr);
								when "110" => -- zeros
									alu1 <= (others => '0');
								when "111" => -- ones
									alu1 <= (others => '1');
								when others => 
									-- do nothing
							end case;
							
							alu2(0) <= IR(11); -- direction bit
						when others => -- move 
							case IR(11) is 
								when '1' => -- T value
									-- treat next 8 bits as a sign-extended immediate value
									alu1(7 downto 0) <= unsigned(IR(10 downto 3));
									alu1(15 downto 8) <= (others => IR(10));
								when '0' => -- SSS = source location (table D)
									case IR(10 downto 8) is 
										when "000" => -- RA
											alu1 <= unsigned(RA);
										when "001" => -- RB
											alu1 <= unsigned(RB);
										when "010" => -- RC
											alu1 <= unsigned(RC);
										when "011" => -- RD
											alu1 <= unsigned(RD);
										when "100" => -- RE
											alu1 <= unsigned(RE);
										when "101" => -- SP
											alu1 <= unsigned(stack_ptr);
										when "110" => -- PC 
											alu1 <= unsigned("00000000" & PC);
										when others => -- IR
											alu1 <= unsigned(IR);
									end case;
								when others => 
									-- do nothing
								end case;
						
					end case;
					
				-- move to next state (execute)	
				state <= "0011";
						
				
				when "0011" => -- execute ALU (process)
					--  set the RAM write enable signal to high if the operation is a store
					-- 	(opcode 0001, or integer 1), a push, or a CALL
					case IR(15 downto 12) is 
						when "0001" => -- store 
							RAM_we <= '1';
						when "0100" => -- push
							RAM_we <= '1';
						when "0011" => -- call
							RAM_we <= '1';
						when others => -- set low otherwise
							RAM_we <= '0';
					end case;
					
					-- move to next state (execute wait state)
					state <= "0100";
					
				when "0100" => -- execute MemWait
					-- does nothing
					state <= "0101"; -- next state
				when "0101" => -- execute Write
					-- handle the final stage of the various operations
					RAM_we <= '0';
					
					case IR(15 downto 12) is -- opcode bits
						when "0000" => -- load from RAM
							case IR(10 downto 8) is -- dest bits
								when "000" => -- RA
									RA <= RAMOUT;
								when "001" => -- RB
									RB <= RAMOUT;
								when "010" => -- RC
									RC <= RAMOUT;
								when "011" => -- RD
									RD <= RAMOUT;
								when "100" => -- RE
									RE <= RAMOUT;
								when "101" => -- SP
									stack_ptr <= RAMOUT;
								when others =>
									-- do nothing
							end case;
						when "0001" => -- do nothing
						
						when "0010" => -- do nothing
						
						when "0011" => 
							-- do nothing for conditional branch, call, and exit
							
							case IR(11 downto 10) is
								when "10" => -- return
									PC <= RAMOUT(7 downto 0);
									cr <= RAMOUT(11 downto 8);
								when others =>
									-- do nothing
							end case;
							
						when "0101" => -- pop
							--  write the value of the RAM data wire to the destination specified in the instruction
							case IR(11 downto 9) is 
								when "000" => -- RA
									RA <= RAMOUT;
								when "001" => -- RB
									RB <= RAMOUT;
								when "010" => -- RC
									RC <= RAMOUT;
								when "011" => -- RD
									RD <= RAMOUT;
								when "100" => -- RE
									RE <= RAMOUT;
								when "101" => -- Stack pointer 
									stack_ptr <= RAMOUT;
								when "110" => -- PC
									PC <= RAMOUT(7 downto 0);
								when "111" => -- condition register
									cr <= RAMOUT(3 downto 0);
								when others =>
									-- do nothing
							end case;
						
						when "0110" => -- write to output
							case IR(11 downto 9) is 
								when "000" => -- RA
									OUTREG <= RA;
								when "001" => -- RB
									OUTREG <= RB;
								when "010" => -- RC
									OUTREG <= RC ;
								when "011" => -- RD
									OUTREG <= RD;
								when "100" => -- RE
									OUTREG <= RE;
								when "101" => -- stack pointer
									OUTREG <= stack_ptr;
								when "110" => -- Program counter
									OUTREG(7 downto 0) <= PC;
									OUTREG(15 downto 8) <= (others => '0');
								when "111" => -- IR
									OUTREG <= IR;
								when others => 
									-- do nothing
							end case;
						
						when "0111" => -- load from input
							case IR(11 downto 9) is -- write the input port value to the specified register
								when "000" => -- RA
									RA(7 downto 0) <= iport;
									RA(15 downto 8) <= (others => '0');
								when "001" => -- RB
									RB(7 downto 0) <= iport;
									RB(15 downto 8) <= (others => '0');
								when "010" => -- RC
									RC(7 downto 0) <= iport;
									RC(15 downto 8) <= (others => '0');
								when "011" => -- RD
									RD(7 downto 0) <= iport;
									RD(15 downto 8) <= (others => '0');
								when "100" => -- RE
									RE(7 downto 0) <= iport;
									RE(15 downto 8) <= (others => '0');
								when "101" => -- Stack pointer
									stack_ptr(7 downto 0) <= iport;
									stack_ptr(15 downto 8) <= (others => '0');
								when others =>
									-- do nothing
							end case;
						
						-- combine all these
						--  binary and unary arithmetic operations (add, sub, and, or, xor, shift, rotate)
						when "1000" | "1001" | "1010" | "1011" | "1100" | "1101" | "1110" => 
							
							case IR(2 downto 0) is -- dest 
								when "000" => -- RA
									RA <= std_logic_vector(alu_out);
								when "001" => -- RB
									RB <= std_logic_vector(alu_out);
								when "010" => -- RC
									RC <= std_logic_vector(alu_out);
								when "011" => -- RD
									RD <= std_logic_vector(alu_out);
								when "100" => -- RE
									RE <= std_logic_vector(alu_out);
								when "101" => -- Stack pointer
									stack_ptr <= std_logic_vector(alu_out);
								when others => 
									-- do nothing
							end case;
							cr <= alu_cr;
							
						when "1111" => -- move 
							
							case IR(2 downto 0) is -- dest select
								when "000" => -- RA
									RA <= std_logic_vector(alu_out);
								when "001" => -- RB
									RB <= std_logic_vector(alu_out);
								when "010" => -- RC
									RC <= std_logic_vector(alu_out);
								when "011" => -- RD
									RD <= std_logic_vector(alu_out);
								when "100" => -- RE
									RE <= std_logic_vector(alu_out);
								when "101" => -- stack pointer
									stack_ptr <= std_logic_vector(alu_out);
								when others => 
									-- do nothing
							end case;
							cr <= alu_cr; -- first things first!
						
						when others =>
							-- do nothing;
					end case;
					
					state <= "0110"; -- return phase 1
				when "0110" => -- execute return phase 1
					state <= "0111"; -- return phase 2
				when "0111" => -- execute return phase 2
					state <= "1000"; -- halt state
				when "1000" => -- halt state
					state <= "0001" ; -- return to fetch state 
				when others =>
					null;
			end case;
		end if;
	
	end process;
	
end rtl;
