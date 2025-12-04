`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/15/2025 03:26:06 PM
// Design Name: 
// Module Name: adc_subsystem


module adc_subsystem (
    input  logic   clk,
    input  logic   reset,
    input          vauxp15, // Analog input (positive) - connect to JXAC4:N2 PMOD pin  (XADC4)
    input          vauxn15, // Analog input (negative) - connect to JXAC10:N1 PMOD pin (XADC4)
    output logic [15:0] data_out,
    output logic [15:0] scaled_adc_data,
    output logic [15:0] ave_data
    );
    logic        ready;              // Data ready from XADC
    logic        ready_r, ready_pulse;
    logic [31:0] scaled_adc_data_temp; // Scaled ADC data for display
    logic [6:0]  daddr_in;              // XADC address
    logic        enable;                // XADC enable
    logic        eos_out;               // End of sequence
    logic        busy_out;              // XADC busy signal

    // Constants
    localparam CHANNEL_ADDR = 7'h1f;     // XA4/AD15 (for XADC4)
    // XADC Instantiation
    xadc_wiz_0 XADC_INST (
        .di_in(16'h0000),        // Not used for reading
        .daddr_in(CHANNEL_ADDR), // Channel address
        .den_in(enable),         // Enable signal
        .dwe_in(1'b0),           // Not writing, so set to 0
        .drdy_out(ready),        // Data ready signal (when high, ADC data is valid)
        .do_out(data_out),           // ADC data output
        .dclk_in(clk),           // Use system clock
        .reset_in(reset),   // Active-high reset
        .vp_in(1'b0),            // Not used, leave disconnected
        .vn_in(1'b0),            // Not used, leave disconnected
        .vauxp15(vauxp15),       // Auxiliary analog input (positive)
        .vauxn15(vauxn15),       // Auxiliary analog input (negative)
        .channel_out(),          // Current channel being converted
        .eoc_out(enable),        // End of conversion
        .alarm_out(),            // Not used
        .eos_out(eos_out),       // End of sequence
        .busy_out(busy_out)      // XADC busy signal
     );
   averager  
   #( .power(12), //2**N samples, default is 2**8 = 256 samples
      .N(16)     // # of bits to take the average of
    ) 
   AVERAGER
    ( .reset(reset),
      .clk(clk),
      .EN(ready_pulse),
      .Din(data_out),
      .Q(ave_data)
    );
    
    always_ff @(posedge clk) begin
        if (reset) begin
            scaled_adc_data <= 0;
            scaled_adc_data_temp <= 0;
        end
        else if (ready_pulse) begin
            // Calculation: This scales FFFFh to 270Fh (i.e. 9999d)
            //    mVolts = ave_data/(2^16 - 1) * 9999 = ave_data * 0.152575
            //    mVolts ~ ave_data * 1250/2^13 = (ave_data) * 1250 >> 13
            // NOTE: The 7-seg display will display in millivolts, 
            //       i.e. 9999 is 0.9999 V or 999.9 mV
            //       place the decimal point in the correct place!
//            scaled_adc_data <= (ave_data*9999) >> 16; // was scaled_adc_data_temp
            scaled_adc_data_temp <= {16'd0, ave_data} * 32'd3300;
            scaled_adc_data <= scaled_adc_data_temp[31:16];
            //scaled_adc_data <= scaled_adc_data_temp; // additional register faciliates pipelining
        end                                          // for higher clock frequencies
    end
        // added these 3 lines for the pulser 
      always_ff@(posedge clk)
        if (reset)
           ready_r <= 0;
        else
           ready_r <= ready;
           
      assign ready_pulse = ~ready_r & ready; // generate 1-clk pulse when ready goes high
      
endmodule
