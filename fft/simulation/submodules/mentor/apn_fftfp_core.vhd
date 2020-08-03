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

LIBRARY work;
USE work.auk_dspip_math_pkg.all;
USE work.auk_fft_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_CORE                            ***
--***                                             ***
--***   Function: Floating Point Streaming FFT    ***
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

ENTITY apn_fftfp_core IS
GENERIC (
         device_family : string;  
         num_stages : natural := 5;  
         input_format : string := "NATURAL_ORDER";
         points : positive := 256;
         accuracy : natural := 1;
         dsp : natural := 0;
         twidrom_base : string := "fftfp" 
        );
PORT (
      sysclk : IN STD_LOGIC;
      reset  : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      radix  : IN STD_LOGIC;
      startin: IN STD_LOGIC;
      length : IN STD_LOGIC_VECTOR (log2_ceil(points)+1 DOWNTO 1);
      inverse: IN STD_LOGIC;
      stg_input_sel  : IN STD_LOGIC_VECTOR (num_stages downto 1);
      realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
      realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout : OUT STD_LOGIC
     );
END apn_fftfp_core;

ARCHITECTURE rtl OF apn_fftfp_core IS
  constant internal_data_width : integer := get_internal_data_width(dsp, device_family);
  type stage_data_outtype IS ARRAY (num_stages DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  type stage_data_intype  IS ARRAY (num_stages DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  




  signal start_stage_in  : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal start_stage_out : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal inv_stage_in    : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal inv_stage_out   : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal realinv, imaginv: STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal real_stage_out, imag_stage_out : stage_data_outtype;
  signal real_stage_in,  imag_stage_in  : stage_data_intype;
  
  component apn_fftfp_stage
  GENERIC (
           device_family: string;
           input_format : string := "NATURAL_ORDER";
           addwidth     : positive := 4;
           delay        : positive := 4;
           accuracy     : natural := 1;
           dsp          : natural := 0;
           realfile     : string := "twrfp1.hex";
           imagfile     : string := "twifp1.hex";
           twidfile     : string := "twqfp1.hex"
          );
  PORT (
        sysclk  : IN STD_LOGIC;
        reset   : IN STD_LOGIC;
        enable  : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        radix   : IN STD_LOGIC;
        stg_sel : IN STD_LOGIC;
        realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
        realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        startout : OUT STD_LOGIC
       );
   end component;
 
   component apn_fftfp_laststage
   GENERIC (
           device_family: string;
           dsp          : natural := 0
  );
    PORT (
        sysclk  : IN STD_LOGIC;
        reset   : IN STD_LOGIC;
        enable  : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        radix   : IN STD_LOGIC;
        realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
        realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        startout : OUT STD_LOGIC
       );
  end component;

BEGIN
  
  realinv <= realin;
  imaginv <= imagin;
 
  start_stage_in(num_stages) <= startin AND stg_input_sel(1);
  gsa: FOR j IN 1 TO 32 GENERATE
    real_stage_in(num_stages)(j) <= realinv(j) AND stg_input_sel(1);
    imag_stage_in(num_stages)(j) <= imaginv(j) AND stg_input_sel(1); 
  END GENERATE gsa;

  stgc: FOR k IN num_stages-1 DOWNTO 1 GENERATE
    start_stage_in(k) <= (start_stage_out(k+1) AND NOT(stg_input_sel(num_stages+1-k))) OR
                         (startin AND stg_input_sel(num_stages+1-k));
    gsai: FOR j IN 1 TO 32 GENERATE
      real_stage_in(k)(j) <= (real_stage_out(k+1)(j) AND NOT(stg_input_sel(num_stages+1-k))) OR
                             (realinv(j) AND stg_input_sel(num_stages+1-k));
      imag_stage_in(k)(j) <= (imag_stage_out(k+1)(j) AND NOT(stg_input_sel(num_stages+1-k))) OR
                             (imaginv(j) AND stg_input_sel(num_stages+1-k));
    END GENERATE gsai;
  END GENERATE stgc;


  stg: FOR k IN num_stages DOWNTO 2 GENERATE

    stgi: apn_fftfp_stage
    GENERIC MAP (device_family=>device_family,
                 input_format=>input_format,
                 addwidth=>2*k, 
                 delay=>(2**((2*k)-2)),
                 accuracy=>accuracy,
                 dsp=>dsp,
                 realfile=>twidrom_base & "twrfp" & integer'image(k-1) & ".hex",
                 imagfile=>twidrom_base & "twifp" & integer'image(k-1) & ".hex",
                 twidfile=>twidrom_base & "twqfp" & integer'image(k-1) & ".hex")
    PORT MAP (sysclk=>sysclk,
              reset=>reset,
              enable=>enable,
              startin=>start_stage_in(k),
              radix=>radix,
              stg_sel=>stg_input_sel(num_stages+1-k),
              realin=>real_stage_in(k)(32 DOWNTO 1),
              imagin=>imag_stage_in(k)(32 DOWNTO 1),
              realout=>real_stage_out(k)(32 DOWNTO 1),
              imagout=>imag_stage_out(k)(32 DOWNTO 1),
              startout=>start_stage_out(k)
    );

  END GENERATE stg;


  stg_last: apn_fftfp_laststage
  GENERIC MAP (
               device_family =>device_family,
                 dsp=>dsp
               )
  PORT MAP (sysclk=>sysclk,
            reset=>reset,
            enable=>enable,
            startin=>start_stage_in(1),
            radix=>radix,
            realin=>real_stage_in(1)(32 DOWNTO 1),
            imagin=>imag_stage_in(1)(32 DOWNTO 1),
            realout=>real_stage_out(1)(32 DOWNTO 1),
            imagout=>imag_stage_out(1)(32 DOWNTO 1),
            startout=>start_stage_out(1)
  );

  realout  <= real_stage_out(1)(32 DOWNTO 1);
  imagout  <= imag_stage_out(1)(32 DOWNTO 1);
  startout <= start_stage_out(1);
  
END rtl;

