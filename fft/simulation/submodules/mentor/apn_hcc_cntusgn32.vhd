-- (C) 2001-2017 Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions and other 
-- software and tools, and its AMPP partner logic functions, and any output 
-- files any of the foregoing (including device programming or simulation 
-- files), and any associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License Subscription 
-- Agreement, Intel MegaCore Function License Agreement, or other applicable 
-- license agreement, including, without limitation, that your use is for the 
-- sole purpose of programming logic devices manufactured by Intel and sold by 
-- Intel or its authorized distributors.  Please refer to the applicable 
-- agreement for further details.



LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all; 

--***************************************************
--***                                             ***
--***   ALTERA FLOATING POINT DATAPATH COMPILER   ***
--***                                             ***
--***   APN_HCC_CNTUSGN32                         ***
--***                                             ***
--***   Function: Count leading bits in an        ***
--***             unsigned 32 bit number          ***
--***                                             ***
--***   14/07/07 ML                               ***
--***                                             ***
--***   (c) 2007 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_hcc_cntusgn32 IS 
PORT (
      frac : IN STD_LOGIC_VECTOR (32 DOWNTO 1);

		count : OUT STD_LOGIC_VECTOR (6 DOWNTO 1)
		);
END apn_hcc_cntusgn32;

ARCHITECTURE rtl OF apn_hcc_cntusgn32 IS
    
  type positiontype IS ARRAY (6 DOWNTO 1) OF STD_LOGIC_VECTOR (6 DOWNTO 1);
  
  signal sec, sel : STD_LOGIC_VECTOR (6 DOWNTO 1);
  signal lastfrac : STD_LOGIC_VECTOR (6 DOWNTO 1);
  signal position : positiontype;
  
  component apn_hcc_usgnpos IS
  GENERIC (start : integer := 10);
  PORT (
        ingroup : IN STD_LOGIC_VECTOR (6 DOWNTO 1);
      
        position : OUT STD_LOGIC_VECTOR (6 DOWNTO 1)   
       );
  end component;
  
BEGIN
  
  -- for single 32 bit mantissa 
  -- [S ][O....O][1 ][M...M][RGS]
  -- [32][31..28][27][26..4][321] - NB underflow can run into RGS
  -- for single 36 bit mantissa 
  -- [S ][O....O][1 ][M...M][O..O][RGS]
  -- [36][35..32][31][30..8][7..4][321] 
  -- for double 64 bit mantissa 
  -- [S ][O....O][1 ][M...M][O..O][RGS]
  -- [64][63..60][59][58..7][6..4][321] - NB underflow less than overflow
  
  -- find first leading '1' in inexact portion for 32 bit positive number
  sec(1) <= frac(31) OR frac(30) OR frac(29) OR frac(28) OR frac(27) OR frac(26);
  sec(2) <= frac(25) OR frac(24) OR frac(23) OR frac(22) OR frac(21) OR frac(20);
  sec(3) <= frac(19) OR frac(18) OR frac(17) OR frac(16) OR frac(15) OR frac(14);
  sec(4) <= frac(13) OR frac(12) OR frac(11) OR frac(10) OR frac(9) OR frac(8);
  sec(5) <= frac(7) OR frac(6) OR frac(5) OR frac(4) OR frac(3) OR frac(2);
  sec(6) <= frac(1);
  
  sel(1) <= sec(1);
  sel(2) <= sec(2) AND NOT(sec(1));
  sel(3) <= sec(3) AND NOT(sec(2)) AND NOT(sec(1));
  sel(4) <= sec(4) AND NOT(sec(3)) AND NOT(sec(2)) AND NOT(sec(1));
  sel(5) <= sec(5) AND NOT(sec(4)) AND NOT(sec(3)) AND NOT(sec(2)) AND NOT(sec(1));
  sel(6) <= sec(6) AND NOT(sec(5)) AND NOT(sec(4)) AND NOT(sec(3)) AND NOT(sec(2)) AND NOT(sec(1));
            
  pone: apn_hcc_usgnpos 
  GENERIC MAP (start=>0)
  PORT MAP (ingroup=>frac(31 DOWNTO 26),
            position=>position(1)(6 DOWNTO 1));
  ptwo: apn_hcc_usgnpos 
  GENERIC MAP (start=>6)
  PORT MAP (ingroup=>frac(25 DOWNTO 20),
            position=>position(2)(6 DOWNTO 1));
  pthr: apn_hcc_usgnpos 
  GENERIC MAP (start=>12)
  PORT MAP (ingroup=>frac(19 DOWNTO 14),
            position=>position(3)(6 DOWNTO 1));          
  pfor: apn_hcc_usgnpos 
  GENERIC MAP (start=>18)
  PORT MAP (ingroup=>frac(13 DOWNTO 8),
            position=>position(4)(6 DOWNTO 1));
  pfiv: apn_hcc_usgnpos 
  GENERIC MAP (start=>24)
  PORT MAP (ingroup=>frac(7 DOWNTO 2),
            position=>position(5)(6 DOWNTO 1));
  psix: apn_hcc_usgnpos 
  GENERIC MAP (start=>30)
  PORT MAP (ingroup=>lastfrac,
            position=>position(6)(6 DOWNTO 1));          
             
  lastfrac <= frac(1) & "00000";          
 
  gmc: FOR k IN 1 TO 6 GENERATE
    count(k) <= (position(1)(k) AND sel(1)) OR 
                (position(2)(k) AND sel(2)) OR 
                (position(3)(k) AND sel(3)) OR 
                (position(4)(k) AND sel(4)) OR 
                (position(5)(k) AND sel(5)) OR 
                (position(6)(k) AND sel(6));
  END GENERATE;
  
END rtl;

