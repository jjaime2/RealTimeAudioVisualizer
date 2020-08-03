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
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_RVSCTL                          ***
--***                                             ***
--***   Function: index reversal address          ***
--***   generator for supported transform length  ***
--***                                             ***
--***   01/09/10 KHP                              ***
--***                                             ***
--***   (c) 2010 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

-- This module has a latency of one cycle.
-- It used to have a latency of two but it's difficult to
-- use it with that latency.
ENTITY apn_fftfp_rvsctl IS
GENERIC (
         pointswidth : positive := 8;
         -- read_addr_gen generic is needed because of the specific
         -- way in which we use this address generator.
         -- To perform digit reversed to natural order conversion 
         -- using a single memory we let the writing happen in seqential 
         -- order and then read that data out in digit reverse order. 
         -- So we need a generic to indicate whether address generator should
         -- start off in sequential or digit-reversed.
         -- Note because we may go through a sequence of reversals for
         -- mixed radix, the writer must start in an earlier order to reader
         read_addr_gen : boolean := false
        );
PORT (
      sysclk  : IN STD_LOGIC;
      reset   : IN STD_LOGIC;
      enable  : IN STD_LOGIC;
      validin : IN STD_LOGIC;
      length  : IN STD_LOGIC_VECTOR (pointswidth+1 DOWNTO 1);
      address  : OUT STD_LOGIC_VECTOR (pointswidth DOWNTO 1);
      validout : OUT STD_LOGIC
     );
END apn_fftfp_rvsctl;

ARCHITECTURE rtl OF apn_fftfp_rvsctl IS
	
  signal length_d      : STD_LOGIC_VECTOR (pointswidth+1 DOWNTO 1);
  
  signal countff     : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal maskff      : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal validoutff  : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal modulo      : STD_LOGIC;
  signal mask_rst    : STD_LOGIC;
  signal addressnode : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal length_ext  : STD_LOGIC_VECTOR (19 DOWNTO 1);

  signal address8node    : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address32node   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address128node  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address512node  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address2knode   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address8knode   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address32knode  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address128knode : STD_LOGIC_VECTOR (18 DOWNTO 1);

  signal address16node   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address64node   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address256node  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address1knode   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address4knode   : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address16knode  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address64knode  : STD_LOGIC_VECTOR (18 DOWNTO 1);
  signal address256knode : STD_LOGIC_VECTOR (18 DOWNTO 1);

  signal modulo8    : STD_LOGIC;
  signal modulo32   : STD_LOGIC;
  signal modulo128  : STD_LOGIC;
  signal modulo512  : STD_LOGIC;
  signal modulo2k   : STD_LOGIC;
  signal modulo8k   : STD_LOGIC;
  signal modulo32k  : STD_LOGIC;
  signal modulo128k : STD_LOGIC;

  signal modulo16   : STD_LOGIC;
  signal modulo64   : STD_LOGIC;
  signal modulo256  : STD_LOGIC;
  signal modulo1k   : STD_LOGIC;
  signal modulo4k   : STD_LOGIC;
  signal modulo16k  : STD_LOGIC;
  signal modulo64k  : STD_LOGIC;
  signal modulo256k : STD_LOGIC;

BEGIN
    
  pda: PROCESS (sysclk) 
  BEGIN
  
    IF (reset = '1') THEN
      
      countff <= conv_std_logic_vector (0,18);
        IF read_addr_gen then
          maskff <= "000000000000000010";
        ELSE
          maskff <= "000000000000000001";
        END IF;
      validoutff <= "0000";
      
    ELSIF (rising_edge(sysclk)) THEN
        
      IF (enable = '1') THEN
    
        IF (validin = '1' AND modulo = '1') THEN
          countff <= conv_std_logic_vector (0,18);
        ELSIF (validin = '1') THEN
          countff <= countff + 1;
        END IF;

        IF ( length /= conv_std_logic_vector(0,pointswidth+1) and length_d /= length ) then
          --This is actually only need when we down-size, because then we may be in an invalid mask.
          --But we are doing it for all size changes here.
          IF read_addr_gen then
            maskff <= "000000000000000010";
          ELSE
            maskff <= "000000000000000001";
          END IF;
        ELSIF (mask_rst = '1') THEN
          maskff <= "000000000000000001"; 
        ELSIF (validin = '1' AND modulo = '1') THEN
          maskff(1) <= maskff(18);
          FOR k IN 2 TO 18 LOOP
            maskff(k) <= maskff(k-1);
          END LOOP;
        END IF;
        
        IF (modulo = '1') THEN
          validoutff(1) <= '1';
        END IF;
        validoutff(2) <= validoutff(1);
        validoutff(3) <= validoutff(2);
        validoutff(4) <= validoutff(3);
         
      END IF;
  
    END IF;
      
  END PROCESS;

  length_d_p : process (sysclk)
  begin
    if ( reset = '1' ) then
      length_d <= conv_std_logic_vector(0,pointswidth+1);
    elsif (rising_edge(sysclk)) then
      if ( enable = '1' ) then
        length_d <= length;
      else
       length_d <= length_d;
      end if;
    end if;
  end process; 

  --*****************
  --***  Radix-4  ***
  --*****************
  
  --length=16
  --[4321]
  --[2143] (start again)
  
  address16node(18 DOWNTO 5) <= "00000000000000"; 
  address16node(4) <= (countff(4) AND (maskff(1))) OR 
                      (countff(2) AND (maskff(2)));
  address16node(3) <= (countff(3) AND (maskff(1))) OR 
                      (countff(1) AND (maskff(2)));
  address16node(2) <= (countff(2) AND (maskff(1))) OR 
                      (countff(4) AND (maskff(2)));
  address16node(1) <= (countff(1) AND (maskff(1))) OR 
                      (countff(3) AND (maskff(2)));

  modulo16 <= countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=64
  --[654321]
  --[214365] (start again)
  
  address64node(18 DOWNTO 7) <= "000000000000"; 
  address64node(6) <= (countff(6) AND (maskff(1))) OR 
                      (countff(2) AND (maskff(2)));
  address64node(5) <= (countff(5) AND (maskff(1))) OR 
                      (countff(1) AND (maskff(2)));
  address64node(4) <= (countff(4) AND (maskff(1))) OR 
                      (countff(4) AND (maskff(2)));
  address64node(3) <= (countff(3) AND (maskff(1))) OR 
                      (countff(3) AND (maskff(2)));
  address64node(2) <= (countff(2) AND (maskff(1))) OR 
                      (countff(6) AND (maskff(2)));
  address64node(1) <= (countff(1) AND (maskff(1))) OR 
                      (countff(5) AND (maskff(2)));

  modulo64 <= countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=256
  --[87654321]
  --[21436587] (start again)
  
  address256node(18 DOWNTO 9) <= "0000000000"; 
  address256node(8) <= (countff(8) AND (maskff(1))) OR 
                       (countff(2) AND (maskff(2)));
  address256node(7) <= (countff(7) AND (maskff(1))) OR 
                       (countff(1) AND (maskff(2)));
  address256node(6) <= (countff(6) AND (maskff(1))) OR 
                       (countff(4) AND (maskff(2)));
  address256node(5) <= (countff(5) AND (maskff(1))) OR 
                       (countff(3) AND (maskff(2)));
  address256node(4) <= (countff(4) AND (maskff(1))) OR 
                       (countff(6) AND (maskff(2)));
  address256node(3) <= (countff(3) AND (maskff(1))) OR 
                       (countff(5) AND (maskff(2)));
  address256node(2) <= (countff(2) AND (maskff(1))) OR 
                       (countff(8) AND (maskff(2)));
  address256node(1) <= (countff(1) AND (maskff(1))) OR 
                       (countff(7) AND (maskff(2)));

  modulo256 <= countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=1024
  --[10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9] (start again)
  
  address1knode(18 DOWNTO 11) <= "00000000"; 
  address1knode(10) <= (countff(10) AND (maskff(1))) OR 
                       (countff(2)  AND (maskff(2)));
  address1knode(9)  <= (countff(9)  AND (maskff(1))) OR 
                       (countff(1)  AND (maskff(2)));
  address1knode(8)  <= (countff(8)  AND (maskff(1))) OR 
                       (countff(4)  AND (maskff(2)));
  address1knode(7)  <= (countff(7)  AND (maskff(1))) OR 
                       (countff(3)  AND (maskff(2)));
  address1knode(6)  <= (countff(6)  AND (maskff(1))) OR 
                       (countff(6)  AND (maskff(2)));
  address1knode(5)  <= (countff(5)  AND (maskff(1))) OR 
                       (countff(5)  AND (maskff(2)));
  address1knode(4)  <= (countff(4)  AND (maskff(1))) OR 
                       (countff(8)  AND (maskff(2)));
  address1knode(3)  <= (countff(3)  AND (maskff(1))) OR 
                       (countff(7)  AND (maskff(2)));
  address1knode(2)  <= (countff(2)  AND (maskff(1))) OR 
                       (countff(10) AND (maskff(2)));
  address1knode(1)  <= (countff(1)  AND (maskff(1))) OR 
                       (countff(9)  AND (maskff(2)));

  modulo1k <= countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=4096
  --[12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11] (start again)
  
  address4knode(18 DOWNTO 13) <= "000000";
  address4knode(12) <= (countff(12) AND (maskff(1))) OR 
                       (countff(2)  AND (maskff(2)));
  address4knode(11) <= (countff(11) AND (maskff(1))) OR 
                       (countff(1)  AND (maskff(2)));
  address4knode(10) <= (countff(10) AND (maskff(1))) OR 
                       (countff(4)  AND (maskff(2)));
  address4knode(9)  <= (countff(9)  AND (maskff(1))) OR 
                       (countff(3)  AND (maskff(2)));
  address4knode(8)  <= (countff(8)  AND (maskff(1))) OR 
                       (countff(6)  AND (maskff(2)));
  address4knode(7)  <= (countff(7)  AND (maskff(1))) OR 
                       (countff(5)  AND (maskff(2)));
  address4knode(6)  <= (countff(6)  AND (maskff(1))) OR 
                       (countff(8)  AND (maskff(2)));
  address4knode(5)  <= (countff(5)  AND (maskff(1))) OR 
                       (countff(7)  AND (maskff(2)));
  address4knode(4)  <= (countff(4)  AND (maskff(1))) OR 
                       (countff(10) AND (maskff(2)));
  address4knode(3)  <= (countff(3)  AND (maskff(1))) OR 
                       (countff(9)  AND (maskff(2)));
  address4knode(2)  <= (countff(2)  AND (maskff(1))) OR 
                       (countff(12) AND (maskff(2)));
  address4knode(1)  <= (countff(1)  AND (maskff(1))) OR 
                       (countff(11) AND (maskff(2)));

  modulo4k <= countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=16384
  --[14 13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 14 13] (start again)
  
  address16knode(18 DOWNTO 15) <= "0000";
  address16knode(14) <= (countff(14) AND (maskff(1))) OR 
                        (countff(2)  AND (maskff(2)));
  address16knode(13) <= (countff(13) AND (maskff(1))) OR 
                        (countff(1)  AND (maskff(2)));
  address16knode(12) <= (countff(12) AND (maskff(1))) OR 
                        (countff(4)  AND (maskff(2)));
  address16knode(11) <= (countff(11) AND (maskff(1))) OR 
                        (countff(3)  AND (maskff(2)));
  address16knode(10) <= (countff(10) AND (maskff(1))) OR 
                        (countff(6)  AND (maskff(2)));
  address16knode(9)  <= (countff(9)  AND (maskff(1))) OR 
                        (countff(5)  AND (maskff(2)));
  address16knode(8)  <= (countff(8)  AND (maskff(1))) OR 
                        (countff(8)  AND (maskff(2)));
  address16knode(7)  <= (countff(7)  AND (maskff(1))) OR 
                        (countff(7)  AND (maskff(2)));
  address16knode(6)  <= (countff(6)  AND (maskff(1))) OR 
                        (countff(10) AND (maskff(2)));
  address16knode(5)  <= (countff(5)  AND (maskff(1))) OR 
                        (countff(9)  AND (maskff(2)));
  address16knode(4)  <= (countff(4)  AND (maskff(1))) OR 
                        (countff(12) AND (maskff(2)));
  address16knode(3)  <= (countff(3)  AND (maskff(1))) OR 
                        (countff(11) AND (maskff(2)));
  address16knode(2)  <= (countff(2)  AND (maskff(1))) OR 
                        (countff(14) AND (maskff(2)));
  address16knode(1)  <= (countff(1)  AND (maskff(1))) OR 
                        (countff(13) AND (maskff(2)));

  modulo16k <= countff(14) AND countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=65536
  --[16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 14 13 16 15] (start again)
  
  address64knode(18 DOWNTO 17) <= "00";
  address64knode(16) <= (countff(16) AND (maskff(1))) OR 
                        (countff(2)  AND (maskff(2)));
  address64knode(15) <= (countff(15) AND (maskff(1))) OR 
                        (countff(1)  AND (maskff(2)));
  address64knode(14) <= (countff(14) AND (maskff(1))) OR 
                        (countff(4)  AND (maskff(2)));
  address64knode(13) <= (countff(13) AND (maskff(1))) OR 
                        (countff(3)  AND (maskff(2)));
  address64knode(12) <= (countff(12) AND (maskff(1))) OR 
                        (countff(6)  AND (maskff(2)));
  address64knode(11) <= (countff(11) AND (maskff(1))) OR 
                        (countff(5)  AND (maskff(2)));
  address64knode(10) <= (countff(10) AND (maskff(1))) OR 
                        (countff(8)  AND (maskff(2)));
  address64knode(9)  <= (countff(9)  AND (maskff(1))) OR 
                        (countff(7)  AND (maskff(2)));
  address64knode(8)  <= (countff(8)  AND (maskff(1))) OR 
                        (countff(10) AND (maskff(2)));
  address64knode(7)  <= (countff(7)  AND (maskff(1))) OR 
                        (countff(9)  AND (maskff(2)));
  address64knode(6)  <= (countff(6)  AND (maskff(1))) OR 
                        (countff(12) AND (maskff(2)));
  address64knode(5)  <= (countff(5)  AND (maskff(1))) OR 
                        (countff(11) AND (maskff(2)));
  address64knode(4)  <= (countff(4)  AND (maskff(1))) OR 
                        (countff(14) AND (maskff(2)));
  address64knode(3)  <= (countff(3)  AND (maskff(1))) OR 
                        (countff(13) AND (maskff(2)));
  address64knode(2)  <= (countff(2)  AND (maskff(1))) OR 
                        (countff(16) AND (maskff(2)));
  address64knode(1)  <= (countff(1)  AND (maskff(1))) OR 
                        (countff(15) AND (maskff(2)));

  modulo64k <= countff(16) AND countff(15) AND countff(14) AND countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=262144
  --[18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 14 13 16 15 18 17] (start again)

  address256knode(18) <= (countff(18) AND (maskff(1))) OR 
                         (countff(2)  AND (maskff(2)));
  address256knode(17) <= (countff(17) AND (maskff(1))) OR 
                         (countff(1)  AND (maskff(2)));  
  address256knode(16) <= (countff(16) AND (maskff(1))) OR 
                         (countff(4)  AND (maskff(2)));
  address256knode(15) <= (countff(15) AND (maskff(1))) OR 
                         (countff(3)  AND (maskff(2)));
  address256knode(14) <= (countff(14) AND (maskff(1))) OR 
                         (countff(6)  AND (maskff(2)));
  address256knode(13) <= (countff(13) AND (maskff(1))) OR 
                         (countff(5)  AND (maskff(2)));
  address256knode(12) <= (countff(12) AND (maskff(1))) OR 
                         (countff(8)  AND (maskff(2)));
  address256knode(11) <= (countff(11) AND (maskff(1))) OR 
                         (countff(7)  AND (maskff(2)));
  address256knode(10) <= (countff(10) AND (maskff(1))) OR 
                         (countff(10) AND (maskff(2)));
  address256knode(9)  <= (countff(9)  AND (maskff(1))) OR 
                         (countff(9)  AND (maskff(2)));
  address256knode(8)  <= (countff(8)  AND (maskff(1))) OR 
                         (countff(12) AND (maskff(2)));
  address256knode(7)  <= (countff(7)  AND (maskff(1))) OR 
                         (countff(11) AND (maskff(2)));
  address256knode(6)  <= (countff(6)  AND (maskff(1))) OR 
                         (countff(14) AND (maskff(2)));
  address256knode(5)  <= (countff(5)  AND (maskff(1))) OR 
                         (countff(13) AND (maskff(2)));
  address256knode(4)  <= (countff(4)  AND (maskff(1))) OR 
                         (countff(16) AND (maskff(2)));
  address256knode(3)  <= (countff(3)  AND (maskff(1))) OR 
                         (countff(15) AND (maskff(2)));
  address256knode(2)  <= (countff(2)  AND (maskff(1))) OR 
                         (countff(18) AND (maskff(2)));
  address256knode(1)  <= (countff(1)  AND (maskff(1))) OR 
                         (countff(17) AND (maskff(2)));

  modulo256k <= countff(18) AND countff(17) AND countff(16) AND countff(15) AND countff(14) AND countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --*************************
  --***  Mixed Radix-4/2  ***
  --*************************

  --length=8
  --[321]
  --[213]
  --[132]
  --[321] (start again)
  
  address8node(18 DOWNTO 4) <= "000000000000000"; 
  address8node(3) <= (countff(3) AND (maskff(1))) OR 
                     (countff(2) AND (maskff(2))) OR 
                     (countff(1) AND (maskff(3))); 
  address8node(2) <= (countff(2) AND (maskff(1))) OR 
                     (countff(1) AND (maskff(2))) OR 
                     (countff(3) AND (maskff(3)));
  address8node(1) <= (countff(1) AND (maskff(1))) OR 
                     (countff(3) AND (maskff(2))) OR 
                     (countff(2) AND (maskff(3)));
                                                                                          
  modulo8 <= countff(3) AND countff(2) AND countff(1);

  --length=32
  --[54321]
  --[21435]
  --[35142]
  --[42513]
  --[13254]
  --[54321] (start again)
  
  address32node(18 DOWNTO 6) <= "0000000000000"; 
  address32node(5) <= (countff(5) AND (maskff(1))) OR 
                      (countff(2) AND (maskff(2))) OR 
                      (countff(3) AND (maskff(3))) OR 
                      (countff(4) AND (maskff(4))) OR 
                      (countff(1) AND (maskff(5)));
  address32node(4) <= (countff(4) AND (maskff(1))) OR 
                      (countff(1) AND (maskff(2))) OR 
                      (countff(5) AND (maskff(3))) OR 
                      (countff(2) AND (maskff(4))) OR 
                      (countff(3) AND (maskff(5)));
  address32node(3) <= (countff(3) AND (maskff(1))) OR 
                      (countff(4) AND (maskff(2))) OR 
                      (countff(1) AND (maskff(3))) OR 
                      (countff(5) AND (maskff(4))) OR
                      (countff(2) AND (maskff(5)));
  address32node(2) <= (countff(2) AND (maskff(1))) OR 
                      (countff(3) AND (maskff(2))) OR 
                      (countff(4) AND (maskff(3))) OR 
                      (countff(1) AND (maskff(4))) OR 
                      (countff(5) AND (maskff(5)));
  address32node(1) <= (countff(1) AND (maskff(1))) OR 
                      (countff(5) AND (maskff(2))) OR 
                      (countff(2) AND (maskff(3))) OR 
                      (countff(3) AND (maskff(4))) OR 
                      (countff(4) AND (maskff(5)));
                                                                                          
  modulo32 <= countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=128
  --[7654321]
  --[2143657]
  --[5736142]
  --[4261735]
  --[3517264]
  --[6472513]
  --[1325476]
  --[7654321] (start again)
  
  address128node(18 DOWNTO 8) <= "00000000000"; 
  address128node(7) <= (countff(7) AND maskff(1)) OR 
                       (countff(2) AND maskff(2)) OR 
                       (countff(5) AND maskff(3)) OR 
                       (countff(4) AND maskff(4)) OR 
                       (countff(3) AND maskff(5)) OR
                       (countff(6) AND maskff(6)) OR
                       (countff(1) AND maskff(7));
  address128node(6) <= (countff(6) AND maskff(1)) OR 
                       (countff(1) AND maskff(2)) OR 
                       (countff(7) AND maskff(3)) OR 
                       (countff(2) AND maskff(4)) OR 
                       (countff(5) AND maskff(5)) OR
                       (countff(4) AND maskff(6)) OR
                       (countff(3) AND maskff(7));
  address128node(5) <= (countff(5) AND maskff(1)) OR 
                       (countff(4) AND maskff(2)) OR 
                       (countff(3) AND maskff(3)) OR 
                       (countff(6) AND maskff(4)) OR 
                       (countff(1) AND maskff(5)) OR
                       (countff(7) AND maskff(6)) OR
                       (countff(2) AND maskff(7));                    
  address128node(4) <= (countff(4) AND maskff(1)) OR 
                       (countff(3) AND maskff(2)) OR 
                       (countff(6) AND maskff(3)) OR 
                       (countff(1) AND maskff(4)) OR 
                       (countff(7) AND maskff(5)) OR
                       (countff(2) AND maskff(6)) OR
                       (countff(5) AND maskff(7)); 
  address128node(3) <= (countff(3) AND maskff(1)) OR 
                       (countff(6) AND maskff(2)) OR 
                       (countff(1) AND maskff(3)) OR 
                       (countff(7) AND maskff(4)) OR 
                       (countff(2) AND maskff(5)) OR
                       (countff(5) AND maskff(6)) OR
                       (countff(4) AND maskff(7)); 
  address128node(2) <= (countff(2) AND maskff(1)) OR 
                       (countff(5) AND maskff(2)) OR 
                       (countff(4) AND maskff(3)) OR 
                       (countff(3) AND maskff(4)) OR 
                       (countff(6) AND maskff(5)) OR
                       (countff(1) AND maskff(6)) OR
                       (countff(7) AND maskff(7)); 
  address128node(1) <= (countff(1) AND maskff(1)) OR 
                       (countff(7) AND maskff(2)) OR 
                       (countff(2) AND maskff(3)) OR 
                       (countff(5) AND maskff(4)) OR 
                       (countff(4) AND maskff(5)) OR
                       (countff(3) AND maskff(6)) OR
                       (countff(6) AND maskff(7));

  modulo128 <= countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=512
  --[987654321]
  --[214365879]
  --[795836142]
  --[426183957]
  --[573918264]
  --[648291735]
  --[351729486]
  --[869472513]
  --[132547698]
  --[987654321] (start again)

  address512node(18 DOWNTO 10) <= "000000000"; 
  address512node(9) <= (countff(9) AND maskff(1)) OR 
                       (countff(2) AND maskff(2)) OR 
                       (countff(7) AND maskff(3)) OR 
                       (countff(4) AND maskff(4)) OR 
                       (countff(5) AND maskff(5)) OR
                       (countff(6) AND maskff(6)) OR
                       (countff(3) AND maskff(7)) OR
                       (countff(8) AND maskff(8)) OR
                       (countff(1) AND maskff(9));
  address512node(8) <= (countff(8) AND maskff(1)) OR 
                       (countff(1) AND maskff(2)) OR 
                       (countff(9) AND maskff(3)) OR 
                       (countff(2) AND maskff(4)) OR 
                       (countff(7) AND maskff(5)) OR
                       (countff(4) AND maskff(6)) OR
                       (countff(5) AND maskff(7)) OR
                       (countff(6) AND maskff(8)) OR
                       (countff(3) AND maskff(9));
  address512node(7) <= (countff(7) AND maskff(1)) OR 
                       (countff(4) AND maskff(2)) OR 
                       (countff(5) AND maskff(3)) OR 
                       (countff(6) AND maskff(4)) OR 
                       (countff(3) AND maskff(5)) OR
                       (countff(8) AND maskff(6)) OR
                       (countff(1) AND maskff(7)) OR
                       (countff(9) AND maskff(8)) OR
                       (countff(2) AND maskff(9));
  address512node(6) <= (countff(6) AND maskff(1)) OR 
                       (countff(3) AND maskff(2)) OR 
                       (countff(8) AND maskff(3)) OR 
                       (countff(1) AND maskff(4)) OR 
                       (countff(9) AND maskff(5)) OR
                       (countff(2) AND maskff(6)) OR
                       (countff(7) AND maskff(7)) OR
                       (countff(4) AND maskff(8)) OR
                       (countff(5) AND maskff(9));                    
  address512node(5) <= (countff(5) AND maskff(1)) OR 
                       (countff(6) AND maskff(2)) OR 
                       (countff(3) AND maskff(3)) OR 
                       (countff(8) AND maskff(4)) OR 
                       (countff(1) AND maskff(5)) OR
                       (countff(9) AND maskff(6)) OR
                       (countff(2) AND maskff(7)) OR
                       (countff(7) AND maskff(8)) OR
                       (countff(4) AND maskff(9)); 
  address512node(4) <= (countff(4) AND maskff(1)) OR 
                       (countff(5) AND maskff(2)) OR 
                       (countff(6) AND maskff(3)) OR 
                       (countff(3) AND maskff(4)) OR 
                       (countff(8) AND maskff(5)) OR
                       (countff(1) AND maskff(6)) OR
                       (countff(9) AND maskff(7)) OR
                       (countff(2) AND maskff(8)) OR
                       (countff(7) AND maskff(9)); 
  address512node(3) <= (countff(3) AND maskff(1)) OR 
                       (countff(8) AND maskff(2)) OR 
                       (countff(1) AND maskff(3)) OR 
                       (countff(9) AND maskff(4)) OR 
                       (countff(2) AND maskff(5)) OR
                       (countff(7) AND maskff(6)) OR
                       (countff(4) AND maskff(7)) OR
                       (countff(5) AND maskff(8)) OR
                       (countff(6) AND maskff(9));
  address512node(2) <= (countff(2) AND maskff(1)) OR 
                       (countff(7) AND maskff(2)) OR 
                       (countff(4) AND maskff(3)) OR 
                       (countff(5) AND maskff(4)) OR 
                       (countff(6) AND maskff(5)) OR
                       (countff(3) AND maskff(6)) OR
                       (countff(8) AND maskff(7)) OR
                       (countff(1) AND maskff(8)) OR
                       (countff(9) AND maskff(9));  
  address512node(1) <= (countff(1) AND maskff(1)) OR 
                       (countff(9) AND maskff(2)) OR 
                       (countff(2) AND maskff(3)) OR 
                       (countff(7) AND maskff(4)) OR 
                       (countff(4) AND maskff(5)) OR
                       (countff(5) AND maskff(6)) OR
                       (countff(6) AND maskff(7)) OR
                       (countff(3) AND maskff(8)) OR
                       (countff(8) AND maskff(9));
  
  modulo512 <= countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);
  
  
  --length=2048
  --[11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 11]
  --[ 9 11  7 10  5  8  3  6  1  4  2]
  --[ 4  2  6  1  8  3 10  5 11  7  9]
  --[ 7  9  5 11  3 10  1  8  2  6  4]
  --[ 6  4  8  2 10  1 11  3  9  5  7]
  --[ 5  7  3  9  1 11  2 10  4  8  6]
  --[ 8  6 10  4 11  2  9  1  7  3  5]
  --[ 3  5  1  7  2  9  4 11  6 10  8]
  --[10  8 11  6  9  4  7  2  5  1  3]
  --[ 1  3  2  5  4  7  6  9  8 11 10]
  --[11 10  9  8  7  6  5  4  3  2  1] (start again)
 
  address2knode(18 DOWNTO 12) <= "0000000"; 
  address2knode(11) <= (countff(11) AND maskff(1))  OR 
                       (countff(2)  AND maskff(2))  OR 
                       (countff(9)  AND maskff(3))  OR 
                       (countff(4)  AND maskff(4))  OR 
                       (countff(7)  AND maskff(5))  OR
                       (countff(6)  AND maskff(6))  OR
                       (countff(5)  AND maskff(7))  OR
                       (countff(8)  AND maskff(8))  OR
                       (countff(3)  AND maskff(9))  OR
                       (countff(10) AND maskff(10)) OR
                       (countff(1)  AND maskff(11));
  address2knode(10) <= (countff(10) AND maskff(1))  OR 
                       (countff(1)  AND maskff(2))  OR 
                       (countff(11) AND maskff(3))  OR 
                       (countff(2)  AND maskff(4))  OR 
                       (countff(9)  AND maskff(5))  OR
                       (countff(4)  AND maskff(6))  OR
                       (countff(7)  AND maskff(7))  OR
                       (countff(6)  AND maskff(8))  OR
                       (countff(5)  AND maskff(9))  OR
                       (countff(8)  AND maskff(10)) OR
                       (countff(3)  AND maskff(11));
  address2knode(9)  <= (countff(9)  AND maskff(1))  OR 
                       (countff(4)  AND maskff(2))  OR 
                       (countff(7)  AND maskff(3))  OR 
                       (countff(6)  AND maskff(4))  OR 
                       (countff(5)  AND maskff(5))  OR
                       (countff(8)  AND maskff(6))  OR
                       (countff(3)  AND maskff(7))  OR
                       (countff(10) AND maskff(8))  OR
                       (countff(1)  AND maskff(9))  OR
                       (countff(11) AND maskff(10)) OR
                       (countff(2)  AND maskff(11));
  address2knode(8)  <= (countff(8)  AND maskff(1))  OR 
                       (countff(3)  AND maskff(2))  OR 
                       (countff(10) AND maskff(3))  OR 
                       (countff(1)  AND maskff(4))  OR 
                       (countff(11) AND maskff(5))  OR
                       (countff(2)  AND maskff(6))  OR
                       (countff(9)  AND maskff(7))  OR
                       (countff(4)  AND maskff(8))  OR
                       (countff(7)  AND maskff(9))  OR
                       (countff(6)  AND maskff(10)) OR
                       (countff(5)  AND maskff(11));
  address2knode(7)  <= (countff(7)  AND maskff(1))  OR 
                       (countff(6)  AND maskff(2))  OR 
                       (countff(5)  AND maskff(3))  OR 
                       (countff(8)  AND maskff(4))  OR 
                       (countff(3)  AND maskff(5))  OR
                       (countff(10) AND maskff(6))  OR
                       (countff(1)  AND maskff(7))  OR
                       (countff(11) AND maskff(8))  OR
                       (countff(2)  AND maskff(9))  OR
                       (countff(9)  AND maskff(10)) OR
                       (countff(4)  AND maskff(11));
  address2knode(6)  <= (countff(6)  AND maskff(1))  OR 
                       (countff(5)  AND maskff(2))  OR 
                       (countff(8)  AND maskff(3))  OR 
                       (countff(3)  AND maskff(4))  OR 
                       (countff(10) AND maskff(5))  OR
                       (countff(1)  AND maskff(6))  OR
                       (countff(11) AND maskff(7))  OR
                       (countff(2)  AND maskff(8))  OR
                       (countff(9)  AND maskff(9))  OR
                       (countff(4)  AND maskff(10)) OR
                       (countff(7)  AND maskff(11));
  address2knode(5)  <= (countff(5)  AND maskff(1))  OR 
                       (countff(8)  AND maskff(2))  OR 
                       (countff(3)  AND maskff(3))  OR 
                       (countff(10) AND maskff(4))  OR 
                       (countff(1)  AND maskff(5))  OR
                       (countff(11) AND maskff(6))  OR
                       (countff(2)  AND maskff(7))  OR
                       (countff(9)  AND maskff(8))  OR
                       (countff(4)  AND maskff(9))  OR 
                       (countff(7)  AND maskff(10)) OR 
                       (countff(6)  AND maskff(11));
  address2knode(4)  <= (countff(4)  AND maskff(1))  OR 
                       (countff(7)  AND maskff(2))  OR 
                       (countff(6)  AND maskff(3))  OR 
                       (countff(5)  AND maskff(4))  OR 
                       (countff(8)  AND maskff(5))  OR
                       (countff(3)  AND maskff(6))  OR
                       (countff(10) AND maskff(7))  OR
                       (countff(1)  AND maskff(8))  OR
                       (countff(11) AND maskff(9))  OR 
                       (countff(2)  AND maskff(10)) OR 
                       (countff(9)  AND maskff(11));
  address2knode(3)  <= (countff(3)  AND maskff(1))  OR 
                       (countff(10) AND maskff(2))  OR 
                       (countff(1)  AND maskff(3))  OR 
                       (countff(11) AND maskff(4))  OR 
                       (countff(2)  AND maskff(5))  OR
                       (countff(9)  AND maskff(6))  OR
                       (countff(4)  AND maskff(7))  OR
                       (countff(7)  AND maskff(8))  OR
                       (countff(6)  AND maskff(9))  OR
                       (countff(5)  AND maskff(10)) OR
                       (countff(8)  AND maskff(11));
  address2knode(2)  <= (countff(2)  AND maskff(1))  OR 
                       (countff(9)  AND maskff(2))  OR 
                       (countff(4)  AND maskff(3))  OR 
                       (countff(7)  AND maskff(4))  OR 
                       (countff(6)  AND maskff(5))  OR
                       (countff(5)  AND maskff(6))  OR
                       (countff(8)  AND maskff(7))  OR
                       (countff(3)  AND maskff(8))  OR
                       (countff(10) AND maskff(9))  OR  
                       (countff(1)  AND maskff(10)) OR  
                       (countff(11) AND maskff(11));   
  address2knode(1)  <= (countff(1)  AND maskff(1))  OR 
                       (countff(11) AND maskff(2))  OR 
                       (countff(2)  AND maskff(3))  OR 
                       (countff(9)  AND maskff(4))  OR 
                       (countff(4)  AND maskff(5))  OR
                       (countff(7)  AND maskff(6))  OR
                       (countff(6)  AND maskff(7))  OR
                       (countff(5)  AND maskff(8))  OR
                       (countff(8)  AND maskff(9))  OR
                       (countff(3)  AND maskff(10)) OR
                       (countff(10) AND maskff(11));
  
  modulo2k <= countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=8192
  --[13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 13]
  --[11 13  9 12  7 10  5  8  3  6  1  4  2]
  --[ 4  2  6  1  8  3 10  5 12  7 13  9 11]
  --[ 9 11  7 13  5 12  3 10  1  8  2  6  4]
  --[ 6  4  8  2 10  1 12  3 13  5 11  7  9]
  --[ 7  9  5 11  3 13  1 12  2 10  4  8  6]
  --[ 8  6 10  4 12  2 13  1 11  3  9  5  7]
  --[ 5  7  3  9  1 11  2 13  4 12  6 10  8]
  --[10  8 12  6 13  4 11  2  9  1  7  3  5]
  --[ 3  5  1  7  2  9  4 11  6 13  8 12 10]
  --[12 10 13  8 11  6  9  4  7  2  5  1  3]
  --[ 1  3  2  5  4  7  6  9  8 11 10 13 12]
  --[13 12 11 10  9  8  7  6  5  4  3  2  1] (start again)
 
  address8knode(18 DOWNTO 14) <= "00000"; 
  address8knode(13) <= (countff(13) AND maskff(1))  OR 
                       (countff(2)  AND maskff(2))  OR 
                       (countff(11) AND maskff(3))  OR 
                       (countff(4)  AND maskff(4))  OR 
                       (countff(9)  AND maskff(5))  OR
                       (countff(6)  AND maskff(6))  OR
                       (countff(7)  AND maskff(7))  OR
                       (countff(8)  AND maskff(8))  OR
                       (countff(5)  AND maskff(9))  OR
                       (countff(10) AND maskff(10)) OR
                       (countff(3)  AND maskff(11)) OR
                       (countff(12) AND maskff(12)) OR
                       (countff(1)  AND maskff(13)); 
  address8knode(12) <= (countff(12) AND maskff(1))  OR 
                       (countff(1)  AND maskff(2))  OR 
                       (countff(13) AND maskff(3))  OR 
                       (countff(2)  AND maskff(4))  OR 
                       (countff(11) AND maskff(5))  OR
                       (countff(4)  AND maskff(6))  OR
                       (countff(9)  AND maskff(7))  OR
                       (countff(6)  AND maskff(8))  OR
                       (countff(7)  AND maskff(9))  OR
                       (countff(8)  AND maskff(10)) OR
                       (countff(5)  AND maskff(11)) OR
                       (countff(10) AND maskff(12)) OR
                       (countff(3)  AND maskff(13)); 
  address8knode(11) <= (countff(11) AND maskff(1))  OR 
                       (countff(4)  AND maskff(2))  OR 
                       (countff(9)  AND maskff(3))  OR 
                       (countff(6)  AND maskff(4))  OR 
                       (countff(7)  AND maskff(5))  OR
                       (countff(8)  AND maskff(6))  OR
                       (countff(5)  AND maskff(7))  OR
                       (countff(10) AND maskff(8))  OR
                       (countff(3)  AND maskff(9))  OR
                       (countff(12) AND maskff(10)) OR
                       (countff(1)  AND maskff(11)) OR
                       (countff(13) AND maskff(12)) OR
                       (countff(2)  AND maskff(13)); 
  address8knode(10) <= (countff(10) AND maskff(1))  OR 
                       (countff(3)  AND maskff(2))  OR 
                       (countff(12) AND maskff(3))  OR 
                       (countff(1)  AND maskff(4))  OR 
                       (countff(13) AND maskff(5))  OR
                       (countff(2)  AND maskff(6))  OR
                       (countff(11) AND maskff(7))  OR
                       (countff(4)  AND maskff(8))  OR
                       (countff(9)  AND maskff(9))  OR
                       (countff(6)  AND maskff(10)) OR
                       (countff(7)  AND maskff(11)) OR
                       (countff(8)  AND maskff(12)) OR
                       (countff(5)  AND maskff(13)); 
  address8knode(9)  <= (countff(9)  AND maskff(1))  OR 
                       (countff(6)  AND maskff(2))  OR 
                       (countff(7)  AND maskff(3))  OR 
                       (countff(8)  AND maskff(4))  OR 
                       (countff(5)  AND maskff(5))  OR
                       (countff(10) AND maskff(6))  OR
                       (countff(3)  AND maskff(7))  OR
                       (countff(12) AND maskff(8))  OR
                       (countff(1)  AND maskff(9))  OR
                       (countff(13) AND maskff(10)) OR
                       (countff(2)  AND maskff(11)) OR
                       (countff(11) AND maskff(12)) OR
                       (countff(4)  AND maskff(13)); 
  address8knode(8)  <= (countff(8)  AND maskff(1))  OR 
                       (countff(5)  AND maskff(2))  OR 
                       (countff(10) AND maskff(3))  OR 
                       (countff(3)  AND maskff(4))  OR 
                       (countff(12) AND maskff(5))  OR
                       (countff(1)  AND maskff(6))  OR
                       (countff(13) AND maskff(7))  OR
                       (countff(2)  AND maskff(8))  OR
                       (countff(11) AND maskff(9))  OR
                       (countff(4)  AND maskff(10)) OR
                       (countff(9)  AND maskff(11)) OR
                       (countff(6)  AND maskff(12)) OR
                       (countff(7)  AND maskff(13)); 
  address8knode(7)  <= (countff(7)  AND maskff(1))  OR 
                       (countff(8)  AND maskff(2))  OR 
                       (countff(5)  AND maskff(3))  OR 
                       (countff(10) AND maskff(4))  OR 
                       (countff(3)  AND maskff(5))  OR
                       (countff(12) AND maskff(6))  OR
                       (countff(1)  AND maskff(7))  OR
                       (countff(13) AND maskff(8))  OR
                       (countff(2)  AND maskff(9))  OR
                       (countff(11) AND maskff(10)) OR
                       (countff(4)  AND maskff(11)) OR
                       (countff(9)  AND maskff(12)) OR
                       (countff(6)  AND maskff(13)); 
  address8knode(6)  <= (countff(6)  AND maskff(1))  OR 
                       (countff(7)  AND maskff(2))  OR 
                       (countff(8)  AND maskff(3))  OR 
                       (countff(5)  AND maskff(4))  OR 
                       (countff(10) AND maskff(5))  OR
                       (countff(3)  AND maskff(6))  OR
                       (countff(12) AND maskff(7))  OR
                       (countff(1)  AND maskff(8))  OR
                       (countff(13) AND maskff(9))  OR
                       (countff(2)  AND maskff(10)) OR
                       (countff(11) AND maskff(11)) OR
                       (countff(4)  AND maskff(12)) OR
                       (countff(9)  AND maskff(13)); 
  address8knode(5)  <= (countff(5)  AND maskff(1))  OR 
                       (countff(10) AND maskff(2))  OR 
                       (countff(3)  AND maskff(3))  OR 
                       (countff(12) AND maskff(4))  OR 
                       (countff(1)  AND maskff(5))  OR
                       (countff(13) AND maskff(6))  OR
                       (countff(2)  AND maskff(7))  OR
                       (countff(11) AND maskff(8))  OR
                       (countff(4)  AND maskff(9))  OR 
                       (countff(9)  AND maskff(10)) OR 
                       (countff(6)  AND maskff(11)) OR
                       (countff(7)  AND maskff(12)) OR
                       (countff(8)  AND maskff(13));
  address8knode(4)  <= (countff(4)  AND maskff(1))  OR 
                       (countff(9)  AND maskff(2))  OR 
                       (countff(6)  AND maskff(3))  OR 
                       (countff(7)  AND maskff(4))  OR 
                       (countff(8)  AND maskff(5))  OR
                       (countff(5)  AND maskff(6))  OR
                       (countff(10) AND maskff(7))  OR
                       (countff(3)  AND maskff(8))  OR
                       (countff(12) AND maskff(9))  OR 
                       (countff(1)  AND maskff(10)) OR 
                       (countff(13) AND maskff(11)) OR
                       (countff(2)  AND maskff(12)) OR
                       (countff(11) AND maskff(13));
  address8knode(3)  <= (countff(3)  AND maskff(1))  OR 
                       (countff(12) AND maskff(2))  OR 
                       (countff(1)  AND maskff(3))  OR 
                       (countff(13) AND maskff(4))  OR 
                       (countff(2)  AND maskff(5))  OR
                       (countff(11) AND maskff(6))  OR
                       (countff(4)  AND maskff(7))  OR
                       (countff(9)  AND maskff(8))  OR
                       (countff(6)  AND maskff(9))  OR
                       (countff(7)  AND maskff(10)) OR
                       (countff(8)  AND maskff(11)) OR
                       (countff(5)  AND maskff(12)) OR
                       (countff(10) AND maskff(13)); 
  address8knode(2)  <= (countff(2)  AND maskff(1))  OR 
                       (countff(11) AND maskff(2))  OR 
                       (countff(4)  AND maskff(3))  OR 
                       (countff(9)  AND maskff(4))  OR 
                       (countff(6)  AND maskff(5))  OR
                       (countff(7)  AND maskff(6))  OR
                       (countff(8)  AND maskff(7))  OR
                       (countff(5)  AND maskff(8))  OR
                       (countff(10) AND maskff(9))  OR  
                       (countff(3)  AND maskff(10)) OR  
                       (countff(12) AND maskff(11)) OR   
                       (countff(1)  AND maskff(12)) OR   
                       (countff(13) AND maskff(13)); 
  address8knode(1)  <= (countff(1)  AND maskff(1))  OR 
                       (countff(13) AND maskff(2))  OR 
                       (countff(2)  AND maskff(3))  OR 
                       (countff(11) AND maskff(4))  OR 
                       (countff(4)  AND maskff(5))  OR
                       (countff(9)  AND maskff(6))  OR
                       (countff(6)  AND maskff(7))  OR
                       (countff(7)  AND maskff(8))  OR
                       (countff(8)  AND maskff(9))  OR
                       (countff(5)  AND maskff(10)) OR
                       (countff(10) AND maskff(11)) OR
                       (countff(3)  AND maskff(12)) OR
                       (countff(12) AND maskff(13));
  
  modulo8k <= countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=32768
  --[15 14 13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 14 13 15]
  --[13 15 11 14  9 12  7 10  5  8  3  6  1  4  2]
  --[ 4  2  6  1  8  3 10  5 12  7 14  9 15 11 13]
  --[11 13  9 15  7 14  5 12  3 10  1  8  2  6  4]
  --[ 6  4  8  2 10  1 12  3 14  5 15  7 13  9 11]
  --[ 9 11  7 13  5 15  3 14  1 12  2 10  4  8  6]
  --[ 8  6 10  4 12  2 14  1 15  3 13  5 11  7  9]
  --[ 7  9  5 11  3 13  1 15  2 14  4 12  6 10  8]
  --[10  8 12  6 14  4 15  2 13  1 11  3  9  5  7]
  --[ 5  7  3  9  1 11  2 13  4 15  6 14  8 12 10]
  --[12 10 14  8 15  6 13  4 11  2  9  1  7  3  5]
  --[ 3  5  1  7  2  9  4 11  6 13  8 15 10 14 12]
  --[14 12 15 10 13  8 11  6  9  4  7  2  5  1  3]
  --[ 1  3  2  5  4  7  6  9  8 11 10 13 12 15 14]
  --[15 14 13 12 11 10  9  8  7  6  5  4  3  2  1] (start again)
 
  address32knode(18 DOWNTO 16) <= "000"; 
  address32knode(15) <= (countff(15) AND maskff(1))  OR 
                        (countff(2)  AND maskff(2))  OR 
                        (countff(13) AND maskff(3))  OR 
                        (countff(4)  AND maskff(4))  OR 
                        (countff(11) AND maskff(5))  OR
                        (countff(6)  AND maskff(6))  OR
                        (countff(9)  AND maskff(7))  OR
                        (countff(8)  AND maskff(8))  OR
                        (countff(7)  AND maskff(9))  OR
                        (countff(10) AND maskff(10)) OR
                        (countff(5)  AND maskff(11)) OR
                        (countff(12) AND maskff(12)) OR
                        (countff(3)  AND maskff(13)) OR 
                        (countff(14) AND maskff(14)) OR 
                        (countff(1)  AND maskff(15));
  address32knode(14) <= (countff(14) AND maskff(1))  OR 
                        (countff(1)  AND maskff(2))  OR 
                        (countff(15) AND maskff(3))  OR 
                        (countff(2)  AND maskff(4))  OR 
                        (countff(13) AND maskff(5))  OR
                        (countff(4)  AND maskff(6))  OR
                        (countff(11) AND maskff(7))  OR
                        (countff(6)  AND maskff(8))  OR
                        (countff(9)  AND maskff(9))  OR
                        (countff(8)  AND maskff(10)) OR
                        (countff(7)  AND maskff(11)) OR
                        (countff(10) AND maskff(12)) OR
                        (countff(5)  AND maskff(13)) OR 
                        (countff(12) AND maskff(14)) OR 
                        (countff(3)  AND maskff(15)); 
  address32knode(13) <= (countff(13) AND maskff(1))  OR 
                        (countff(4)  AND maskff(2))  OR 
                        (countff(11) AND maskff(3))  OR 
                        (countff(6)  AND maskff(4))  OR 
                        (countff(9)  AND maskff(5))  OR
                        (countff(8)  AND maskff(6))  OR
                        (countff(7)  AND maskff(7))  OR
                        (countff(10) AND maskff(8))  OR
                        (countff(5)  AND maskff(9))  OR
                        (countff(12) AND maskff(10)) OR
                        (countff(3)  AND maskff(11)) OR
                        (countff(14) AND maskff(12)) OR
                        (countff(1)  AND maskff(13)) OR 
                        (countff(15) AND maskff(14)) OR 
                        (countff(2)  AND maskff(15)); 
  address32knode(12) <= (countff(12) AND maskff(1))  OR 
                        (countff(3)  AND maskff(2))  OR 
                        (countff(14) AND maskff(3))  OR 
                        (countff(1)  AND maskff(4))  OR 
                        (countff(15) AND maskff(5))  OR
                        (countff(2)  AND maskff(6))  OR
                        (countff(13) AND maskff(7))  OR
                        (countff(4)  AND maskff(8))  OR
                        (countff(11) AND maskff(9))  OR
                        (countff(6)  AND maskff(10)) OR
                        (countff(9)  AND maskff(11)) OR
                        (countff(8)  AND maskff(12)) OR
                        (countff(7)  AND maskff(13)) OR 
                        (countff(10) AND maskff(14)) OR 
                        (countff(5)  AND maskff(15)); 
  address32knode(11) <= (countff(11) AND maskff(1))  OR 
                        (countff(6)  AND maskff(2))  OR 
                        (countff(9)  AND maskff(3))  OR 
                        (countff(8)  AND maskff(4))  OR 
                        (countff(7)  AND maskff(5))  OR
                        (countff(10) AND maskff(6))  OR
                        (countff(5)  AND maskff(7))  OR
                        (countff(12) AND maskff(8))  OR
                        (countff(3)  AND maskff(9))  OR
                        (countff(14) AND maskff(10)) OR
                        (countff(1)  AND maskff(11)) OR
                        (countff(15) AND maskff(12)) OR
                        (countff(2)  AND maskff(13)) OR 
                        (countff(13) AND maskff(14)) OR 
                        (countff(4)  AND maskff(15)); 
  address32knode(10) <= (countff(10) AND maskff(1))  OR 
                        (countff(5)  AND maskff(2))  OR 
                        (countff(12) AND maskff(3))  OR 
                        (countff(3)  AND maskff(4))  OR 
                        (countff(14) AND maskff(5))  OR
                        (countff(1)  AND maskff(6))  OR
                        (countff(15) AND maskff(7))  OR
                        (countff(2)  AND maskff(8))  OR
                        (countff(13) AND maskff(9))  OR
                        (countff(4)  AND maskff(10)) OR
                        (countff(11) AND maskff(11)) OR
                        (countff(6)  AND maskff(12)) OR
                        (countff(9)  AND maskff(13)) OR 
                        (countff(8)  AND maskff(14)) OR 
                        (countff(7)  AND maskff(15)); 
  address32knode(9)  <= (countff(9)  AND maskff(1))  OR 
                        (countff(8)  AND maskff(2))  OR 
                        (countff(7)  AND maskff(3))  OR 
                        (countff(10) AND maskff(4))  OR 
                        (countff(5)  AND maskff(5))  OR
                        (countff(12) AND maskff(6))  OR
                        (countff(3)  AND maskff(7))  OR
                        (countff(14) AND maskff(8))  OR
                        (countff(1)  AND maskff(9))  OR
                        (countff(15) AND maskff(10)) OR
                        (countff(2)  AND maskff(11)) OR
                        (countff(13) AND maskff(12)) OR
                        (countff(4)  AND maskff(13)) OR 
                        (countff(11) AND maskff(14)) OR 
                        (countff(6)  AND maskff(15)); 
  address32knode(8)  <= (countff(8)  AND maskff(1))  OR 
                        (countff(7)  AND maskff(2))  OR 
                        (countff(10) AND maskff(3))  OR 
                        (countff(5)  AND maskff(4))  OR 
                        (countff(12) AND maskff(5))  OR
                        (countff(3)  AND maskff(6))  OR
                        (countff(14) AND maskff(7))  OR
                        (countff(1)  AND maskff(8))  OR
                        (countff(15) AND maskff(9))  OR
                        (countff(2)  AND maskff(10)) OR
                        (countff(13) AND maskff(11)) OR
                        (countff(4)  AND maskff(12)) OR
                        (countff(11) AND maskff(13)) OR 
                        (countff(6)  AND maskff(14)) OR 
                        (countff(9)  AND maskff(15)); 
  address32knode(7)  <= (countff(7)  AND maskff(1))  OR 
                        (countff(10) AND maskff(2))  OR 
                        (countff(5)  AND maskff(3))  OR 
                        (countff(12) AND maskff(4))  OR 
                        (countff(3)  AND maskff(5))  OR
                        (countff(14) AND maskff(6))  OR
                        (countff(1)  AND maskff(7))  OR
                        (countff(15) AND maskff(8))  OR
                        (countff(2)  AND maskff(9))  OR
                        (countff(13) AND maskff(10)) OR
                        (countff(4)  AND maskff(11)) OR
                        (countff(11) AND maskff(12)) OR
                        (countff(6)  AND maskff(13)) OR 
                        (countff(9)  AND maskff(14)) OR 
                        (countff(8)  AND maskff(15)); 
  address32knode(6)  <= (countff(6)  AND maskff(1))  OR 
                        (countff(9)  AND maskff(2))  OR 
                        (countff(8)  AND maskff(3))  OR 
                        (countff(7)  AND maskff(4))  OR 
                        (countff(10) AND maskff(5))  OR
                        (countff(5)  AND maskff(6))  OR
                        (countff(12) AND maskff(7))  OR
                        (countff(3)  AND maskff(8))  OR
                        (countff(14) AND maskff(9))  OR
                        (countff(1)  AND maskff(10)) OR
                        (countff(15) AND maskff(11)) OR
                        (countff(2)  AND maskff(12)) OR
                        (countff(13) AND maskff(13)) OR 
                        (countff(4)  AND maskff(14)) OR 
                        (countff(11) AND maskff(15));
  address32knode(5)  <= (countff(5)  AND maskff(1))  OR 
                        (countff(12) AND maskff(2))  OR 
                        (countff(3)  AND maskff(3))  OR 
                        (countff(14) AND maskff(4))  OR 
                        (countff(1)  AND maskff(5))  OR
                        (countff(15) AND maskff(6))  OR
                        (countff(2)  AND maskff(7))  OR
                        (countff(13) AND maskff(8))  OR
                        (countff(4)  AND maskff(9))  OR 
                        (countff(11) AND maskff(10)) OR 
                        (countff(6)  AND maskff(11)) OR
                        (countff(9)  AND maskff(12)) OR
                        (countff(8)  AND maskff(13)) OR
                        (countff(7)  AND maskff(14)) OR
                        (countff(10) AND maskff(15)); 
  address32knode(4)  <= (countff(4)  AND maskff(1))  OR 
                        (countff(11) AND maskff(2))  OR 
                        (countff(6)  AND maskff(3))  OR 
                        (countff(9)  AND maskff(4))  OR 
                        (countff(8)  AND maskff(5))  OR
                        (countff(7)  AND maskff(6))  OR
                        (countff(10) AND maskff(7))  OR
                        (countff(5)  AND maskff(8))  OR
                        (countff(12) AND maskff(9))  OR 
                        (countff(3)  AND maskff(10)) OR 
                        (countff(14) AND maskff(11)) OR
                        (countff(1)  AND maskff(12)) OR
                        (countff(15) AND maskff(13)) OR
                        (countff(2)  AND maskff(14)) OR
                        (countff(13) AND maskff(15)); 
  address32knode(3)  <= (countff(3)  AND maskff(1))  OR 
                        (countff(14) AND maskff(2))  OR 
                        (countff(1)  AND maskff(3))  OR 
                        (countff(15) AND maskff(4))  OR 
                        (countff(2)  AND maskff(5))  OR
                        (countff(13) AND maskff(6))  OR
                        (countff(4)  AND maskff(7))  OR
                        (countff(11) AND maskff(8))  OR
                        (countff(6)  AND maskff(9))  OR
                        (countff(9)  AND maskff(10)) OR
                        (countff(8)  AND maskff(11)) OR
                        (countff(7)  AND maskff(12)) OR
                        (countff(10) AND maskff(13)) OR 
                        (countff(5)  AND maskff(14)) OR 
                        (countff(12) AND maskff(15));
  address32knode(2)  <= (countff(2)  AND maskff(1))  OR 
                        (countff(13) AND maskff(2))  OR 
                        (countff(4)  AND maskff(3))  OR 
                        (countff(11) AND maskff(4))  OR 
                        (countff(6)  AND maskff(5))  OR
                        (countff(9)  AND maskff(6))  OR
                        (countff(8)  AND maskff(7))  OR
                        (countff(7)  AND maskff(8))  OR
                        (countff(10) AND maskff(9))  OR  
                        (countff(5)  AND maskff(10)) OR  
                        (countff(12) AND maskff(11)) OR   
                        (countff(3)  AND maskff(12)) OR   
                        (countff(14) AND maskff(13)) OR 
                        (countff(1)  AND maskff(14)) OR 
                        (countff(15) AND maskff(15));
  address32knode(1)  <= (countff(1)  AND maskff(1))  OR 
                        (countff(15) AND maskff(2))  OR 
                        (countff(2)  AND maskff(3))  OR 
                        (countff(13) AND maskff(4))  OR 
                        (countff(4)  AND maskff(5))  OR
                        (countff(11) AND maskff(6))  OR
                        (countff(6)  AND maskff(7))  OR
                        (countff(9)  AND maskff(8))  OR
                        (countff(8)  AND maskff(9))  OR
                        (countff(7)  AND maskff(10)) OR
                        (countff(10) AND maskff(11)) OR
                        (countff(5)  AND maskff(12)) OR
                        (countff(12) AND maskff(13)) OR
                        (countff(3)  AND maskff(14)) OR
                        (countff(14) AND maskff(15));
  
  modulo32k <= countff(15) AND countff(14) AND countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);


  --length=131072
  --[17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1]
  --[ 2  1  4  3  6  5  8  7 10  9 12 11 14 13 16 15 17]
  --[15 17 13 16 11 14  9 12  7 10  5  8  3  6  1  4  2]
  --[ 4  2  6  1  8  3 10  5 12  7 14  9 16 11 17 13 15]
  --[13 15 11 17  9 16  7 14  5 12  3 10  1  8  2  6  4]
  --[ 6  4  8  2 10  1 12  3 14  5 16  7 17  9 15 11 13]
  --[11 13  9 15  7 17  5 16  3 14  1 12  2 10  4  8  6]
  --[ 8  6 10  4 12  2 14  1 16  3 17  5 15  7 13  9 11]
  --[ 9 11  7 13  5 15  3 17  1 16  2 14  4 12  6 10  8]
  --[10  8 12  6 14  4 16  2 17  1 15  3 13  5 11  7  9]
  --[ 7  9  5 11  3 13  1 15  2 17  4 16  6 14  8 12 10]
  --[12 10 14  8 16  6 17  4 15  2 13  1 11  3  9  5  7]
  --[ 5  7  3  9  1 11  2 13  4 15  6 17  8 16 10 14 12]
  --[14 12 16 10 17  8 15  6 13  4 11  2  9  1  7  3  5]
  --[ 3  5  1  7  2  9  4 11  6 13  8 15 10 17 12 16 14]
  --[16 14 17 12 15 10 13  8 11  6  9  4  7  2  5  1  3]
  --[ 1  3  2  5  4  7  6  9  8 11 10 13 12 15 14 17 16]
  --[17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1] (start again)
 
  address128knode(18) <= '0'; 
  address128knode(17) <= (countff(17) AND maskff(1))  OR 
                         (countff(2)  AND maskff(2))  OR 
                         (countff(15) AND maskff(3))  OR 
                         (countff(4)  AND maskff(4))  OR 
                         (countff(13) AND maskff(5))  OR
                         (countff(6)  AND maskff(6))  OR
                         (countff(11) AND maskff(7))  OR
                         (countff(8)  AND maskff(8))  OR
                         (countff(9)  AND maskff(9))  OR
                         (countff(10) AND maskff(10)) OR
                         (countff(7)  AND maskff(11)) OR
                         (countff(12) AND maskff(12)) OR
                         (countff(5)  AND maskff(13)) OR 
                         (countff(14) AND maskff(14)) OR 
                         (countff(3)  AND maskff(15)) OR
                         (countff(16) AND maskff(16)) OR
                         (countff(1)  AND maskff(17)); 
  address128knode(16) <= (countff(16) AND maskff(1))  OR 
                         (countff(1)  AND maskff(2))  OR 
                         (countff(17) AND maskff(3))  OR 
                         (countff(2)  AND maskff(4))  OR 
                         (countff(15) AND maskff(5))  OR
                         (countff(4)  AND maskff(6))  OR
                         (countff(13) AND maskff(7))  OR
                         (countff(6)  AND maskff(8))  OR
                         (countff(11) AND maskff(9))  OR
                         (countff(8)  AND maskff(10)) OR
                         (countff(9)  AND maskff(11)) OR
                         (countff(10) AND maskff(12)) OR
                         (countff(7)  AND maskff(13)) OR 
                         (countff(12) AND maskff(14)) OR 
                         (countff(5)  AND maskff(15)) OR
                         (countff(14) AND maskff(16)) OR
                         (countff(3)  AND maskff(17));
  address128knode(15) <= (countff(15) AND maskff(1))  OR 
                         (countff(4)  AND maskff(2))  OR 
                         (countff(13) AND maskff(3))  OR 
                         (countff(6)  AND maskff(4))  OR 
                         (countff(11) AND maskff(5))  OR
                         (countff(8)  AND maskff(6))  OR
                         (countff(9 ) AND maskff(7))  OR
                         (countff(10) AND maskff(8))  OR
                         (countff(7)  AND maskff(9))  OR
                         (countff(12) AND maskff(10)) OR
                         (countff(5)  AND maskff(11)) OR
                         (countff(14) AND maskff(12)) OR
                         (countff(3)  AND maskff(13)) OR 
                         (countff(16) AND maskff(14)) OR 
                         (countff(1)  AND maskff(15)) OR
                         (countff(17) AND maskff(16)) OR
                         (countff(2)  AND maskff(17)); 
  address128knode(14) <= (countff(14) AND maskff(1))  OR 
                         (countff(3)  AND maskff(2))  OR 
                         (countff(16) AND maskff(3))  OR 
                         (countff(1)  AND maskff(4))  OR 
                         (countff(17) AND maskff(5))  OR
                         (countff(2)  AND maskff(6))  OR
                         (countff(15) AND maskff(7))  OR
                         (countff(4)  AND maskff(8))  OR
                         (countff(13) AND maskff(9))  OR
                         (countff(6)  AND maskff(10)) OR
                         (countff(11) AND maskff(11)) OR
                         (countff(8)  AND maskff(12)) OR
                         (countff(9)  AND maskff(13)) OR 
                         (countff(10) AND maskff(14)) OR 
                         (countff(7)  AND maskff(15)) OR
                         (countff(12) AND maskff(16)) OR 
                         (countff(5)  AND maskff(17)); 
  address128knode(13) <= (countff(13) AND maskff(1))  OR 
                         (countff(6)  AND maskff(2))  OR 
                         (countff(11) AND maskff(3))  OR 
                         (countff(8)  AND maskff(4))  OR 
                         (countff(9)  AND maskff(5))  OR
                         (countff(10) AND maskff(6))  OR
                         (countff(7)  AND maskff(7))  OR
                         (countff(12) AND maskff(8))  OR
                         (countff(5)  AND maskff(9))  OR
                         (countff(14) AND maskff(10)) OR
                         (countff(3)  AND maskff(11)) OR
                         (countff(16) AND maskff(12)) OR
                         (countff(1)  AND maskff(13)) OR 
                         (countff(17) AND maskff(14)) OR 
                         (countff(2)  AND maskff(15)) OR 
                         (countff(15) AND maskff(16)) OR 
                         (countff(4)  AND maskff(17));
  address128knode(12) <= (countff(12) AND maskff(1))  OR 
                         (countff(5)  AND maskff(2))  OR 
                         (countff(14) AND maskff(3))  OR 
                         (countff(3)  AND maskff(4))  OR 
                         (countff(16) AND maskff(5))  OR
                         (countff(1)  AND maskff(6))  OR
                         (countff(17) AND maskff(7))  OR
                         (countff(2)  AND maskff(8))  OR
                         (countff(15) AND maskff(9))  OR
                         (countff(4)  AND maskff(10)) OR
                         (countff(13) AND maskff(11)) OR
                         (countff(6)  AND maskff(12)) OR
                         (countff(11) AND maskff(13)) OR 
                         (countff(8)  AND maskff(14)) OR 
                         (countff(9)  AND maskff(15)) OR 
                         (countff(10) AND maskff(16)) OR 
                         (countff(7)  AND maskff(17)); 
  address128knode(11) <= (countff(11) AND maskff(1))  OR 
                         (countff(8)  AND maskff(2))  OR 
                         (countff(9)  AND maskff(3))  OR 
                         (countff(10) AND maskff(4))  OR 
                         (countff(7)  AND maskff(5))  OR
                         (countff(12) AND maskff(6))  OR
                         (countff(5)  AND maskff(7))  OR
                         (countff(14) AND maskff(8))  OR
                         (countff(3)  AND maskff(9))  OR
                         (countff(16) AND maskff(10)) OR
                         (countff(1)  AND maskff(11)) OR
                         (countff(17) AND maskff(12)) OR
                         (countff(2)  AND maskff(13)) OR 
                         (countff(15) AND maskff(14)) OR 
                         (countff(4)  AND maskff(15)) OR 
                         (countff(13) AND maskff(16)) OR 
                         (countff(6)  AND maskff(17)); 
  address128knode(10) <= (countff(10) AND maskff(1))  OR 
                         (countff(7)  AND maskff(2))  OR 
                         (countff(12) AND maskff(3))  OR 
                         (countff(5)  AND maskff(4))  OR 
                         (countff(14) AND maskff(5))  OR
                         (countff(3)  AND maskff(6))  OR
                         (countff(16) AND maskff(7))  OR
                         (countff(1)  AND maskff(8))  OR
                         (countff(17) AND maskff(9))  OR
                         (countff(2)  AND maskff(10)) OR
                         (countff(15) AND maskff(11)) OR
                         (countff(4)  AND maskff(12)) OR
                         (countff(13) AND maskff(13)) OR 
                         (countff(6)  AND maskff(14)) OR 
                         (countff(11) AND maskff(15)) OR 
                         (countff(8)  AND maskff(16)) OR 
                         (countff(9)  AND maskff(17)); 
  address128knode(9)  <= (countff(9)  AND maskff(1))  OR 
                         (countff(10) AND maskff(2))  OR 
                         (countff(7)  AND maskff(3))  OR 
                         (countff(12) AND maskff(4))  OR 
                         (countff(5)  AND maskff(5))  OR
                         (countff(14) AND maskff(6))  OR
                         (countff(3)  AND maskff(7))  OR
                         (countff(16) AND maskff(8))  OR
                         (countff(1)  AND maskff(9))  OR
                         (countff(17) AND maskff(10)) OR
                         (countff(2)  AND maskff(11)) OR
                         (countff(15) AND maskff(12)) OR
                         (countff(4)  AND maskff(13)) OR 
                         (countff(13) AND maskff(14)) OR 
                         (countff(6)  AND maskff(15)) OR 
                         (countff(11) AND maskff(16)) OR 
                         (countff(8)  AND maskff(17));
  address128knode(8)  <= (countff(8)  AND maskff(1))  OR 
                         (countff(9)  AND maskff(2))  OR 
                         (countff(10) AND maskff(3))  OR 
                         (countff(7)  AND maskff(4))  OR 
                         (countff(12) AND maskff(5))  OR
                         (countff(5)  AND maskff(6))  OR
                         (countff(14) AND maskff(7))  OR
                         (countff(3)  AND maskff(8))  OR
                         (countff(16) AND maskff(9))  OR
                         (countff(1)  AND maskff(10)) OR
                         (countff(17) AND maskff(11)) OR
                         (countff(2)  AND maskff(12)) OR
                         (countff(15) AND maskff(13)) OR 
                         (countff(4)  AND maskff(14)) OR 
                         (countff(13) AND maskff(15)) OR 
                         (countff(6)  AND maskff(16)) OR 
                         (countff(11) AND maskff(17)); 
  address128knode(7)  <= (countff(7)  AND maskff(1))  OR 
                         (countff(12) AND maskff(2))  OR 
                         (countff(5)  AND maskff(3))  OR 
                         (countff(14) AND maskff(4))  OR 
                         (countff(3)  AND maskff(5))  OR
                         (countff(16) AND maskff(6))  OR
                         (countff(1)  AND maskff(7))  OR
                         (countff(17) AND maskff(8))  OR
                         (countff(2)  AND maskff(9))  OR
                         (countff(15) AND maskff(10)) OR
                         (countff(4)  AND maskff(11)) OR
                         (countff(13) AND maskff(12)) OR
                         (countff(6)  AND maskff(13)) OR 
                         (countff(11) AND maskff(14)) OR 
                         (countff(8)  AND maskff(15)) OR 
                         (countff(9)  AND maskff(16)) OR 
                         (countff(10) AND maskff(17)); 
  address128knode(6)  <= (countff(6)  AND maskff(1))  OR 
                         (countff(11) AND maskff(2))  OR 
                         (countff(8)  AND maskff(3))  OR 
                         (countff(9)  AND maskff(4))  OR 
                         (countff(10) AND maskff(5))  OR
                         (countff(7)  AND maskff(6))  OR
                         (countff(12) AND maskff(7))  OR
                         (countff(5)  AND maskff(8))  OR
                         (countff(14) AND maskff(9))  OR
                         (countff(3)  AND maskff(10)) OR
                         (countff(16) AND maskff(11)) OR
                         (countff(1)  AND maskff(12)) OR
                         (countff(17) AND maskff(13)) OR 
                         (countff(2)  AND maskff(14)) OR 
                         (countff(15) AND maskff(15)) OR
                         (countff(4)  AND maskff(16)) OR
                         (countff(13) AND maskff(17)); 
  address128knode(5)  <= (countff(5)  AND maskff(1))  OR 
                         (countff(14) AND maskff(2))  OR 
                         (countff(3)  AND maskff(3))  OR 
                         (countff(16) AND maskff(4))  OR 
                         (countff(1)  AND maskff(5))  OR
                         (countff(17) AND maskff(6))  OR
                         (countff(2)  AND maskff(7))  OR
                         (countff(15) AND maskff(8))  OR
                         (countff(4)  AND maskff(9))  OR 
                         (countff(13) AND maskff(10)) OR 
                         (countff(6)  AND maskff(11)) OR
                         (countff(11) AND maskff(12)) OR
                         (countff(8)  AND maskff(13)) OR
                         (countff(9)  AND maskff(14)) OR
                         (countff(10) AND maskff(15)) OR 
                         (countff(7)  AND maskff(16)) OR 
                         (countff(12) AND maskff(17)); 
  address128knode(4)  <= (countff(4)  AND maskff(1))  OR 
                         (countff(13) AND maskff(2))  OR 
                         (countff(6)  AND maskff(3))  OR 
                         (countff(11) AND maskff(4))  OR 
                         (countff(8)  AND maskff(5))  OR
                         (countff(9)  AND maskff(6))  OR
                         (countff(10) AND maskff(7))  OR
                         (countff(7)  AND maskff(8))  OR
                         (countff(12) AND maskff(9))  OR 
                         (countff(5)  AND maskff(10)) OR 
                         (countff(14) AND maskff(11)) OR
                         (countff(3)  AND maskff(12)) OR
                         (countff(16) AND maskff(13)) OR
                         (countff(1)  AND maskff(14)) OR
                         (countff(17) AND maskff(15)) OR 
                         (countff(2)  AND maskff(16)) OR 
                         (countff(15) AND maskff(17)); 
  address128knode(3)  <= (countff(3)  AND maskff(1))  OR 
                         (countff(16) AND maskff(2))  OR 
                         (countff(1)  AND maskff(3))  OR 
                         (countff(17) AND maskff(4))  OR 
                         (countff(2)  AND maskff(5))  OR
                         (countff(15) AND maskff(6))  OR
                         (countff(4)  AND maskff(7))  OR
                         (countff(13) AND maskff(8))  OR
                         (countff(6)  AND maskff(9))  OR
                         (countff(11) AND maskff(10)) OR
                         (countff(8)  AND maskff(11)) OR
                         (countff(9)  AND maskff(12)) OR
                         (countff(10) AND maskff(13)) OR 
                         (countff(7)  AND maskff(14)) OR 
                         (countff(12) AND maskff(15)) OR
                         (countff(5)  AND maskff(16)) OR
                         (countff(14) AND maskff(17));
  address128knode(2)  <= (countff(2)  AND maskff(1))  OR 
                         (countff(15) AND maskff(2))  OR 
                         (countff(4)  AND maskff(3))  OR 
                         (countff(13) AND maskff(4))  OR 
                         (countff(6)  AND maskff(5))  OR
                         (countff(11) AND maskff(6))  OR
                         (countff(8)  AND maskff(7))  OR
                         (countff(9)  AND maskff(8))  OR
                         (countff(10) AND maskff(9))  OR  
                         (countff(7)  AND maskff(10)) OR  
                         (countff(12) AND maskff(11)) OR   
                         (countff(5)  AND maskff(12)) OR   
                         (countff(14) AND maskff(13)) OR 
                         (countff(3)  AND maskff(14)) OR 
                         (countff(16) AND maskff(15)) OR
                         (countff(1)  AND maskff(16)) OR
                         (countff(17) AND maskff(17));
  address128knode(1)  <= (countff(1)  AND maskff(1))  OR 
                         (countff(17) AND maskff(2))  OR 
                         (countff(2)  AND maskff(3))  OR 
                         (countff(15) AND maskff(4))  OR 
                         (countff(4)  AND maskff(5))  OR
                         (countff(13) AND maskff(6))  OR
                         (countff(6)  AND maskff(7))  OR
                         (countff(11) AND maskff(8))  OR
                         (countff(8)  AND maskff(9))  OR
                         (countff(9)  AND maskff(10)) OR
                         (countff(10) AND maskff(11)) OR
                         (countff(7)  AND maskff(12)) OR
                         (countff(12) AND maskff(13)) OR
                         (countff(5)  AND maskff(14)) OR
                         (countff(14) AND maskff(15)) OR
                         (countff(3)  AND maskff(16)) OR
                         (countff(16) AND maskff(17));
  
  modulo128k <= countff(17) AND countff(16) AND countff(15) AND countff(14) AND countff(13) AND countff(12) AND countff(11) AND countff(10) AND countff(9) AND countff(8) AND countff(7) AND countff(6) AND countff(5) AND countff(4) AND countff(3) AND countff(2) AND countff(1);



  length_ext <= conv_std_logic_vector (0,18-pointswidth) & length;

  modulo   <= (length_ext(4)  AND modulo8)    OR
              (length_ext(5)  AND modulo16)   OR
              (length_ext(6)  AND modulo32)   OR
              (length_ext(7)  AND modulo64)   OR
              (length_ext(8)  AND modulo128)  OR
              (length_ext(9)  AND modulo256)  OR
              (length_ext(10) AND modulo512)  OR
              (length_ext(11) AND modulo1k)   OR
              (length_ext(12) AND modulo2k)   OR
              (length_ext(13) AND modulo4k)   OR
              (length_ext(14) AND modulo8k)   OR
              (length_ext(15) AND modulo16k)  OR
              (length_ext(16) AND modulo32k)  OR
              (length_ext(17) AND modulo64k)  OR
              (length_ext(18) AND modulo128k) OR
              (length_ext(19) AND modulo256k);
  
  addressnode <= address8node    when length_ext(4)='1'  else
                 address16node   when length_ext(5)='1'  else
                 address32node   when length_ext(6)='1'  else
                 address64node   when length_ext(7)='1'  else
                 address128node  when length_ext(8)='1'  else
                 address256node  when length_ext(9)='1'  else
                 address512node  when length_ext(10)='1' else
                 address1knode   when length_ext(11)='1' else
                 address2knode   when length_ext(12)='1' else
                 address4knode   when length_ext(13)='1' else
                 address8knode   when length_ext(14)='1' else
                 address16knode  when length_ext(15)='1' else
                 address32knode  when length_ext(16)='1' else
                 address64knode  when length_ext(17)='1' else
                 address128knode when length_ext(18)='1' else
                 address256knode when length_ext(19)='1' else
                 conv_std_logic_vector (0,18);
  
  mask_rst <= modulo AND (
              (length_ext(4)  AND maskff(3))  OR
              (length_ext(6)  AND maskff(5))  OR
              (length_ext(8)  AND maskff(7))  OR
              (length_ext(10) AND maskff(9))  OR
              (length_ext(12) AND maskff(11)) OR
              (length_ext(14) AND maskff(13)) OR
              (length_ext(16) AND maskff(15)) OR
              (length_ext(18) AND maskff(17)) OR
              ((length_ext(5) OR length_ext(7) OR length_ext(9) OR length_ext(11) OR length_ext(13) OR length_ext(15) OR length_ext(17) OR length_ext(19)) AND maskff(2))
              );

  address  <= addressnode(pointswidth DOWNTO 1);
  validout <= validoutff(4);
  
END rtl;

