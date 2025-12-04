//******************************************************************************
// Module: edge_detector
//
// Description:
// Detects rising and falling edges of an input signal. The input signal is
// synchronized through two flip-flops to prevent metastability issues when
// crossing clock domains.
//
// Ports:
//   - clk: System clock
//   - reset: Active-high synchronous reset
//   - signal_in: Input signal to detect edges on (typically from external source)
//   - rising_edge: Output pulse (high for one clock cycle) on rising edge (0→1)
//   - falling_edge: Output pulse (high for one clock cycle) on falling edge (1→0)
//
// Operation:
//   1. Input signal is synchronized through two flip-flops (sync1, sync2)
//   2. Synchronized signal is delayed by one clock (signal_delayed)
//   3. Rising edge detected when: previous=0 AND current=1
//   4. Falling edge detected when: previous=1 AND current=0
//
// Example:
//   signal_in:       ────┐     ┌────────
//                        └─────┘
//
//   rising_edge:     ────┐─────────────
//                        └─────
//
//   falling_edge:    ──────────┐───────
//                              └───────
//
//******************************************************************************

module edge_detector (
    input  logic clk,
    input  logic reset,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);

    // Two-stage synchronizer to prevent metastability
    logic sync1, sync2;
    
    // Delayed version for edge comparison
    logic signal_delayed;
    
    // Synchronization chain
    always_ff @(posedge clk) begin
        if (reset) begin
            sync1          <= 1'b0;
            sync2          <= 1'b0;
            signal_delayed <= 1'b0;
        end else begin
            sync1          <= signal_in;        // First stage synchronization
            sync2          <= sync1;            // Second stage synchronization
            signal_delayed <= sync2;            // Delay for edge comparison
        end
    end
    
    // Edge detection combinational logic
    assign rising_edge  = !signal_delayed && sync2;   // 0→1 transition
    assign falling_edge = signal_delayed && !sync2;   // 1→0 transition

endmodule