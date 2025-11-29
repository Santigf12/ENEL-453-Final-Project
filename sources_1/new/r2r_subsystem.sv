module r2r_subsystem (
    input  logic        clk,
    input  logic        reset,
    input  logic [1:0]  bin_bcd_select,
    input  logic        r2r_compare,      
    output logic [7:0]  r2r_bus,          
    output logic [15:0] r2r_system_out
);
    // Internal signal declarations
    logic [7:0] duty_cycle;
    logic rising_edge;
    logic falling_edge;
    logic [15:0] scaled_r2r_data;
    logic [31:0] scaled_r2r_temp;
    logic [15:0] bcd_value;
    logic r2r_enable;
    logic [7:0] r2r_raw_adc;
    logic [7:0] r2r_avg_data;
    
    // Saturation detection
    logic comparator_was_high;
    
    assign r2r_enable = 1'b1;
    assign r2r_bus = duty_cycle;
    
    saw_generator #(
        .WIDTH(8), 
        .CLOCK_FREQ(100_000_000), 
        .WAVE_FREQ_HZ(100)
    ) saw_generator (
        .clk(clk),
        .reset(reset),
        .enable(r2r_enable),
        .R2R_out(duty_cycle)
    );
    
    edge_detector edge_detector (
        .clk(clk),
        .reset(reset),
        .signal_in(r2r_compare),
        .rising_edge(rising_edge),
        .falling_edge(falling_edge)
    );
   
    
    // ADC capture with saturation handling
    always_ff @(posedge clk) begin
        if (reset) begin
            r2r_raw_adc <= 8'h00;
        end else if (falling_edge) begin
            // Normal case: capture ramp value at comparator transition
            r2r_raw_adc <= duty_cycle;
        end else if (duty_cycle == 8'hFE) begin
            if (r2r_compare) begin
                // Comparator still high at max = input exceeds range (saturate high)
                r2r_raw_adc <= 8'hFF;
            end
        end
    end
    
    bin_to_bcd BIN2BCD (
        .clk(clk),
        .reset(reset),
        .bin_in(scaled_r2r_data),
        .bcd_out(bcd_value)
    );
    
    averager #(
        .power(6),
        .N(8)
    ) AVERAGER (
        .reset(reset),
        .clk(clk),
        .EN(falling_edge),
        .Din(r2r_raw_adc),
        .Q(r2r_avg_data)
    );
   
    always_ff @(posedge clk) begin
        if (reset) begin
            scaled_r2r_data <= 0;
            scaled_r2r_temp <= 0;
        end
        else if (falling_edge) begin
            scaled_r2r_temp <= {24'd0, r2r_avg_data[7:0]} * 32'd13246;
            scaled_r2r_data <= scaled_r2r_temp[25:10];  // Divide by 1024
        end
    end
    
    always_comb begin
        case (bin_bcd_select)
            2'b00: r2r_system_out = scaled_r2r_data;
            2'b01: r2r_system_out = bcd_value;
            2'b10: r2r_system_out = {8'h00, r2r_raw_adc};
            2'b11: r2r_system_out = {8'h00, r2r_avg_data};
            default: r2r_system_out = 16'h0000;
        endcase
    end
    
endmodule