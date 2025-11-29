`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: pwm_system
// Description: PWM-based ADC subsystem with selectable algorithm
//              - Ramp ADC: Counts 0->255, captures at comparator edge
//              - SAR ADC: Binary search, exactly 8 comparisons
//////////////////////////////////////////////////////////////////////////////////

module pwm_system (
    input  logic        clk,
    input  logic        reset,
    input  logic [1:0]  bin_bcd_select,
    input  logic        pwm_compare,
    output logic [15:0] led,
    output logic [15:0] pwm_system_out,
    output logic        pwm_out
);
    //==========================================================================
    // RAMP ADC Signals
    //==========================================================================
    logic [7:0] ramp_duty_cycle;
    logic ramp_rising_edge;
    logic ramp_falling_edge;
    logic ramp_enable;
    logic [7:0] ramp_raw_adc;
    logic [7:0] ramp_avg_data;
    logic ramp_comparator_was_high;
    logic ramp_pwm_out;
    
    assign ramp_enable = 1'b1;
    
    // Sawtooth generator for Ramp ADC (generates both PWM and ramp)
    saw_generator #(
        .WIDTH(8), 
        .CLOCK_FREQ(100_000_000), 
        .WAVE_FREQ_HZ(100)
    ) ramp_saw_gen (
        .clk(clk),
        .reset(reset),
        .enable(ramp_enable),
        .pwm_out(ramp_pwm_out),
        .R2R_out(ramp_duty_cycle)
    );
    
    // Edge detector for Ramp ADC
    edge_detector ramp_edge_det (
        .clk(clk),
        .reset(reset),
        .signal_in(pwm_compare),
        .rising_edge(ramp_rising_edge),
        .falling_edge(ramp_falling_edge)
    );
    
    
    // Ramp ADC capture with saturation handling
    always_ff @(posedge clk) begin
        if (reset) begin
            ramp_raw_adc <= 8'h00;
        end else if (ramp_falling_edge) begin
            // Normal: capture at comparator edge
            ramp_raw_adc <= ramp_duty_cycle;
        end else if (ramp_duty_cycle == 8'hFF) begin
            if (pwm_compare) begin
                // Saturate high: input exceeds range
                ramp_raw_adc <= 8'hFF;
            end
        end
    end
    
    // Averager for Ramp ADC
    averager #(
        .power(6),  // 2^6 = 64 samples
        .N(8)
    ) ramp_averager (
        .reset(reset),
        .clk(clk),
        .EN(ramp_falling_edge),
        .Din(ramp_raw_adc),
        .Q(ramp_avg_data)
    );
    
    
    //==========================================================================
    // Mode Selection Multiplexing
    //==========================================================================
    logic [7:0] selected_raw_adc;
    logic [7:0] selected_avg_data;
    logic       selected_update_flag;
    
    always_comb begin
        if (adc_mode == 1'b0) begin
            // Ramp ADC mode
            pwm_out             = ramp_pwm_out;
            selected_raw_adc    = ramp_raw_adc;
            selected_avg_data   = ramp_avg_data;
            selected_update_flag = ramp_falling_edge;
        end else begin
            // SAR ADC mode
            pwm_out             = sar_pwm_out;
            selected_raw_adc    = sar_adc_result;
            selected_avg_data   = sar_avg_data;
            selected_update_flag = sar_conversion_done;
        end
    end
    
    //==========================================================================
    // Scaling and Display Logic (Common to both modes)
    //==========================================================================
    logic [15:0] scaled_pwm_data;
    logic [31:0] scaled_pwm_temp;
    logic [15:0] bcd_value;
    
    // Scale averaged ADC value to millivolts
    // 0-255 maps to 0-3300mV
    // Formula: (value * 13246) >> 10 gives accurate 3300mV at 255
    always_ff @(posedge clk) begin
        if (reset) begin
            scaled_pwm_data <= 0;
            scaled_pwm_temp <= 0;
        end
        else if (selected_update_flag) begin
            scaled_pwm_temp <= {24'd0, selected_avg_data[7:0]} * 32'd13246;
            scaled_pwm_data <= scaled_pwm_temp[25:10];
        end
    end
    
    // Binary to BCD converter for decimal display
    bin_to_bcd bin2bcd_inst (
        .clk(clk),
        .reset(reset),
        .bin_in(scaled_pwm_data),
        .bcd_out(bcd_value)
    );
    
    // Output multiplexer
    always_comb begin
        case (bin_bcd_select)
            2'b00: pwm_system_out = scaled_pwm_data;        // Scaled voltage (hex)
            2'b01: pwm_system_out = bcd_value;              // Scaled voltage (BCD/decimal)
            2'b10: pwm_system_out = {8'h00, selected_raw_adc};    // Raw ADC value
            2'b11: pwm_system_out = {8'h00, selected_avg_data};   // Averaged ADC value
            default: pwm_system_out = 16'h0000;
        endcase
    end
    
    // LED display (optional - show current mode or status)
    assign led = {8'h00, selected_avg_data};

endmodule
