module r2r_subsystem (
    input  logic        clk,
    input  logic        reset,
    input  logic [1:0]  bin_bcd_select,
    input  logic        r2r_compare, 
    input  logic        adc_mode,     // 0 = Ramp, 1 = SAR
    output logic [7:0]  r2r_bus,          
    output logic [15:0] r2r_system_out
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
    
    assign ramp_enable = 1'b1;
    
    // Sawtooth generator for Ramp ADC
    saw_generator #(
        .WIDTH(8), 
        .CLOCK_FREQ(200_000_000), 
        .WAVE_FREQ_HZ(100)
    ) ramp_saw_gen (
        .clk(clk),
        .reset(reset),
        .enable(ramp_enable),
        .R2R_out(ramp_duty_cycle)
    );
    
    // Edge detector for Ramp ADC
    edge_detector ramp_edge_det (
        .clk(clk),
        .reset(reset),
        .signal_in(r2r_compare),
        .rising_edge(ramp_rising_edge),
        .falling_edge(ramp_falling_edge)
    );
    
    // Ramp ADC capture with saturation handling
    always_ff @(posedge clk) begin
        if (reset) begin
            ramp_raw_adc <= 8'h00;
        end else if (ramp_falling_edge) begin
            ramp_raw_adc <= ramp_duty_cycle;
        end else if (ramp_duty_cycle == 8'hFE) begin
            if (r2r_compare) begin
                ramp_raw_adc <= 8'hFF;
            end
        end
    end
    
    // Averager for Ramp ADC
    averager #(
        .power(6),
        .N(8)
    ) ramp_averager (
        .reset(reset),
        .clk(clk),
        .EN(ramp_falling_edge),
        .Din(ramp_raw_adc),
        .Q(ramp_avg_data)
    );
    
    //==========================================================================
    // SAR ADC Signals
    //==========================================================================
    logic [7:0] sar_dac_out;
    logic [7:0] sar_adc_result;
    logic       sar_conversion_done;
    logic       sar_start;
    logic [7:0] sar_avg_data;
    
    // SAR ADC core (R2R settles much faster than PWM, so fewer settle cycles)
    sar_adc #(
        .WIDTH(8),
        .SETTLE_CYCLES(250000)  // R2R settles quickly, ~1us at 100MHz
    ) sar_adc_inst (
        .clk(clk),
        .reset(reset),
        .start(sar_start),
        .compare_in(r2r_compare),
        .dac_out(sar_dac_out),
        .adc_result(sar_adc_result),
        .conversion_done(sar_conversion_done)
    );
    
    // Auto-start logic and mode switch detection (combined)
    logic [15:0] sar_start_delay;
    logic adc_mode_prev;

    always_ff @(posedge clk) begin
        if (reset) begin
            sar_start <= 1'b0;
            sar_start_delay <= 16'd0;
            adc_mode_prev <= 1'b0;
        end else begin
            adc_mode_prev <= adc_mode;
            
            if (adc_mode == 1'b1) begin
                // Check for mode switch (rising edge of adc_mode)
                if (adc_mode && !adc_mode_prev) begin
                    sar_start_delay <= 16'd1;
                    sar_start <= 1'b0;
                end
                // Normal auto-restart logic
                else if (sar_conversion_done) begin
                    sar_start_delay <= 16'd1;
                    sar_start <= 1'b0;
                end else if (sar_start_delay > 0) begin
                    sar_start_delay <= sar_start_delay + 1;
                    if (sar_start_delay >= 16'd100) begin
                        sar_start <= 1'b1;
                        sar_start_delay <= 16'd0;
                    end
                end else if (sar_start) begin
                    sar_start <= 1'b0;
                end
            end else begin
                sar_start <= 1'b0;
                sar_start_delay <= 16'd0;
            end
        end 
    end
    
    // Averager for SAR ADC
    averager #(
        .power(6),
        .N(8)
    ) sar_averager (
        .reset(reset),
        .clk(clk),
        .EN(sar_conversion_done),
        .Din(sar_adc_result),
        .Q(sar_avg_data)
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
            r2r_bus              = ramp_duty_cycle;
            selected_raw_adc     = ramp_raw_adc;
            selected_avg_data    = ramp_avg_data;
            selected_update_flag = ramp_falling_edge;
        end else begin
            // SAR ADC mode
            r2r_bus              = sar_dac_out;
            selected_raw_adc     = sar_adc_result;
            selected_avg_data    = sar_avg_data;
            selected_update_flag = sar_conversion_done;
        end
    end
    
    //==========================================================================
    // Scaling and Display Logic (Common to both modes)
    //==========================================================================
    logic [15:0] scaled_r2r_data;
    logic [31:0] scaled_r2r_temp;
    logic [15:0] bcd_value;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            scaled_r2r_data <= 0;
            scaled_r2r_temp <= 0;
        end
        else if (selected_update_flag) begin
            scaled_r2r_temp <= {24'd0, selected_avg_data[7:0]} * 32'd13246;
            scaled_r2r_data <= scaled_r2r_temp[25:10];
        end
    end
    
    // Binary to BCD converter
    bin_to_bcd bin2bcd_inst (
        .clk(clk),
        .reset(reset),
        .bin_in(scaled_r2r_data),
        .bcd_out(bcd_value)
    );
    
    // Output multiplexer
    always_comb begin
        case (bin_bcd_select)
            2'b00: r2r_system_out = scaled_r2r_data;
            2'b01: r2r_system_out = bcd_value;
            2'b10: r2r_system_out = {8'h00, selected_raw_adc};
            2'b11: r2r_system_out = {8'h00, selected_avg_data};
            default: r2r_system_out = 16'h0000;
        endcase
    end
    
endmodule