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
USE ieee.numeric_std.all;

LIBRARY work;
USE work.auk_dspip_math_pkg.all;
USE work.auk_fft_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFPBDR_CORE                         ***
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

ENTITY apn_fftfpbdr_core IS
GENERIC (
         device_family: string;  
         num_stages   : natural := 5;  
         input_format : string := "NATURAL_ORDER";
         points       : positive := 256;
         accuracy     : natural := 1;
         dsp          : natural := 0;
         twidrom_base : string := "fftfp" 
        );
PORT (
      sysclk        : IN  STD_LOGIC;
      reset         : IN  STD_LOGIC;
      enable        : IN  STD_LOGIC;
      radix         : IN  STD_LOGIC;
      startin       : IN  STD_LOGIC;
      length        : IN  STD_LOGIC_VECTOR (log2_ceil(points)+1 DOWNTO 1);
      mlenfor       : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
      mlentwo       : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
      inverse       : IN  STD_LOGIC;
      stg_input_sel : IN  STD_LOGIC_VECTOR (num_stages downto 1);
      realin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      realout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout      : OUT STD_LOGIC
     );
END apn_fftfpbdr_core;

ARCHITECTURE rtl OF apn_fftfpbdr_core IS
  constant internal_data_width : integer := get_internal_data_width(dsp, device_family);

  type stage_data_outtype IS ARRAY (num_stages DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  type stage_data_intype  IS ARRAY (num_stages DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  
  signal start_stage_in  : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal start_stage_out : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal inv_stage_in, inv_stage_out : STD_LOGIC_VECTOR (num_stages DOWNTO 1);
  signal realinv, imaginv: STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal real_stage_out, imag_stage_out : stage_data_outtype;
  signal real_stage_in,  imag_stage_in  : stage_data_intype;
  signal start_out, inv_out : STD_LOGIC;
  signal real_out, imag_out : STD_LOGIC_VECTOR (32 DOWNTO 1);
  
  component apn_fftfpbdr_stage
  GENERIC (
           device_family: string;
           input_format : string := "NATURAL_ORDER";
           addwidth     : positive := 4;
           stage        : positive := 1;
           twidwidth    : positive := 4;
           points       : positive := 256;
           delay        : positive := 4;
           accuracy     : natural := 1;
           dsp          : natural := 0;
           realffile     : string := "twrfp1.hex";
           imagffile     : string := "twifp1.hex";
           twidffile     : string := "twqfp1.hex";
           realrfile     : string := "twrfp1.hex";
           imagrfile     : string := "twifp1.hex";
           twidrfile     : string := "twqfp1.hex"
          );
  PORT (
        sysclk  : IN STD_LOGIC;
        reset   : IN STD_LOGIC;
        enable  : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        mlenfor : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
        mlentwo : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
        radix   : IN STD_LOGIC;
        stg_sel : IN STD_LOGIC;
        invin   : IN  STD_LOGIC;
        realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
        invout  : OUT  STD_LOGIC;
        realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        startout : OUT STD_LOGIC
       );
   end component;
 
  component apn_fftfpbdr_firststage
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
      stg_sel       : IN  STD_LOGIC;
      startin       : IN  STD_LOGIC;
      mlenfor       : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
      mlentwo       : IN  STD_LOGIC_VECTOR (log2_ceil(4**num_stages)+1 DOWNTO 1);
      radix         : IN  STD_LOGIC;
      invin         : IN  STD_LOGIC;
      realin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagin        : IN  STD_LOGIC_VECTOR (32 DOWNTO 1);
      invout        : OUT STD_LOGIC;
      realout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagout       : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout      : OUT STD_LOGIC
    );
  end component;

  component apn_fftfpbdr_laststage
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
        invin   : IN  STD_LOGIC;
        realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        
        invout  : OUT STD_LOGIC;
        realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        startout : OUT STD_LOGIC
       );
   end component;

BEGIN
  
  realinv <= realin when inverse = '0' else 
             imagin;
  imaginv <= imagin when inverse = '0' else
             realin;

  conn: PROCESS (inverse, startin, realinv, imaginv, start_stage_out, inv_stage_out, real_stage_out, imag_stage_out)
  BEGIN

    IF (inverse = '1') THEN

      start_stage_in(1) <= startin;
      inv_stage_in(1) <= inverse;
      gsa1: FOR j IN 1 TO 32 LOOP
        real_stage_in(1)(j) <= realinv(j);
        imag_stage_in(1)(j) <= imaginv(j); 
      END LOOP gsa1;

      stgc1: FOR k IN 1 TO num_stages-1 LOOP
        start_stage_in(k+1) <= start_stage_out(k);
        inv_stage_in(k+1) <= inv_stage_out(k);
        gsai1: FOR j IN 1 TO 32 LOOP
          real_stage_in(k+1)(j) <= real_stage_out(k)(j);
          imag_stage_in(k+1)(j) <= imag_stage_out(k)(j);
        END LOOP gsai1;
      END LOOP stgc1;

      start_out <= start_stage_out(num_stages);
      inv_out <= inv_stage_out(num_stages);
      gsb1: FOR j IN 1 TO 32 LOOP
        real_out(j) <= real_stage_out(num_stages)(j);
        imag_out(j) <= imag_stage_out(num_stages)(j); 
      END LOOP gsb1;

    ELSE

      start_stage_in(num_stages) <= startin;
      inv_stage_in(num_stages) <= inverse;
      gsa0: FOR j IN 1 TO 32 LOOP
        real_stage_in(num_stages)(j) <= realinv(j);
        imag_stage_in(num_stages)(j) <= imaginv(j); 
      END LOOP gsa0;

      stgc0: FOR k IN 2 TO num_stages LOOP
        start_stage_in(k-1) <= start_stage_out(k);
        inv_stage_in(k-1) <= inv_stage_out(k);
        gsai0: FOR j IN 1 TO 32 LOOP
          real_stage_in(k-1)(j) <= real_stage_out(k)(j);
          imag_stage_in(k-1)(j) <= imag_stage_out(k)(j);
        END LOOP gsai0;
      END LOOP stgc0;

      start_out <= start_stage_out(1);
      inv_out <= inv_stage_out(1);
      gsb0: FOR j IN 1 TO 32 LOOP
        real_out(j) <= real_stage_out(1)(j);
        imag_out(j) <= imag_stage_out(1)(j); 
      END LOOP gsb0;

    END IF;

  END PROCESS conn;


  stg_input: apn_fftfpbdr_firststage
      GENERIC MAP (
        device_family  =>  device_family,
        addwidth  =>  2*1,
        stage     =>  1,
        twidwidth =>  ((log2_ceil(4**num_stages)) - ((1-1)*2)),
        points    =>  4**num_stages,
        accuracy  =>  accuracy,
        dsp       =>  dsp,
        realfile  =>  twidrom_base & "twrfp" & integer'image(num_stages-1) & ".hex",
        imagfile  =>  twidrom_base & "twifp" & integer'image(num_stages-1) & ".hex",
        twidfile  =>  twidrom_base & "twqfp" & integer'image(num_stages-1) & ".hex"
      )
    PORT MAP (
      sysclk        =>  sysclk,
      reset         =>  reset,
      enable        =>  enable,
      stg_sel       =>  stg_input_sel(num_stages),
      startin       =>  start_stage_in(1),
      mlenfor       =>  mlenfor,
      mlentwo       =>  mlentwo,
      radix         =>  radix,
      invin         =>  inv_stage_in(1),
      realin        =>  real_stage_in(1)(32 DOWNTO 1),
      imagin        =>  imag_stage_in(1)(32 DOWNTO 1),
      invout        =>  inv_stage_out(1),
      realout       =>  real_stage_out(1)(32 DOWNTO 1),
      imagout       =>  imag_stage_out(1)(32 DOWNTO 1),
      startout      =>  start_stage_out(1)
    );

  stg: FOR k IN 2 TO num_stages-1 GENERATE

    stgi: apn_fftfpbdr_stage
      GENERIC MAP (
        device_family => device_family,
        input_format=>input_format,
        addwidth  =>  2*k,
        stage     =>  k,
        twidwidth =>  ((log2_ceil(4**num_stages)) - ((k-1)*2)),
        points    =>  4**num_stages,
        delay     =>  (2**((2*k)-2)),
        accuracy  =>  accuracy,
        dsp       =>  dsp,
        realffile =>  twidrom_base & "twrfp" & integer'image(k-1) & ".hex",
        imagffile =>  twidrom_base & "twifp" & integer'image(k-1) & ".hex",
        twidffile =>  twidrom_base & "twqfp" & integer'image(k-1) & ".hex",
        realrfile =>  twidrom_base & "twrfp" & integer'image(num_stages-k) & ".hex",
        imagrfile =>  twidrom_base & "twifp" & integer'image(num_stages-k) & ".hex",
        twidrfile =>  twidrom_base & "twqfp" & integer'image(num_stages-k) & ".hex"
      )
      PORT MAP (
        sysclk    =>  sysclk,
        reset     =>  reset,
        enable    =>  enable,
        startin   =>  start_stage_in(k),
        mlenfor   =>  mlenfor,
        mlentwo   =>  mlentwo,
        radix     =>  radix,
        stg_sel   =>  stg_input_sel(num_stages-k+1),
        invin     =>  inv_stage_in(k),
        realin    =>  real_stage_in(k)(32 DOWNTO 1),
        imagin    =>  imag_stage_in(k)(32 DOWNTO 1),
        invout    =>  inv_stage_out(k),
        realout   =>  real_stage_out(k)(32 DOWNTO 1),
        imagout   =>  imag_stage_out(k)(32 DOWNTO 1),
        startout  =>  start_stage_out(k)
    );

  END GENERATE stg;

  stg_last: apn_fftfpbdr_laststage
    GENERIC MAP (
      device_family =>  device_family,
      input_format  =>  input_format,
      addwidth      =>  2*num_stages, 
      delay         =>  (2**((2*num_stages)-2)),
      accuracy      =>  accuracy,
      dsp           =>  dsp,
      realfile      =>  twidrom_base & "twrfp" & integer'image(num_stages-1) & ".hex", 
      imagfile      =>  twidrom_base & "twifp" & integer'image(num_stages-1) & ".hex", 
      twidfile      =>  twidrom_base & "twqfp" & integer'image(num_stages-1) & ".hex" 
    )
    PORT MAP (
      sysclk    =>  sysclk,
      reset     =>  reset,
      enable    =>  enable,
      startin   =>  start_stage_in(num_stages),
      radix     =>  radix,
      stg_sel   =>  stg_input_sel(1),
      invin     =>  inv_stage_in(num_stages),
      realin    =>  real_stage_in(num_stages)(32 DOWNTO 1),
      imagin    =>  imag_stage_in(num_stages)(32 DOWNTO 1),
      invout    =>  inv_stage_out(num_stages),
      realout   =>  real_stage_out(num_stages)(32 DOWNTO 1),
      imagout   =>  imag_stage_out(num_stages)(32 DOWNTO 1),
      startout  =>  start_stage_out(num_stages)
    );

  realout  <= real_out(32 DOWNTO 1) when inv_out = '0' else
              imag_out(32 DOWNTO 1);
  imagout  <= imag_out(32 DOWNTO 1) when inv_out = '0' else
              real_out(32 DOWNTO 1);
  startout <= start_out;

END rtl;

