module pwm_adc_test (
    input  logic       clk,           // 100 MHz
    input  logic       reset,
    input  logic [3:0] sw,            // Speed select
    input  logic       comparator_in, // From TLV3701
    
    output logic       pwm_out,       // To RC filter
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an
);

    // Select ramp frequency based on switches
    logic [WIDTH-1:0] duty_cycle;
    logic [WIDTH-1:0] r2r_out;
    logic ramp_enable;
    real ramp_freq;
    
    always_comb begin
        case (sw[1:0])
            2'b00: ramp_freq = 10.0;    // 10 Hz - slow for testing
            2'b01: ramp_freq = 100.0;   // 100 Hz - moderate
            2'b10: ramp_freq = 1000.0;  // 1 kHz - fast
            2'b11: ramp_freq = 10000.0; // 10 kHz - very fast
            default: ramp_freq = 100.0;
        endcase
    end
    
    assign ramp_enable = 1'b1;  // Always enabled
    
    // Instantiate sawtooth generator
    sawtooth_generator #(
        .WIDTH(8),
        .CLOCK_FREQ(100_000_000),
        .RAMP_FREQ(ramp_freq)  // Use selected frequency
    ) sawtooth_inst (
        .clk(clk),
        .reset(reset),
        .enable(ramp_enable),
        .pwm_out(pwm_out),
        .R2R_out(r2r_out),
        .duty_cycle(duty_cycle)  // This is what we'll capture!
    );
    
    // Synchronize comparator input (ALWAYS synchronize external signals!)
    logic comp_sync1, comp_sync2, comp_prev;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            comp_sync1 <= 0;
            comp_sync2 <= 0;
            comp_prev <= 0;
        end else begin
            comp_sync1 <= comparator_in;
            comp_sync2 <= comp_sync1;
            comp_prev <= comp_sync2;
        end
    end
    
    // Edge detection
    logic falling_edge, rising_edge;
    assign falling_edge = comp_prev && !comp_sync2;   // HIGH → LOW
    assign rising_edge = !comp_prev && comp_sync2;    // LOW → HIGH
    
    // Capture ADC value on falling edge
    logic [7:0] adc_captured;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            adc_captured <= 0;
        end else if (falling_edge) begin
            adc_captured <= duty_cycle;  // Capture current duty cycle!
        end
    end
    
    // Display captured value
    logic [15:0] display_value;
    assign display_value = {8'h00, adc_captured};
    
    // LED indicators
    assign led[7:0] = adc_captured;      // Show captured value
    assign led[8] = comp_sync2;           // Comparator state
    assign led[9] = falling_edge;         // Edge pulse (will be brief)
    assign led[11:10] = sw[1:0];          // Show speed setting
    assign led[15:12] = 4'b0;
    
    // 7-segment display (reuse from Lab 5)
    seven_segment_display_subsystem display_inst (
        .clk(clk),
        .reset(reset),
        .sec_dig1(display_value[3:0]),
        .sec_dig2(display_value[7:4]),
        .min_dig1(display_value[11:8]),
        .min_dig2(display_value[15:12]),
        .decimal_point(4'b0000),
        .CA(seg[6]), .CB(seg[5]), .CC(seg[4]), .CD(seg[3]),
        .CE(seg[2]), .CF(seg[1]), .CG(seg[0]), .DP(),
        .AN1(an[0]), .AN2(an[1]), .AN3(an[2]), .AN4(an[3])
    );

endmodule