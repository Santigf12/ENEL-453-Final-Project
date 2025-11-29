// Triangle PWM and R2R Generator Module
// Generates a 1 Hz triangle waveform using PWM by adjusting the duty cycle.

module triangle_generator
    #(
        parameter int WIDTH = 8,                   // Bit width for duty_cycle
        parameter int CLOCK_FREQ = 100_000_000,    // System clock frequency in Hz
        parameter real WAVE_FREQ = 1.0             // Desired triangle wave frequency in Hz
    )
    (
        input  logic clk,      // System clock (100 MHz)
        input  logic reset,    // Active-high reset
        input  logic enable,   // Active-high enable
        output logic pwm_out,  // PWM output signal
        output logic [WIDTH-1:0] R2R_out // R2R ladder output
    );

    // Calculate maximum duty cycle value based on WIDTH
    localparam int MAX_DUTY_CYCLE = (2 ** WIDTH) - 1;  // 255 for WIDTH = 8
    // Total steps for duty_cycle (up and down)
    localparam int TOTAL_STEPS = MAX_DUTY_CYCLE * 2;   // 510 steps
    // Calculate downcounter PERIOD to achieve desired wave frequency
    localparam int DOWNCOUNTER_PERIOD = integer'(CLOCK_FREQ / (WAVE_FREQ * TOTAL_STEPS));

    // Ensure DOWNCOUNTER_PERIOD is positive
    initial begin
        if (DOWNCOUNTER_PERIOD <= 0) begin
            $error("DOWNCOUNTER_PERIOD must be positive. Adjust CLOCK_FREQ or WAVE_FREQ.");
        end
    end

    // Internal signals
    logic zero;                   // Output from downcounter (enables duty_cycle update)
    logic [WIDTH-1:0] duty_cycle; // Duty cycle value for PWM
    logic dir;                    // Direction of duty_cycle counter: 1 = up, 0 = down
    
    assign R2R_out = duty_cycle; // R2R ladder resistor circuit automatically generates the analog voltage

    // Instantiate downcounter module
    downcounter #(
        .PERIOD(DOWNCOUNTER_PERIOD)  // Set downcounter period based on calculations
    ) downcounter_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),  // Use the enable input
        .zero(zero)       // Pulses high every DOWNCOUNTER_PERIOD clock cycles
    );

    // Duty cycle up/down counter logic
    always_ff @(posedge clk) begin
        if (reset) begin
            duty_cycle <= 0;    // Initialize duty_cycle to 0 on reset
            dir        <= 1; // Start counting up
        end else if (enable) begin
            if (zero) begin
                if (dir) begin
                    if (duty_cycle == MAX_DUTY_CYCLE) begin
                        dir        <= 0;           // Change direction to down
                        duty_cycle <= duty_cycle - 1;
                    end else begin
                        duty_cycle <= duty_cycle + 1; // Increment duty_cycle
                    end
                end else begin
                    if (duty_cycle == 0) begin
                        dir        <= 1;           // Change direction to up
                        duty_cycle <= duty_cycle + 1;
                    end else begin
                        duty_cycle <= duty_cycle - 1; // Decrement duty_cycle
                    end
                end
            end
        end else begin
            // Optionally reset duty_cycle and dir when enable is low
            duty_cycle <= 0;
            dir        <= 1; // Reset direction to up
        end
    end

    // Instantiate PWM module
    pwm #(
        .WIDTH(WIDTH)
    ) pwm_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),    // Use the enable input
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)   // Output PWM signal
    );

endmodule
