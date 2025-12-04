/*
This design uses the XADC from the IP Catalog. The specific channel is XADC4.
The Auxiliary Analog Inputs are VAUXP[15] and VAUXN[15].
These map to the FPGA pins of N2 and N1, respecitively (also in .XDC).
These map to the JXADC PMOD and the specific PMOD inputs are
JXADC4:N2 and JXAC10:N1, respectively. These pin are right beside the PMOD GND
on JXAC11:GND and JXAC5:GND.

The ADC is set to single-ended, continuous sampling, 1 MSps, 256 averaging. 
Additional averaging is done using the averager module below.
*/
module lab_5_top_level_students (
    input  logic   clk,
    input  logic   reset,
    input  logic [1:0] bin_bcd_select,
    input logic [1:0] system_select,
    input logic pwm_compare,
    input logic r2r_compare,
    input logic adc_mode,

   // input  logic [15:0] switches_inputs,
    input          vauxp15, // Analog input (positive) - connect to JXAC4:N2 PMOD pin  (XADC4)
    input          vauxn15, // Analog input (negative) - connect to JXAC10:N1 PMOD pin (XADC4)
    output logic   CA, CB, CC, CD, CE, CF, CG, DP,
    output logic   AN1, AN2, AN3, AN4,
    output logic pwm_out,
    output logic [7:0] r2r_bus
);
    // Internal signal declarations
    
    // Tie analog inputs to high-impedance to prevent I/O buffer inference
    //assign vauxp5 = 1'bZ;
    //assign vauxn5 = 1'bZ;
        
    logic [15:0] mux_out;
    logic [15:0] xadc_out, pwm_system_out, r2r_system_out;
    logic [3:0]  decimal_point;


    
    
    xadc_system xadc_system(
    .clk (clk),
    .reset (reset),
    .bin_bcd_select (bin_bcd_select),
    .vauxp15(vauxp15),
    .vauxn15 (vauxn15),
    .xadc_output (xadc_out)
    );
    
    pwm_system pwm_system(
    .clk(clk),
    .reset(reset),
    .bin_bcd_select(bin_bcd_select),
    .pwm_compare(pwm_compare),
    .adc_mode(adc_mode),
    .pwm_system_out(pwm_system_out),
    .pwm_out(pwm_out)
    );
    
    
    r2r_subsystem r2r_subsystem(
    .clk(clk),
    .reset(reset),
    .bin_bcd_select(bin_bcd_select),
    .r2r_compare(r2r_compare),
    .adc_mode(adc_mode),
    .r2r_bus(r2r_bus),
    .r2r_system_out(r2r_system_out)
    );
    
     mux4_16_bits MUX4 (
        .in0(xadc_out), // hexadecimal, scaled and averaged
        .in1(pwm_system_out),       // decimal, scaled and averaged
        .in2(r2r_system_out),      // raw 12-bit ADC hexadecimal
        .in3(16'h0000),        // averaged and before scaling 16-bit ADC (extra 4-bits from averaging) hexadecimal
        .select(system_select),
        .mux_out(mux_out)
    );
    
    // Decimal point control based on display mode
    decimal_point_mux DP_MUX (
        .select(bin_bcd_select),
        .dp(decimal_point)
    );
   
    
     
    // Seven Segment Display Subsystem
    seven_segment_display_subsystem SEVEN_SEGMENT_DISPLAY (
        .clk(clk), 
        .reset(reset), 
        .sec_dig1(mux_out[3:0]),     // Lowest digit
        .sec_dig2(mux_out[7:4]),     // Second digit
        .min_dig1(mux_out[11:8]),    // Third digit
        .min_dig2(mux_out[15:12]),   // Highest digit
        .decimal_point(decimal_point),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD), 
        .CE(CE), .CF(CF), .CG(CG), .DP(DP), 
        .AN1(AN1), .AN2(AN2), .AN3(AN3), .AN4(AN4)
    );
    
    
    
endmodule
