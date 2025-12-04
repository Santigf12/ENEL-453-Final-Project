    module saw_generator #(
    parameter int WIDTH         = 8,
    parameter int CLOCK_FREQ    = 100_000_000,
    parameter int WAVE_FREQ_HZ  = 1          // integer Hz (use 1 for the lab)
) (
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 enable,
    output logic                 pwm_out,
    output logic [WIDTH-1:0]     R2R_out
);
    // 2^WIDTH steps per period → for WAVE_FREQ_HZ=1 Hz, we need 256 steps/sec
    localparam int STEPS  = (1 << WIDTH);                  // 256
    // clocks per step (rounded, never 0)
    localparam int DIV    = (CLOCK_FREQ + (STEPS*WAVE_FREQ_HZ)/2) / (STEPS*WAVE_FREQ_HZ);
    localparam int DIV_W  = (DIV <= 1) ? 1 : $clog2(DIV);

    logic [DIV_W-1:0] divcnt;
    logic             tick;

    // Step tick @ CLOCK_FREQ / DIV
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            divcnt <= '0;
            tick   <= 1'b0;
        end else if (!enable) begin
            divcnt <= '0;
            tick   <= 1'b0;
        end else if (divcnt == DIV-1) begin
            divcnt <= '0;
            tick   <= 1'b1;
        end else begin
            divcnt <= divcnt + 1'b1;
            tick   <= 1'b0;
        end
    end

    // Saw counter: 0..255 then wrap to 0
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            R2R_out <= '0;
        end else if (!enable) begin
            // OPTION A (recommended): restart from 0 next time
            R2R_out <= '0;
            // OPTION B: comment the line above to "pause" and resume where it left off
        end else if (tick) begin
            R2R_out <= R2R_out + 1'b1;  // wraps naturally at 255->0
        end
    end

    // 8-bit PWM whose duty follows the saw value
    pwm #(.WIDTH(WIDTH)) u_pwm (
        .clk(clk), .reset(reset),
        .enable(enable),
        .duty_cycle(R2R_out),
        .pwm_out(pwm_out)
    );
endmodule
