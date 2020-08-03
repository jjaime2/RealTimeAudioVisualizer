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
use std.textio.all;
use ieee.std_logic_textio.all; 

library work;
use work.auk_dspip_math_pkg.all;
USE work.auk_fft_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   apn_fftfpbdr_firststage                   ***
--***                                             ***
--***   Function: first R4/R2 stage for streaming ***
--***   FFT                                       ***
--***                                             ***
--***   20/01/10 ML                               ***
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

ENTITY apn_fftfpbdr_firststage IS
GENERIC (
         device_family: string;
         addwidth     : positive := 4;
         stage        : positive := 1;
         twidwidth    : positive := 4;
         points       : positive := 256;
         accuracy     : natural := 1;
         dsp          : natural := 0;
         realfile     : string := "twrfp1.hex";
         imagfile     : string := "twifp1.hex";
         twidfile     : string := "twqfp1.hex"
        );
PORT (
      sysclk        : IN  STD_LOGIC;
      reset         : IN  STD_LOGIC;
      enable        : IN  STD_LOGIC;
      startin       : IN  STD_LOGIC;
      mlenfor       : IN  STD_LOGIC_VECTOR (log2_ceil(points)+1 DOWNTO 1);
      mlentwo       : IN  STD_LOGIC_VECTOR (log2_ceil(points)+1 DOWNTO 1);
      radix         : IN  STD_LOGIC;
      stg_sel       : IN  STD_LOGIC;
      invin         : IN  STD_LOGIC;
      realin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      invout        : OUT STD_LOGIC;
      realout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout      : OUT STD_LOGIC
     );
END apn_fftfpbdr_firststage;

ARCHITECTURE rtl OF apn_fftfpbdr_firststage IS
  constant internal_data_width : integer := get_internal_data_width(dsp, device_family);
  constant FFT_LATENCY : integer := get_fft_latency(dsp, device_family);
  type delayfftype IS ARRAY (6 DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  type muxfftype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (internal_data_width DOWNTO 1);
  type expmuxtype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (8 DOWNTO 1);
  type manmuxtype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (23 DOWNTO 1);
  type mannodetype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);

  type indextype IS ARRAY ((((log2_ceil(points))-(2*stage))/2) DOWNTO 1) OF STD_LOGIC_VECTOR (twidwidth DOWNTO 1);
  type doutnodetype IS ARRAY (8 DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  type soutnodetype IS ARRAY (8 DOWNTO 1) OF STD_LOGIC;
  signal startff    : STD_LOGIC_VECTOR (19 DOWNTO 1);

  signal start_counttwid  : STD_LOGIC;
  signal counttwidff      : STD_LOGIC_VECTOR ((log2_ceil(points))+1 DOWNTO 1);
  signal bf_num           : STD_LOGIC_VECTOR ((log2_ceil(points))-(2*stage) DOWNTO 1);
  
  constant mul_fact       : STD_LOGIC_VECTOR ((2*stage) DOWNTO 1) := (OTHERS => '0');
  signal fwdadd           : STD_LOGIC_VECTOR ((log2_ceil(points)) DOWNTO 1);
  signal rvsadd           : STD_LOGIC_VECTOR ((log2_ceil(points)) DOWNTO 1);
  
  signal addtwaddind      : STD_LOGIC;
  signal addzer, addone, addtwo, addthr : STD_LOGIC;
  signal twaddind         : STD_LOGIC_VECTOR (twidwidth DOWNTO 1);

  signal countff          : STD_LOGIC_VECTOR (addwidth DOWNTO 1);

  signal realinff, imaginff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realff, imagff : delayfftype;
  signal realmuxff, imagmuxff : muxfftype;
  signal selone, seltwo, selthr, selfor : STD_LOGIC; 
  signal seloneff, seltwoff, selthrff, selforff : STD_LOGIC; 
  signal realoutnode, imagoutnode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realoutnode_f, imagoutnode_f : doutnodetype;
  signal realoutnode_fs, imagoutnode_fs : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realoutnode_r, imagoutnode_r : STD_LOGIC_VECTOR (32 DOWNTO 1);
    
  signal realsignmux, imagsignmux : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal realexpmux, imagexpmux : expmuxtype;
  signal realmanmux, imagmanmux : manmuxtype;
  signal real_twiddle, imag_twiddle : STD_LOGIC_VECTOR (internal_data_width DOWNTO 1);
  signal startoutnode, startoutnode_fs, startoutnode_r : STD_LOGIC;
  signal startoutnode_f : soutnodetype;
  signal invoutff : STD_LOGIC_VECTOR (7+FFT_LATENCY DOWNTO 1);
  signal realmux, imagmux : mannodetype;
  component apn_fftfprvs_fft4
  GENERIC (
           device_family : string;
           accuracy : natural := 1;
           dsp : natural := 0
          );
  PORT (
        sysclk  : IN STD_LOGIC;
        reset   : IN STD_LOGIC;
        enable  : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        realina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imagina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realinb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imaginb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realinc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imaginc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imagind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        real_twiddle : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imag_twiddle : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      
        startout : OUT STD_LOGIC;
        realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
       );
   end component;
  component apn_fftfp_fft4_hdfp
  PORT (
        sysclk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        realina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        real_twiddle : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imag_twiddle : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
        startout : OUT STD_LOGIC;
        realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
      );
  end component;
  
  component apn_fftfprvs_twiddle_opt
  GENERIC (
           device_family : string;
           data_width : positive := 40;
           addwidth : positive := 6;
           twidfile : string := "twqfp1.hex"
          );
  PORT (
        sysclk : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        twiddle_address : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);       
      
        real_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1); 
        imag_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1)
       );
  end component;


  component apn_fftfp_dft4
  PORT (
        sysclk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        realina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imagina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realinb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imaginb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realinc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imaginc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        realind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
        imagind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);

        startout : OUT STD_LOGIC;
        realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
       );
   end component;
  component apn_fftfp_dft4_hdfp
  PORT (
        sysclk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        realina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);

        startout : OUT STD_LOGIC;
        realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
       );
   end component;   
BEGIN

  inverse_ctrl : process (sysclk, reset)
  begin
    if reset = '1' then
      FOR k IN 1 TO 7+FFT_LATENCY LOOP    -- 25 = 7(pipeline in stage) + FFT_LATENCY(pipeline if fft) / 10(pipeline in dft)
        invoutff(k) <= '0';
      END LOOP;
    elsif rising_edge(sysclk) then
      if enable = '1' then
        if (stg_sel = '1') then
          invoutff(1) <= invin;
          FOR k IN 2 TO 7+FFT_LATENCY LOOP
            invoutff(k) <= invoutff(k-1);
          END LOOP;
        else
          invoutff(1) <= '0';
          FOR k IN 2 TO 7+FFT_LATENCY LOOP
            invoutff(k) <= invoutff(k-1);
          END LOOP;
        end if;
      end if;  
    end if;
  end process inverse_ctrl;


  ------------------------------------------------------------------------------  
  ------------------------------------------------------------------------------  
  -- counttwidff: count from 0 to N-1
  ctp: PROCESS (sysclk, reset)
  BEGIN
    IF (reset = '1') THEN
      FOR k IN 1 TO (log2_ceil(points)+1) LOOP
        counttwidff(k) <= '0';
      END LOOP;
    ELSIF (rising_edge(sysclk)) THEN
      IF (enable = '1') THEN
        IF (start_counttwid = '1') THEN
          IF (radix = '0') THEN
            IF (counttwidff = mlenfor) THEN
              FOR k IN 1 TO (log2_ceil(points)) LOOP
                counttwidff(k) <= '0';
              END LOOP;
            ELSE
              counttwidff <= counttwidff + 1;
            END IF;
          ELSE
            IF (counttwidff = mlentwo) THEN
              FOR k IN 1 TO (log2_ceil(points)) LOOP
                counttwidff(k) <= '0';
              END LOOP;
            ELSE
              counttwidff <= counttwidff + 2;
            END IF;
          END IF;
        ELSE
          FOR k IN 1 TO (log2_ceil(points)) LOOP
            counttwidff(k) <= '0';
          END LOOP;
        END IF;        
      END IF;
    END IF;
  END PROCESS;
  
  -- bf_num: indicates the current number of butterflys
  bf_num <= counttwidff((log2_ceil(points)) DOWNTO (2*stage+1));
  
  -- fwdadd: bf_num * (4*stage)
  fwdadd <= bf_num & mul_fact;
  
  -- generate the reverse address
  gra: FOR k in 1 TO (log2_ceil(points))/2 GENERATE
    rvsadd(log2_ceil(points) - (2*(k-1))    ) <= fwdadd(2*k);
    rvsadd(log2_ceil(points) - (2*(k-1)) - 1) <= fwdadd((2*k)-1);
  END GENERATE;

  addzer <= NOT(counttwidff(addwidth))   AND   NOT(counttwidff(addwidth-1))   ;
  addone <= NOT(counttwidff(addwidth))   AND      (counttwidff(addwidth-1))   ;
  addtwo <=    (counttwidff(addwidth))   AND   NOT(counttwidff(addwidth-1))   ;
  addthr <=    (counttwidff(addwidth))   AND      (counttwidff(addwidth-1))   ;

  addtwaddind <= addone OR addtwo OR addthr;

  ctai: PROCESS (sysclk, reset)
  BEGIN
    IF (reset = '1') THEN
      FOR k IN 1 TO twidwidth LOOP
        twaddind(k) <= '0';
      END LOOP;
    ELSIF (rising_edge(sysclk)) THEN
      IF (enable = '1') THEN
        IF (addzer = '1') THEN
          twaddind <= (OTHERS => '0');
        ELSIF (addtwaddind = '1') THEN
          IF (radix = '1') THEN
            twaddind <= twaddind + (rvsadd(log2_ceil(points)-1 DOWNTO 1) & '0');
          ELSE
            twaddind <= twaddind + rvsadd;
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS;
  
  pda: PROCESS (reset, sysclk) 
  BEGIN
  
    IF (reset = '1') THEN
        
      FOR k IN 1 TO 19 LOOP
        startff(k) <= '0';
      END LOOP;
      FOR k IN 1 TO addwidth LOOP
        countff(k) <= '0';
      END LOOP;
      seloneff <= '0';
      seltwoff <= '0';
      selthrff <= '0';
      selforff <= '0';


    ELSIF (rising_edge(sysclk)) THEN

      IF (enable = '1') THEN

        IF (stg_sel = '1') then
          startff(1) <= startin;
        ELSE
          startff(1) <= '0';
        END IF;
        FOR k IN 2 TO 19 LOOP
          startff(k) <= startff(k-1);
        END LOOP;

        IF (stg_sel = '1') THEN
          realinff(32 DOWNTO 1) <= realin;
          imaginff(32 DOWNTO 1) <= imagin;
        ELSE
          realinff(32 DOWNTO 1) <= (others => '0');
          imaginff(32 DOWNTO 1) <= (others => '0');
        END IF;
        realff(1)(32 DOWNTO 1) <= realinff(32 DOWNTO 1);
        imagff(1)(32 DOWNTO 1) <= imaginff(32 DOWNTO 1);
        FOR k IN 2 TO 6 LOOP
          realff(k)(32 DOWNTO 1) <= realff(k-1)(32 DOWNTO 1);
          imagff(k)(32 DOWNTO 1) <= imagff(k-1)(32 DOWNTO 1);
        END LOOP;

        IF (startff(3) = '1') THEN
          countff <= countff + 1;
        END IF;
        
        seloneff <= selone;
        seltwoff <= seltwo;
        selthrff <= selthr;
        selforff <= selfor;
        

      END IF;
      
    END IF;
      
  END PROCESS;
  
  -- {1,1,1,1)
  realsignmux(1) <= (realff(3)(32) AND seloneff) OR 
                    (realff(4)(32) AND seltwoff) OR
                    (realff(5)(32) AND selthrff) OR
                    (realff(6)(32) AND selforff);
  imagsignmux(1) <= (imagff(3)(32) AND seloneff) OR 
                    (imagff(4)(32) AND seltwoff) OR
                    (imagff(5)(32) AND selthrff) OR
                    (imagff(6)(32) AND selforff);
  gmxone: FOR k IN 1 TO 8 GENERATE
    realexpmux(1)(k) <= (realff(3)(k+23) AND seloneff) OR 
                        (realff(4)(k+23) AND seltwoff) OR
                        (realff(5)(k+23) AND selthrff) OR
                        (realff(6)(k+23) AND selforff);
    imagexpmux(1)(k) <= (imagff(3)(k+23) AND seloneff) OR 
                        (imagff(4)(k+23) AND seltwoff) OR
                        (imagff(5)(k+23) AND selthrff) OR
                        (imagff(6)(k+23) AND selforff);
  END GENERATE;
  gmmone: FOR k IN 1 TO 23 GENERATE
    realmanmux(1)(k) <= (realff(3)(k) AND seloneff) OR 
                        (realff(4)(k) AND seltwoff) OR
                        (realff(5)(k) AND selthrff) OR
                        (realff(6)(k) AND selforff);
    imagmanmux(1)(k) <= (imagff(3)(k) AND seloneff) OR 
                        (imagff(4)(k) AND seltwoff) OR
                        (imagff(5)(k) AND selthrff) OR
                        (imagff(6)(k) AND selforff);
  END GENERATE;
  
  
                         
  -- {1,-j,-1,j}
  realsignmux(2) <= (realff(2)(32)      AND seloneff) OR
                    (imagff(3)(32)      AND seltwoff AND NOT(radix)) OR
                    (NOT(realff(3)(32)) AND seltwoff AND     radix) OR
                    (NOT(realff(4)(32)) AND selthrff) OR
                    (NOT(imagff(5)(32)) AND selforff);
  imagsignmux(2) <= (imagff(2)(32)      AND seloneff) OR
                    (NOT(realff(3)(32)) AND seltwoff AND NOT(radix)) OR
                    (NOT(imagff(3)(32)) AND seltwoff AND     radix) OR
                    (NOT(imagff(4)(32)) AND selthrff) OR
                    (realff(5)(32)      AND selforff);
  gmxtwo: FOR k IN 1 TO 8 GENERATE
    realexpmux(2)(k) <= (realff(2)(k+23) AND seloneff) OR
                        (imagff(3)(k+23) AND seltwoff AND NOT(radix)) OR
                        (realff(3)(k+23) AND seltwoff AND     radix) OR
                        (realff(4)(k+23) AND selthrff) OR
                        (imagff(5)(k+23) AND selforff);
    imagexpmux(2)(k) <= (imagff(2)(k+23) AND seloneff) OR
                        (realff(3)(k+23) AND seltwoff AND NOT(radix)) OR
                        (imagff(3)(k+23) AND seltwoff AND     radix) OR
                        (imagff(4)(k+23) AND selthrff) OR
                        (realff(5)(k+23) AND selforff);
  END GENERATE;
  gmmtwo: FOR k IN 1 TO 23 GENERATE
    realmanmux(2)(k) <= (realff(2)(k) AND seloneff) OR
                        (imagff(3)(k) AND seltwoff AND NOT(radix)) OR
                        (realff(3)(k) AND seltwoff AND     radix) OR
                        (realff(4)(k) AND selthrff) OR
                        (imagff(5)(k) AND selforff);
    imagmanmux(2)(k) <= (imagff(2)(k) AND seloneff) OR
                        (realff(3)(k) AND seltwoff AND NOT(radix)) OR
                        (imagff(3)(k) AND seltwoff AND     radix) OR
                        (imagff(4)(k) AND selthrff) OR
                        (realff(5)(k) AND selforff);
  END GENERATE;

  
    
  --{1,-1,1,-1}
  realsignmux(3) <= ((realff(1)(32)      AND seloneff) OR
                     (NOT(realff(2)(32)) AND seltwoff) OR
                     (realff(3)(32)      AND selthrff) OR
                     (NOT(realff(4)(32)) AND selforff)) AND NOT(radix);
  imagsignmux(3) <= ((imagff(1)(32)      AND seloneff) OR
                     (NOT(imagff(2)(32)) AND seltwoff) OR
                     (imagff(3)(32)      AND selthrff) OR
                     (NOT(imagff(4)(32)) AND selforff)) AND NOT(radix);
  gmxthr: FOR k IN 1 TO 8 GENERATE
    realexpmux(3)(k) <= ((realff(1)(k+23) AND seloneff) OR
                         (realff(2)(k+23) AND seltwoff) OR
                         (realff(3)(k+23) AND selthrff) OR
                         (realff(4)(k+23) AND selforff)) AND NOT(radix);
    imagexpmux(3)(k) <= ((imagff(1)(k+23) AND seloneff) OR
                         (imagff(2)(k+23) AND seltwoff) OR
                         (imagff(3)(k+23) AND selthrff) OR
                         (imagff(4)(k+23) AND selforff)) AND NOT(radix);
  END GENERATE;
  gmmthr: FOR k IN 1 TO 23 GENERATE
    realmanmux(3)(k) <= ((realff(1)(k) AND seloneff) OR
                         (realff(2)(k) AND seltwoff) OR
                         (realff(3)(k) AND selthrff) OR
                         (realff(4)(k) AND selforff)) AND NOT(radix);
    imagmanmux(3)(k) <= ((imagff(1)(k) AND seloneff) OR
                         (imagff(2)(k) AND seltwoff) OR
                         (imagff(3)(k) AND selthrff) OR
                         (imagff(4)(k) AND selforff)) AND NOT(radix);
  END GENERATE;
  
  
                      
  -- {1,j,-1,-j}       
  realsignmux(4) <= ((realinff(32)       AND seloneff) OR
                     (NOT(imagff(1)(32)) AND seltwoff) OR
                     (NOT(realff(2)(32)) AND selthrff) OR
                     (imagff(3)(32)      AND selforff)) AND NOT(radix);
  imagsignmux(4) <= ((imaginff(32)       AND seloneff) OR
                     (realff(1)(32)      AND seltwoff) OR
                     (NOT(imagff(2)(32)) AND selthrff) OR
                     (NOT(realff(3)(32)) AND selforff)) AND NOT(radix);                      
  gmxfor: FOR k IN 1 TO 8 GENERATE                       
    realexpmux(4)(k) <= ((realinff(k+23)  AND seloneff) OR
                         (imagff(1)(k+23) AND seltwoff) OR
                         (realff(2)(k+23) AND selthrff) OR
                         (imagff(3)(k+23) AND selforff)) AND NOT(radix);
    imagexpmux(4)(k) <= ((imaginff(k+23)  AND seloneff) OR
                         (realff(1)(k+23) AND seltwoff) OR
                         (imagff(2)(k+23) AND selthrff) OR
                         (realff(3)(k+23) AND selforff)) AND NOT(radix);
  END GENERATE;
  gmmfor: FOR k IN 1 TO 23 GENERATE
    realmanmux(4)(k) <= ((realinff(k)  AND seloneff) OR
                         (imagff(1)(k) AND seltwoff) OR
                         (realff(2)(k) AND selthrff) OR
                         (imagff(3)(k) AND selforff)) AND NOT(radix);
    imagmanmux(4)(k) <= ((imaginff(k)  AND seloneff) OR
                         (realff(1)(k) AND seltwoff) OR
                         (imagff(2)(k) AND selthrff) OR
                         (realff(3)(k) AND selforff)) AND NOT(radix);
  END GENERATE;

  

  selone <= (NOT(countff(2)) AND NOT(countff(1)) AND NOT(radix)) OR
            (NOT(countff(1)) AND radix);
  seltwo <= (NOT(countff(2)) AND     countff(1)  AND NOT(radix)) OR
            (    countff(1)  AND radix);
  selthr <= (    countff(2)  AND NOT(countff(1)) AND NOT(radix));
  selfor <= (    countff(2)  AND     countff(1)  AND NOT(radix)); 
  

   
  
  ctwa: apn_fftfprvs_twiddle_opt
  GENERIC MAP (
               device_family=>device_family,
               addwidth=>twidwidth,
               twidfile=>twidfile,
               data_width=>internal_data_width)
  PORT MAP (
            sysclk=>sysclk,
            enable=>enable,
            twiddle_address=>twaddind,
            real_twiddle=>real_twiddle,
            imag_twiddle=>imag_twiddle);



  process (sysclk, reset)
  begin
    if reset = '1' then
      FOR k IN 1 TO 8 LOOP
        startoutnode_f(k) <= '0';
        realoutnode_f(k)  <= (others => '0');
        imagoutnode_f(k)  <= (others => '0');
      END LOOP;
    elsif rising_edge(sysclk) then
      if enable = '1' then
        startoutnode_f(1)              <= startoutnode_fs;
        realoutnode_f(1)(32 DOWNTO 1)  <= realoutnode_fs;
        imagoutnode_f(1)(32 DOWNTO 1)  <= imagoutnode_fs;
        FOR k IN 2 TO 8 LOOP
          startoutnode_f(k)              <= startoutnode_f(k-1);
          realoutnode_f(k)(32 DOWNTO 1)  <= realoutnode_f(k-1)(32 DOWNTO 1);
          imagoutnode_f(k)(32 DOWNTO 1)  <= imagoutnode_f(k-1)(32 DOWNTO 1);
        END LOOP;
      end if;
    end if;
  end process;  

  process (startoutnode_r, startoutnode_f, realoutnode_r, realoutnode_f, imagoutnode_r, imagoutnode_f, invoutff)
  begin
    if (invoutff(6+FFT_LATENCY) = '1') then
      startoutnode <= startoutnode_r;
      realoutnode  <= realoutnode_r;
      imagoutnode  <= imagoutnode_r;
    else
      startoutnode <= startoutnode_f(8);
      realoutnode  <= realoutnode_f(8);
      imagoutnode  <= imagoutnode_f(8);
    end if;
  end process;

  process (sysclk, reset)
  begin
    if reset = '1' then
      startout  <= '0';
      invout    <= '0';
      realout   <= (others => '0');
      imagout   <= (others => '0');
    elsif rising_edge(sysclk) then
      if enable = '1' then
        if stg_sel = '1' then
          startout  <= startoutnode;
	        invout    <= invoutff(6+FFT_LATENCY);
          realout   <= realoutnode;
          imagout   <= imagoutnode;
        else
          startout  <= startin;
          realout   <= realin;
          imagout   <= imagin;
	  invout    <= invin;
        end if;
      end if;
    end if;
  end process;
  
  


    custom_width_adaptor:  IF not(dsp = 3) GENERATE
  signal realsignmuxff, imagsignmuxff : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal realexpmuxff, imagexpmuxff : expmuxtype;
  signal realmanmuxff, imagmanmuxff : manmuxtype;
  signal realmanprenode, imagmanprenode : mannodetype;
  signal realmangennode, imagmangennode : mannodetype;
  signal realmannode, imagmannode : mannodetype;

  BEGIN

    start_counttwid <= startff(8);

  core_r: apn_fftfprvs_fft4
  GENERIC MAP (device_family=>device_family,
               accuracy=>accuracy,
               dsp=>dsp)
  PORT MAP (sysclk=>sysclk,
            reset=>reset,
            enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1)(40 DOWNTO 1),imagina=>imagmuxff(1)(40 DOWNTO 1),
            realinb=>realmuxff(2)(40 DOWNTO 1),imaginb=>imagmuxff(2)(40 DOWNTO 1),
            realinc=>realmuxff(3)(40 DOWNTO 1),imaginc=>imagmuxff(3)(40 DOWNTO 1),
            realind=>realmuxff(4)(40 DOWNTO 1),imagind=>imagmuxff(4)(40 DOWNTO 1),
            real_twiddle=>real_twiddle,
            imag_twiddle=>imag_twiddle,
            startout=>startoutnode_r,
            realout=>realoutnode_r,imagout=>imagoutnode_r);


    core_f: apn_fftfp_dft4
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1)(40 DOWNTO 1),imagina=>imagmuxff(1)(40 DOWNTO 1),
            realinb=>realmuxff(2)(40 DOWNTO 1),imaginb=>imagmuxff(2)(40 DOWNTO 1),
            realinc=>realmuxff(3)(40 DOWNTO 1),imaginc=>imagmuxff(3)(40 DOWNTO 1),
            realind=>realmuxff(4)(40 DOWNTO 1),imagind=>imagmuxff(4)(40 DOWNTO 1),
            
            startout=>startoutnode_fs,
            realout=>realoutnode_fs,imagout=>imagoutnode_fs);


  
    conv: FOR i IN 1 TO 4 GENERATE
      realmangennode(i)(32 DOWNTO 28) <= "00000";
      realmangennode(i)(27) <= or_reduce(realexpmuxff(i));
      realmangennode(i)(26 DOWNTO 4) <= realmanmuxff(i)(23 DOWNTO 1);
      realmangennode(i)(3 DOWNTO 1) <= "000";
      grma: FOR k IN 1 TO 32 GENERATE
        realmanprenode(i)(k) <= realmangennode(i)(k) XOR realsignmuxff(i);
      END GENERATE;
      realmannode(i)(32 DOWNTO 1) <= realmanprenode(i)(32 DOWNTO 1) + realsignmuxff(i);
      
      imagmangennode(i)(32 DOWNTO 28) <= "00000";
      imagmangennode(i)(27) <= or_reduce(imagexpmuxff(i));
      imagmangennode(i)(26 DOWNTO 4) <= imagmanmuxff(i)(23 DOWNTO 1);
      imagmangennode(i)(3 DOWNTO 1) <= "000";
      gima: FOR k IN 1 TO 32 GENERATE
        imagmanprenode(i)(k) <= imagmangennode(i)(k) XOR imagsignmuxff(i);
      END GENERATE;
      imagmannode(i)(32 DOWNTO 1) <= imagmanprenode(i)(32 DOWNTO 1) + imagsignmuxff(i);               
    END GENERATE;


    conv_proc: PROCESS (sysclk, reset) 
    BEGIN
    
      IF (reset = '1') THEN

        realsignmuxff <= (others=>'0');
        imagsignmuxff <= (others=>'0');
        realexpmuxff <= (others=>(others=>'0'));
        imagexpmuxff <= (others=>(others=>'0'));

        realmanmuxff <= (others=>(others=>'0'));
        imagmanmuxff <= (others=>(others=>'0'));

        realmuxff <= (others=>(others=>'0'));
        imagmuxff <= (others=>(others=>'0'));


    
      ELSIF (rising_edge(sysclk)) THEN

        IF (enable = '1') THEN
          FOR k IN 1 TO 4 LOOP
            realmux(k) <= realsignmux(k) & realexpmux(k) & realmanmux(k);
            imagmux(k) <= imagsignmux(k) & imagexpmux(k) & imagmanmux(k);
          END LOOP;
          realsignmuxff(4 DOWNTO 1) <= realsignmux(4 DOWNTO 1);
          imagsignmuxff(4 DOWNTO 1) <= imagsignmux(4 DOWNTO 1);
          FOR k IN 1 TO 4 LOOP
            realexpmuxff(k)(8 DOWNTO 1) <= realexpmux(k)(8 DOWNTO 1);
            imagexpmuxff(k)(8 DOWNTO 1) <= imagexpmux(k)(8 DOWNTO 1);
          END LOOP;
          FOR k IN 1 TO 4 LOOP
            realmanmuxff(k)(23 DOWNTO 1) <= realmanmux(k)(23 DOWNTO 1);
            imagmanmuxff(k)(23 DOWNTO 1) <= imagmanmux(k)(23 DOWNTO 1);
          END LOOP;
        
          FOR k IN 1 TO 4 LOOP
            realmuxff(k) <= realmannode(k) & realexpmuxff(k);
            imagmuxff(k) <= imagmannode(k) & imagexpmuxff(k);
          END LOOP;

        END IF;
        
      END IF;
        
    END PROCESS;
    


    END GENERATE;

single_width:  IF dsp = 3 GENERATE
  begin
    start_counttwid <= startff(6);


    core: apn_fftfp_fft4_hdfp
  PORT MAP (sysclk=>sysclk,
            reset=>reset,
            enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1),imagina=>imagmuxff(1),
            realinb=>realmuxff(2),imaginb=>imagmuxff(2),
            realinc=>realmuxff(3),imaginc=>imagmuxff(3),
            realind=>realmuxff(4),imagind=>imagmuxff(4),
            real_twiddle=>real_twiddle,
            imag_twiddle=>imag_twiddle,
            startout=>startoutnode_r,
            realout=>realoutnode_r,imagout=>imagoutnode_r);

  core_hd: apn_fftfp_dft4_hdfp
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1),imagina=>imagmuxff(1),
            realinb=>realmuxff(2),imaginb=>imagmuxff(2),
            realinc=>realmuxff(3),imaginc=>imagmuxff(3),
            realind=>realmuxff(4),imagind=>imagmuxff(4),
            
            startout=>startoutnode_fs,
            realout=>realoutnode_fs,imagout=>imagoutnode_fs);


    conv_proc: PROCESS (sysclk, reset) 
    BEGIN
    
      IF (reset = '1') THEN
      
            realmux <= (others=>(others=>'0'));
            imagmux <= (others=>(others=>'0'));
       
            realmuxff <= (others=>(others=>'0'));
            imagmuxff <= (others=>(others=>'0'));
    
      ELSIF (rising_edge(sysclk)) THEN

        IF (enable = '1') THEN

          FOR k IN 1 TO 4 LOOP
            realmux(k) <= realsignmux(k) & realexpmux(k) & realmanmux(k);
            imagmux(k) <= imagsignmux(k) & imagexpmux(k) & imagmanmux(k);
          END LOOP;

        
          FOR k IN 1 TO 4 LOOP
            realmuxff(k) <= realmux(k);
            imagmuxff(k) <= imagmux(k);
          END LOOP;

        END IF;
        
      END IF;
        
    END PROCESS;
    



  END GENERATE;




END rtl;

