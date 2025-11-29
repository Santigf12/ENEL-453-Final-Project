//////////////////////////////////////////////////////////////////////////////////
// Module Name: averager_simple
// 
// Description: 
// This module implements a moving average filter that performs oversampling and 
// averaging to achieve increased resolution. It takes 8-bit input samples and 
// produces a 16-bit averaged output, where the upper 8 bits represent the average
// and the lower 8 bits provide additional resolution gained through oversampling.
//
// The number of samples averaged is determined by 2^power. The power parameter must
// be 8 or greater. For example:
// - power = 8: averages 256 samples, providing 4 additional bits of resolution
// - power = 16: averages 65536 samples, providing 8 additional bits of resolution
//
// Theory of Operation:
// - Maintains a running sum of 2^power samples in a shift register array
// - On each clock cycle (when EN=1), adds new sample and subtracts oldest sample
// - Divides sum by 2^power through bit selection to produce averaged output
// - Additional resolution bits come from the bits below the division point
//
// Ports:
// - clk: Clock input
// - reset: Active-high synchronous reset
// - EN: Enable signal (1 = update average, 0 = hold current value)
// - Din[7:0]: 8-bit input data
// - Q[15:0]: 16-bit output where:
//     * Q[15:8] = averaged value (same scale as input)
//     * Q[7:0] = additional resolution bits
//
// Parameters:
// - power: Determines number of samples averaged (2^power)
//          Must be >= 8 for meaningful results
//          Default = 8 (256 samples)
//
// Example instantiation:
// averager_simple #(
//     .power(8)  // Average 256 samples
// ) avg_inst (
//     .clk(clk),
//     .reset(reset),
//     .EN(ready_pulse),     // Typically tied ready_pulse or similar signal
//     .Din(adc_in),  // 8-bit ADC input
//     .Q(avg_out)    // 16-bit averaged output
// );
//////////////////////////////////////////////////////////////////////////////////

module averager_simple
    #(parameter int power = 8) // must be at least 8: 2**power samples, default is 2**8 = 256 samples 
    (
        input logic clk,
        reset,
        EN,
        input logic [7:0] Din,   // input to averager 
        output logic [15:0] Q     // N-bit moving average
    );
    
    // Internal signals
    logic [7:0] REG_ARRAY [2**power:1];
    logic [power+7:0] sum;
    logic [7:0] Q_temp, lower8bits;
    
    // Output assignment
    assign Q_temp     = sum[power+7:power];
    assign lower8bits = sum[power-1:power-8];    
    assign Q = {Q_temp,lower8bits};
   
    always_ff @(posedge clk) begin
        if (reset) begin
            sum <= 0;
            for (int j = 1; j <= 2**power; j++) begin
                REG_ARRAY[j] <= 0;
            end
        end
        else if (EN) begin
            sum <= sum + Din - REG_ARRAY[2**power];
            for (int j = 2**power; j > 1; j--) begin
                REG_ARRAY[j] <= REG_ARRAY[j-1];
            end
            REG_ARRAY[1] <= Din;
        end
    end
endmodule
