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



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.auk_dspip_math_pkg.all;
use work.auk_dspip_lib_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFPBDR_TOP                          ***
--***                                             ***
--***   Function: FP variable streaming FFT       ***
--***   wrapper                                   ***
--***                                             ***
--***   20/01/10 KHP                              ***
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

entity apn_fftfpbdr_top is
  generic (
    DEVICE_FAMILY_g  : string;
    MAX_FFTPTS_g     : natural := 256;
    NUM_STAGES_g     : natural := 5;
    DATAWIDTH_g      : natural := 16;
    MAX_GROW_g       : natural := 12;
    INPUT_FORMAT_g   : string  := "NATURAL_ORDER";
    OUTPUT_FORMAT_g  : string  := "NATURAL_ORDER";
    DSP_ARCH_g       : natural := 0;
    ACCURACY_g       : natural := 1;
    TWIDROM_BASE_g   : string  := "fftfp";
    TWIDWIDTH_g      : natural := 32;        --temp
    DSP_ROUNDING_g   : natural := 0;         --temp
    REPRESENTATION_g : string  := "natural"; --temp
    PRUNE_g          : string  := "0,0,0"    --temp
    );
  port (
    clk          : in  std_logic;
    reset_n      : in  std_logic;
    fftpts_in    : in  std_logic_vector(log2_ceil(MAX_FFTPTS_g) downto 0);
    inverse      : in  std_logic;
    sink_ready   : out std_logic;
    sink_valid   : in  std_logic;
    sink_real    : in  std_logic_vector(DATAWIDTH_g -1 downto 0);
    sink_imag    : in  std_logic_vector(DATAWIDTH_g - 1 downto 0);
    sink_sop     : in  std_logic;
    sink_eop     : in  std_logic;
    sink_error   : in  std_logic_vector(1 downto 0);
    source_error : out std_logic_vector(1 downto 0);
    source_ready : in  std_logic;
    source_valid : out std_logic;
    source_real  : out std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
    source_imag  : out std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
    source_sop   : out std_logic;
    source_eop   : out std_logic;
    fftpts_out   : out std_logic_vector(log2_ceil(MAX_FFTPTS_g) downto 0)
    );
end entity apn_fftfpbdr_top;

architecture str of apn_fftfpbdr_top is

  signal source_stall     : std_logic;
  signal source_stall_ena : std_logic;
  signal source_stall_reg : std_logic;

  -- aligned with last data output (if source_stall occurs need to hold processing
  -- high until output accepted)
  signal processing_to_end : std_logic;
  signal rvs_processing    : std_logic;

  signal in_valid : std_logic;
  signal in_sop   : std_logic;
  signal in_eop   : std_logic;
  signal in_real  : std_logic_vector(DATAWIDTH_g -1 downto 0);
  signal in_imag  : std_logic_vector(DATAWIDTH_g - 1 downto 0);

  signal out_valid      : std_logic;
  signal out_real       : std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
  signal out_imag       : std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
  -- output from fft engine
  signal fft_out_valid  : std_logic;
  signal fft_out_real   : std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
  signal fft_out_imag   : std_logic_vector(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
  signal curr_pwr_2     : std_logic;
  signal curr_inverse   : std_logic;
  signal curr_fftpts    : std_logic_vector(log2_ceil(MAX_FFTPTS_g) downto 0);
  signal mlenfor        : std_logic_vector(log2_ceil(4**NUM_STAGES_g) downto 0);
  signal mlentwo        : std_logic_vector(log2_ceil(4**NUM_STAGES_g) downto 0);
  signal curr_input_sel : std_logic_vector(NUM_STAGES_g - 1 downto 0);
  signal enable         : std_logic;
  signal source_valid_s : std_logic;
  signal source_valid_d : std_logic;
  signal source_sop_s   : std_logic;
  signal source_eop_s   : std_logic;
  signal reset          : std_logic;
  signal num_sop_sent, prev_num_sop_sent   : unsigned(3 downto 0);

  signal sink_in_data    : std_logic_vector(2*DATAWIDTH_g -1 downto 0);
  signal sink_out_data   : std_logic_vector(2*DATAWIDTH_g -1 downto 0);
  signal source_in_data  : std_logic_vector(2*(DATAWIDTH_g+ MAX_GROW_g) -1 downto 0);
  signal source_out_data : std_logic_vector(2*(DATAWIDTH_g+ MAX_GROW_g) -1 downto 0);
  
  signal inframe   : std_logic;
  signal sent_eop  : std_logic;

  component apn_fftfp_rvs
  GENERIC ( 
    device_family : string; 
    points : natural := 256 
  );
  PORT (
    clk        : IN STD_LOGIC;
    reset      : IN STD_LOGIC;
    enable     : IN STD_LOGIC;
    radix      : IN STD_LOGIC;
    length     : IN STD_LOGIC_VECTOR (log2_ceil(MAX_FFTPTS_g) DOWNTO 0);
    in_valid   : IN STD_LOGIC;
    out_stall  : IN STD_LOGIC;
    real_in    : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
    imag_in    : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
    real_out   : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
    imag_out   : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
    out_valid  : OUT STD_LOGIC;
    processing : OUT STD_LOGIC
  ); 
  end component;

  component apn_fftfpbdr_core
  GENERIC (
      device_family: string;
      num_stages   : natural := NUM_STAGES_g;
      input_format : string  := "NATURAL_ORDER";
      points       : natural := 256;
      accuracy     : natural := 1;
      dsp          : natural := 0;
      twidrom_base : string := "fftfp"
  );
  PORT (
      sysclk : IN STD_LOGIC;
      reset  : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      radix  : IN STD_LOGIC;
      startin: IN STD_LOGIC;
      length : IN STD_LOGIC_VECTOR (log2_ceil(MAX_FFTPTS_g) DOWNTO 0);
      mlenfor : in std_logic_vector(log2_ceil(4**NUM_STAGES_g) downto 0);
      mlentwo : in std_logic_vector(log2_ceil(4**NUM_STAGES_g) downto 0);
      inverse: IN STD_LOGIC;
      stg_input_sel  : IN STD_LOGIC_VECTOR (NUM_STAGES_g - 1 downto 0);
      realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout : OUT STD_LOGIC
  );
  end component;


begin

  reset        <= not reset_n;
  enable       <= in_valid when inframe = '1' else
                  not source_stall_reg;
  source_valid <= source_valid_s;
  source_eop   <= source_eop_s;
  source_sop   <= source_sop_s;
  fftpts_out   <= curr_fftpts;

  --to check if it's in data packet for enable control
  enable_ctrl : process (clk, reset_n)
  begin  -- process enable_ctrl
    if reset_n = '0' then
      inframe <= '0';
    elsif rising_edge(clk) then
      if in_valid = '1' then
        if in_eop = '1' then
          inframe <= '0';
        else
          inframe <= '1';
        end if;
      end if;
    end if;
  end process enable_ctrl;

  --processing_to_end is high from the incoming sop to outgoing eop
  --This signal is meant to be used by the sink control block when 
  --the transform size is changing.
  processing_ctrl : process (clk, reset_n)
  begin  -- process enable_ctrl
    if reset_n = '0' then
      processing_to_end <= '0';
      sent_eop <= '0';
    elsif rising_edge(clk) then
      if (in_valid = '1' and in_sop = '1') OR inframe = '1' OR rvs_processing = '1' then
          processing_to_end <= '1';
      elsif sent_eop = '1' then
          processing_to_end <= '0';
      end if;
 
      if sent_eop = '1' then
        sent_eop <= '0';
      elsif prev_num_sop_sent = 1 and num_sop_sent = 0 then
          sent_eop <= '1';
      end if;
    end if;
  end process processing_ctrl;

  sop_eop_count : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        num_sop_sent <= (others=>'0');
        prev_num_sop_sent <= (others=>'0');
      else
        if in_valid = '1' and in_sop = '1' then
          num_sop_sent <= num_sop_sent + 1;
        elsif source_eop_s = '1' and source_valid_s = '1' and source_ready = '1' then
          num_sop_sent <= num_sop_sent - 1;
        end if;
        prev_num_sop_sent <= num_sop_sent;
      end if;
    end if;
  end process;


  sink_in_data <= sink_imag & sink_real;

  sink_ctrl_inst : auk_dspip_avalon_streaming_block_sink_fftfprvs
    generic map (
      MAX_BLK_g    => MAX_FFTPTS_g,
      NUM_STAGES_g => NUM_STAGES_g,
      STALL_g      => 1,
      DATAWIDTH_g  => 2*DATAWIDTH_g,
      FFT_ARCH     => "MR42")
    port map (
      clk            => clk,
      reset          => reset,
      in_blk         => fftpts_in,
      in_sop         => sink_sop,
      in_eop         => sink_eop,
      in_inverse     => inverse,
      sink_valid     => sink_valid,
      sink_ready     => sink_ready,
      source_stall   => source_stall_ena,
      in_data        => sink_in_data,
      in_error       => sink_error ,
      out_error      => source_error,
      processing     => processing_to_end,
      out_valid      => in_valid,
      out_sop        => in_sop,
      out_eop        => in_eop,
      out_data       => sink_out_data,
      curr_pwr_2     => curr_pwr_2,
      mlenfor        => mlenfor,
      mlentwo        => mlentwo,
      curr_inverse   => curr_inverse,
      curr_blk       => curr_fftpts,
      curr_input_sel => curr_input_sel
    );

  in_real <= sink_out_data(DATAWIDTH_g - 1 downto 0);
  in_imag <= sink_out_data(2*DATAWIDTH_g - 1 downto DATAWIDTH_g);

  source_stall_ena <= source_stall;
  source_stall_ctrl : process (clk, reset_n)
  begin
    if reset_n = '0' then
      source_stall_reg <= '0';
    elsif rising_edge(clk) then
      source_stall_reg <= source_stall_ena;
    end if;
  end process source_stall_ctrl;


  --instantiates FFT engine
  core_inst : apn_fftfpbdr_core
    generic map (
      device_family  => DEVICE_FAMILY_g,
      num_stages     => NUM_STAGES_g,
      input_format   => INPUT_FORMAT_g,
      points         => MAX_FFTPTS_g,
      accuracy       => ACCURACY_g,
      dsp            => DSP_ARCH_g,
      twidrom_base   => TWIDROM_BASE_g
    )
    port map (
      sysclk         => clk,
      reset          => reset,
      enable         => enable,
      radix          => curr_pwr_2,
      startin        => in_valid,
      length         => curr_fftpts,
      mlenfor        => mlenfor,
      mlentwo        => mlentwo,
      inverse        => curr_inverse,
      stg_input_sel  => curr_input_sel,
      realin         => in_real,
      imagin         => in_imag,
      
      realout        => fft_out_real,
      imagout        => fft_out_imag,
      startout       => fft_out_valid
    );


  generate_rvs_module : if (OUTPUT_FORMAT_g = INPUT_FORMAT_g) or
                           (OUTPUT_FORMAT_g = "NATURAL_ORDER" and INPUT_FORMAT_g = "-N/2_to_N/2") generate
    signal rvs_enable : std_logic;
  
  begin
    rvs_enable <= fft_out_valid and enable;

    index_reverse_inst : apn_fftfp_rvs
      generic map (
        device_family => DEVICE_FAMILY_g,
        points => MAX_FFTPTS_g
      )
      port map (
        clk        => clk,
        reset      => reset,
        enable     => rvs_enable,
        radix      => '1',
        length     => curr_fftpts,
        in_valid   => fft_out_valid,
        out_stall  => source_stall_ena,
        real_in    => fft_out_real,
        imag_in    => fft_out_imag,
        real_out   => out_real,
        imag_out   => out_imag,
        out_valid  => out_valid,
        processing => rvs_processing
      );
  end generate generate_rvs_module;


  generate_no_bit_reverse_module : if (OUTPUT_FORMAT_g /= INPUT_FORMAT_g)
                                     and not (OUTPUT_FORMAT_g = "NATURAL_ORDER" and INPUT_FORMAT_g = "-N/2_to_N/2") generate
    rvs_processing <= '0';
    out_real       <= fft_out_real;
    out_imag       <= fft_out_imag;
    out_valid      <= fft_out_valid and enable;
  end generate generate_no_bit_reverse_module;

  source_in_data <= out_imag & out_real;


  source_control_inst : auk_dspip_avalon_streaming_block_source
    generic map (
      MAX_BLK_g   => MAX_FFTPTS_g,
      DATAWIDTH_g => 2*(DATAWIDTH_g + MAX_GROW_g)
    )
    port map (
      clk          => clk,
      reset        => reset,
      in_blk       => curr_fftpts,
      in_valid     => out_valid,
      source_stall => source_stall,
      in_data      => source_in_data,
      source_valid => source_valid_s,
      source_ready => source_ready,
      source_sop   => source_sop_s,
      source_eop   => source_eop_s,
      source_data  => source_out_data
    );     

  source_real <= source_out_data(DATAWIDTH_g + MAX_GROW_g - 1 downto 0);
  source_imag <= source_out_data(2*(DATAWIDTH_g + MAX_GROW_g) - 1 downto DATAWIDTH_g + MAX_GROW_g);



end architecture str;
