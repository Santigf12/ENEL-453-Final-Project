`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: decimal_point_mux
// 
//////////////////////////////////////////////////////////////////////////////////


module decimal_point_mux( input logic [1:0] select, output logic [3:0] dp
    );
    
    always_comb begin
        case (select)
            2'b00: dp = 4'b0000; // averaged ADC with extra 4 bits
            2'b01: dp = 4'b0010; // averaged & scaled voltage (show DP)
            2'b10: dp = 4'b0000; // raw ADC (12 bits)
            2'b11: dp = 4'b0000;
            default: dp = 16'h0000; // safe default (note: 4 bits, not 16)
        endcase
    end
endmodule
