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
USE ieee.std_logic_signed.all;
USE ieee.std_logic_arith.all; 

LIBRARY altera_mf;
USE altera_mf.all;

library work;
use work.auk_dspip_math_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_MUL                             ***
--***                                             ***
--***   Function: multiply internal format numbers***
--***                                             ***
--***   20/01/10 ML                               ***
--***                                             ***
--***   (c) 2010 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***   27/01/10 - change exponent to 10 bits     ***
--***   (underflow issues)                        ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_mul IS 
GENERIC (
      device_family : STRING
      );
PORT (
      sysclk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      aamantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      aaexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      bbmantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      bbexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
      ccmantissa : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      ccexponent : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
      );
END apn_fftfp_mul;

ARCHITECTURE rtl OF apn_fftfp_mul IS
  
  type exponentfftype IS ARRAY (2 DOWNTO 1) OF STD_LOGIC_VECTOR (10 DOWNTO 1);
 
  signal aaexponentff, bbexponentff : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal exponentff : exponentfftype;
  signal ccmantissanode : STD_LOGIC_VECTOR (64 DOWNTO 1);
  signal aazipff, aazipff2 : STD_LOGIC;
  signal exponentzip : STD_LOGIC_VECTOR (10 DOWNTO 1);
      
  component altera_fft_mult_add
   generic (
     selected_device_family  : STRING;
     multiplier1_direction   : STRING;
     number_of_multipliers   : NATURAL;
     width_a                 : NATURAL;
     width_b                 : NATURAL;
     width_result            : NATURAL
  );
  port (
     dataa  : IN  STD_LOGIC_VECTOR (number_of_multipliers * width_a - 1 DOWNTO 0);
     datab  : IN  STD_LOGIC_VECTOR (number_of_multipliers * width_b - 1 DOWNTO 0);
     clock0 : IN  STD_LOGIC;
     aclr0  : IN  STD_LOGIC;
     ena0   : IN  STD_LOGIC;
     result : OUT STD_LOGIC_VECTOR (width_result-1 DOWNTO 0)
  );
  end component;   

BEGIN
     
  paa: PROCESS (sysclk, reset)
  BEGIN
      
    IF (reset = '1') THEN

      aazipff  <= '0';
      aazipff2 <= '0';

      FOR k IN 1 TO 10 LOOP
        aaexponentff(k) <= '0';
        bbexponentff(k) <= '0';
      END LOOP;
      FOR k IN 1 TO 2 LOOP
        FOR j IN 1 TO 10 LOOP
          exponentff(k)(j) <= '0';
        END LOOP;
      END LOOP;
         
    ELSIF (rising_edge(sysclk)) THEN
            
      IF (enable = '1') THEN

        aazipff  <= or_reduce(aaexponent);
        aazipff2 <= aazipff;
          
        aaexponentff <= aaexponent;
        bbexponentff <= bbexponent;    
        -- twiddle +1.0 mantissa is "0100...", effect is divide by 4, add 2 to exponent here 
        -- (subtract 125 instead of 127) 
        exponentff(1)(10 DOWNTO 1) <= aaexponentff + bbexponentff - "0001111101";
        exponentff(2)(10 DOWNTO 1) <= exponentzip(10 DOWNTO 1);
    
      END IF;
        
    END IF;
      
  END PROCESS;

  zip: PROCESS (aazipff2, exponentff(1))
  BEGIN
    CASE aazipff2 IS
      WHEN '0'    => exponentzip(10 DOWNTO 1) <= (others => '0');
      WHEN '1'    => exponentzip(10 DOWNTO 1) <= exponentff(1)(10 DOWNTO 1);
      WHEN others => exponentzip(10 DOWNTO 1) <= exponentff(1)(10 DOWNTO 1);
    END CASE;
  END PROCESS;
  
   MULT_ADD_component : altera_fft_mult_add
   GENERIC MAP (
      selected_device_family => device_family,
      multiplier1_direction => "ADD",
      number_of_multipliers => 1,
      width_a => 32,
      width_b => 32,
      width_result => 64
   )
   PORT MAP (
      dataa => aamantissa,
      datab => bbmantissa,
      clock0 => sysclk,
      aclr0 => reset,
      ena0 => enable,
      result => ccmantissanode
   );

  --*** OUTPUTS ***
   ccmantissa <= ccmantissanode(64 DOWNTO 33);
   ccexponent <= exponentff(2)(10 DOWNTO 1);   
   
END rtl;

