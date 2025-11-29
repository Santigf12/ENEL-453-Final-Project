// Sawtooth Generator for ADC Applications
// Generates a sawtooth ramp waveform using PWM
module sawtooth_generator
    #(
        parameter int WIDTH = 8,                   // Bit width for duty_cycle
        parameter int CLOCK_FREQ = 100_000_000,    // System clock frequency in Hz
        parameter real RAMP_FREQ = 1000.0          // Desired ramp frequency in Hz (1 kHz default)
    )
    (
        input  logic clk,              // System clock (100 MHz)
        input  logic reset,            // Active-high reset
        input  logic enable,           // Active-high enable
        output logic pwm_out,          // PWM output signal
        output logic [WIDTH-1:0] R2R_out,     // R2R ladder output
        output logic [WIDTH-1:0] duty_cycle   // Current duty cycle value (for debugging/capture)
    );
    
    // Calculate maximum duty cycle value
    localparam int MAX_DUTY_CYCLE = (2 ** WIDTH) - 1;  // 255 for WIDTH = 8
    
    // Total steps for one complete ramp (0 to MAX_DUTY_CYCLE)
    localparam int TOTAL_STEPS = MAX_DUTY_CYCLE + 1;   // 256 steps
    
    // Calculate downcounter PERIOD to achieve desired ramp frequency
    // Each step takes DOWNCOUNTER_PERIOD clocks
    localparam int DOWNCOUNTER_PERIOD = integer'(CLOCK_FREQ / (RAMP_FREQ * TOTAL_STEPS));
    
    // Validation
    initial begin
        if (DOWNCOUNTER_PERIOD <= 0) begin
            $error("DOWNCOUNTER_PERIOD must be positive. Adjust CLOCK_FREQ or RAMP_FREQ.");
            $error("Current: CLOCK_FREQ=%0d, RAMP_FREQ=%0f, TOTAL_STEPS=%0d", 
                   CLOCK_FREQ, RAMP_FREQ, TOTAL_STEPS);
        end
        $display("Sawtooth Generator Configuration:");
        $display("  Ramp Frequency: %0f Hz", RAMP_FREQ);
        $display("  Steps per Ramp: %0d", TOTAL_STEPS);
        $display("  Downcounter Period: %0d clocks", DOWNCOUNTER_PERIOD);
        $display("  Time per Step: %0f us", (1.0 / CLOCK_FREQ * DOWNCOUNTER_PERIOD * 1_000_000));
        $display("  Total Ramp Time: %0f ms", (1.0 / RAMP_FREQ * 1000));
    end
    
    // Internal signals
    logic zero;  // Pulse from downcounter
    
    assign R2R_out = duty_cycle;  // R2R output follows duty cycle
    
    // Instantiate downcounter
    downcounter #(
        .PERIOD(DOWNCOUNTER_PERIOD)
    ) downcounter_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .zero(zero)
    );
    
    // Sawtooth counter (only counts UP, then resets)
    always_ff @(posedge clk) begin
        if (reset) begin
            duty_cycle <= 0;
        end else if (enable) begin
            if (zero) begin
                if (duty_cycle == MAX_DUTY_CYCLE) begin
                    duty_cycle <= 0;  // Reset to 0 (creates sawtooth)
                end else begin
                    duty_cycle <= duty_cycle + 1;  // Increment
                end
            end
        end else begin
            duty_cycle <= 0;  // Reset when disabled
        end
    end
    
    // Instantiate PWM module
    pwm #(
        .WIDTH(WIDTH)
    ) pwm_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)
    );
    
endmodule