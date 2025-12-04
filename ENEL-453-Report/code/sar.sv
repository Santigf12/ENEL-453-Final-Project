`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sar_adc
// Description: Successive Approximation Register (SAR) ADC implementation
//              FIXED: Added input synchronization and robust counters
//////////////////////////////////////////////////////////////////////////////////

module sar_adc #(
    parameter WIDTH = 8,                    
    parameter SETTLE_CYCLES = 50000         // Default for PWM usage
)(
    input  logic                clk,
    input  logic                reset,
    input  logic                start,          
    input  logic                compare_in,   //Different comparators signals for r2r and pwm     
    output logic [WIDTH-1:0]    dac_out,      
    output logic [WIDTH-1:0]    adc_result,     
    output logic                conversion_done 
);

    // FSM State Definition
    typedef enum logic [2:0] {
        IDLE, INIT, WAIT_SETTLE, COMPARE, DECIDE, NEXT_BIT, DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Internal registers
    logic [WIDTH-1:0]   sar_reg;            
    logic [3:0]         bit_index;          
    logic [31:0]        settle_counter;     // 32-bit to support long delays
    logic               comp_result;        
    
    // Synchronizer signals
    logic comp_sync_1, comp_sync_2;

    // Output the current SAR register value to the DAC
    assign dac_out = sar_reg;
    
    // Double-flop synchronizer for asynchronous comparator input
    // This is critical for reliable state machine operation
    always_ff @(posedge clk) begin
        if (reset) begin
            comp_sync_1 <= 0;
            comp_sync_2 <= 0;
        end else begin
            comp_sync_1 <= compare_in;
            comp_sync_2 <= comp_sync_1;
        end
    end

    // State Register
    always_ff @(posedge clk) begin
        if (reset) current_state <= IDLE;
        else current_state <= next_state;
    end
    
    // Next State Logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE:        if (start) next_state = INIT;
            INIT:        next_state = WAIT_SETTLE;
            WAIT_SETTLE: if (settle_counter >= (SETTLE_CYCLES - 1)) next_state = COMPARE;
            COMPARE:     next_state = DECIDE;
            DECIDE:      if (bit_index > 0) next_state = NEXT_BIT;
                         else next_state = DONE;
            NEXT_BIT:    next_state = WAIT_SETTLE;
            DONE:        next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end
    
    // Datapath
    always_ff @(posedge clk) begin
        if (reset) begin
            sar_reg         <= '0;
            bit_index       <= WIDTH - 1;
            settle_counter  <= '0;
            comp_result     <= '0;
            adc_result      <= '0;
            conversion_done <= '0;
        end else begin
            conversion_done <= '0;
            
            case (current_state)
                IDLE: begin
                    settle_counter <= '0;
                    if (start) begin
                        sar_reg    <= '0;
                        bit_index  <= WIDTH - 1;
                    end
                end
                
                INIT: begin
                    sar_reg[WIDTH-1] <= 1'b1; // Set MSB
                    settle_counter   <= '0;
                end
                
                WAIT_SETTLE: begin
                    settle_counter <= settle_counter + 1;
                end
                
                COMPARE: begin
                    // Use synchronized input
                    comp_result <= comp_sync_2;
                end
                
                DECIDE: begin
                    // If Vin < Vdac (Comparator Low), Clear the bit
                    if (!comp_result) begin
                        sar_reg[bit_index] <= 1'b0;
                    end
                    // Move index down
                    if (bit_index > 0) bit_index <= bit_index - 1'b1;
                end
                
                NEXT_BIT: begin
                    // Set next bit to 1
                    sar_reg[bit_index] <= 1'b1;
                    settle_counter <= '0;
                end
                
                DONE: begin
                    adc_result      <= sar_reg;
                    conversion_done <= 1'b1;
                end
            endcase
        end
    end
endmodule