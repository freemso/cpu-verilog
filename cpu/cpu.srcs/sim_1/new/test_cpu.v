`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Fudan 14 SS
// Engineer: Chengzu Ou
// 
// Create Date: 12/25/2016 04:03:49 AM
// Module Name: test_cpu
// Project Name: cpu
// 
// 
//////////////////////////////////////////////////////////////////////////////////


module test_cpu();

    reg clk, rst;
    
    cpu CPU(clk, rst);
    
    initial begin
        clk = 1'b0;
        rst = 1'b0;
        #1 rst = 1'b1;
        #1 rst = 1'b0;
    end

    always begin
        #1 clk = ~clk;
    end
    
endmodule
