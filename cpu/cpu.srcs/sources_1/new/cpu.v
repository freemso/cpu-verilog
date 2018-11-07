`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Fudan 14 SS
// Engineer: Chengzu Ou
// 
// Create Date: 12/22/2016 08:18:05 AM
// Module Name: cpu
// Project Name: cpu
// 
//////////////////////////////////////////////////////////////////////////////////


module cpu(
    input clk, rst
    );
    
    wire [31:0] inst, di, q1, q2, imm_32, sa, a, b, alu_out, mem_out, next;
    wire [5:0] op, func;
    wire [25:0] address;
    wire [4:0] rs, rt, rd, nd;
    wire [15:0] imm_16;
    wire [2:0] aluc;
    wire jump, m2reg, branch, wmem, shift, aluimm, wreg, regrt, sext;
    
    reg [31:0] pc;
    
    inst_mem INST_MEM(rst, pc, inst);
    
    assign op = inst[31:26];
    assign address = inst[25:0];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign func = inst[5:0];
    assign imm_16 = inst[15:0];
    
    control_unit CONTROL_UNIT(op, func, aluc, jump, m2reg, branch, wmem, shift, aluimm, wreg, regrt, sext);
    
    mux_5 MUX_5(regrt, rd, rt, nd);
    
    reg_file REG_FILE(rst, clk, wreg, rs, rt, nd, di, q1, q2);
    
    mux_32 MUX_32_1(shift, q1, sa, a);
    
    ext EXT(sext, imm_16, imm_32);
    
    mux_32 MUX_32_2(aluimm, q2, imm_32, b);
    
    alu ALU(aluc, a, b, alu_out);
    
    data_mem DATA_MEM(clk, rst, wmem, alu_out, q2, mem_out);
    
    mux_32 MUX_32_3(m2reg, alu_out, mem_out, di);
    
    next_pc NEXT_PC(branch, jump, clk, address, pc, imm_32, next);
    
    always @ (next) begin
        if (rst) pc = 0;
        else pc = next;
    end
    
    always @ (posedge rst) begin
        
    end
    
    always @ (posedge rst) begin
        // init pc
        pc = 0;
        
    end
    
endmodule

module inst_mem(
    input rst,
    input [31:0] pc,
    output [31:0] inst
    );
    
    reg [31:0] inst_mem [15:0];
    
    assign inst = inst_mem[pc];
    
    always @ (posedge rst) begin          //=> R[0]=0,R[15:1]=-1
        // addi, rs=0, rt=1, imm=1          => R[1]=1
        inst_mem[0 ] = {6'b001000,5'd0,5'd1,16'd1};
        // add, rs=0, rt=1, rd=2            => R[2]=1
        inst_mem[1 ] = {6'b000000,5'd0,5'd1,5'd2,5'd0,6'b100000};
        // sub, rs=0, rt=1, rd=3            => R[3]=-1
        inst_mem[2 ] = {6'b000000,5'd0,5'd1,5'd3,5'd0,6'b100010};
        // ori, rs=1, rt=4, imm=2           => R[4]=3
        inst_mem[3 ] = {6'b001101,5'd1,5'd4,16'd2};
        // andi, rs=1, rt=5, imm=1          => R[5]=1
        inst_mem[4 ] = {6'b001100,5'd1,5'd5,16'd1};
        // or, rs=1, rt=4, rd=6             => R[6]=3
        inst_mem[5 ] = {6'b000000,5'd1,5'd4,5'd6,5'd0,6'b100101};
        // and, rs=1, rt=4, rd=7            => R[7]=1
        inst_mem[6 ] = {6'b000000,5'd1,5'd4,5'd7,5'd0,6'b100100};
        // slt, rs=4, rt=1, rd=8            => R[8]=0
        inst_mem[7 ] = {6'b000000,5'd4,5'd1,5'd8,5'd0,6'b101010};
        // slti, rs=3, rt=9, imm=1          => R[9]=1
        inst_mem[8 ] = {6'b001010,5'd3,5'd9,16'd1};
        // sw, base=R[1], rt=4, offset=1    => Data[2]=3
        inst_mem[9 ] = {6'b101011,5'd1,5'd4,16'd1};
        // j, address=3 << 2=12
        inst_mem[10] = {6'b000010,26'd3};
        // add, rs=0, rt=1, rd=11           => R[11]=1 will not execute
        inst_mem[11] = {6'b000000,5'd0,5'd1,5'd11,5'd0,6'b100000};
        // lw, base=R[1], rt=10, offset=1   => R[10]=3
        inst_mem[12] = {6'b100011,5'd1,5'd10,16'd1};
        // nop * 3
        inst_mem[13] = {32'h00000000};
        inst_mem[14] = {32'h00000000};
        inst_mem[15] = {32'h00000000};
    end
    
endmodule

module control_unit(
    input [5:0] op,
    input [5:0] func,
    output reg [2:0] aluc,
    output reg jump, m2reg, branch, wmem, shift, aluimm, wreg, regrt, sext
    );
    
    reg add, sub, and_, or_, slt, addi, andi, ori, slti, sw, lw, j, nop;
    reg tmp1, tmp2, tmp3, tmp4;
    
    always @ (op or func) begin
        //R-type: op rs rt rd sa func
        // op: 000-000
        tmp1 = ~op[5]&~op[4]&~op[3]&~op[2]&~op[1]&~op[0];
        //   func: 100-xxx
        tmp2 = tmp1& func[5]&~func[4]&~func[3];
        add  = tmp2&~func[2]&~func[1]&~func[0]; // -000
        sub  = tmp2&~func[2]& func[1]&~func[0]; // -010
        and_ = tmp2& func[2]&~func[1]&~func[0]; // -100
        or_  = tmp2& func[2]&~func[1]& func[0]; // -101
        //   func: 101-010
        slt  = tmp1& func[5]&~func[4]& func[3]&~func[2]& func[1]&~func[0];
        
        //I-type: op rs rt imm
        // op: 001-xxx
        tmp3 = ~op[5]&~op[4]& op[3];
        addi = tmp3&~op[2]&~op[1]&~op[0]; // -000
        andi = tmp3& op[2]&~op[1]&~op[0]; // -100
        ori  = tmp3& op[2]&~op[1]& op[0]; // -101
        slti = tmp3&~op[2]& op[1]&~op[0]; // -010
        // op: xxx-011
        tmp4 = ~op[2]& op[1]& op[0];
        sw   = op[5]&~op[4]& op[3]&tmp4; // 101-
        lw   = op[5]&~op[4]&~op[3]&tmp4; // 101-
        
        //J-type: op target
        // op: 000-010
        j    = ~op[5]&~op[4]&~op[3]&~op[2]& op[1]&~op[0];
        
        // nop, all zero
        nop  = tmp1&~func[5]&~func[4]&~func[3]&~func[2]&~func[1]&~func[0];
        
        jump = j;
        m2reg = lw;
        branch = 0;
        wmem = sw;
        shift = 0;
        aluimm = addi|andi|ori|slti|sw|lw;
        wreg = add|sub|and_|or_|slt|addi|andi|ori|slti|lw;
        regrt = addi|andi|ori|slti|lw;
        sext = addi|slti;
        
        if (add | addi | lw | sw) aluc = 3'b001;
        else if (sub) aluc = 3'b010;
        else if (and_ | andi) aluc = 3'b011;
        else if (or_ | ori) aluc = 3'b100;
        else if (slt | slti) aluc = 3'b101;
        else aluc = 3'b000;
    end
    
endmodule

module reg_file(
    input rst, clk, we,
    input [4:0] n1, n2, nd,
    input [31:0] di,
    output reg [31:0] q1, q2
    );
    
    reg [31:0] regs [15:0];
    
    integer i;
    
    always @ (posedge clk) begin
        if (we) regs[nd] = di;
    end
    
    always @ (n1 or regs[n1]) begin
        q1 = regs[n1];
    end
    
    always @ (n2 or regs[n2]) begin
        q2 = regs[n2];
    end
    
    always @ (posedge rst) begin
        regs[0] = 32'h00000000;
        for (i = 1; i < 16; i = i + 1) begin
            regs[i] = 32'hffffffff;
        end
    end
    
endmodule

module ext(
    input sext,
    input [15:0] imm_16,
    output wire [31:0] imm_32
    );
    
    assign imm_32 = (sext && imm_16[15]) ? {16'hffff,imm_16} : {16'h0000,imm_16};
    
endmodule

module alu(
    input [2:0] aluc,
    input [31:0] a, b,
    output reg [31:0] out
    );
    
    always @ (aluc or a or b) begin
        case (aluc)
            3'b001: out = a + b;
            3'b010: out = a - b;
            3'b011: out = a & b;
            3'b100: out = a | b;
            3'b101: out = (a[31] == b[31]) ? (a < b) : (a[31] == 1'b1);
            default: out = 0;
        endcase
    end
    
endmodule

module data_mem(
    input clk, rst, we,
    input [31:0] address, write_data,
    output [31:0] read_data
    );
    
    reg [31:0] data [63:0];
    integer i;
    assign read_data = data[address];
    
    // init memory data
    always @ (posedge rst) begin
        for (i = 0; i < 64; i = i + 1) begin
            data[i] = 32'h00000000;
        end
    end
    
    always @ (negedge clk) begin
        if (we) data[address] = write_data;
    end
    
endmodule

module next_pc(
    input branch, jump, clk,
    input [25:0] address,
    input [31:0] current_pc, imm_32,
    output reg [31:0] next
    );
    wire [25:0] temp0;
    wire [31:0] temp1, temp2, temp3, temp4, temp5, temp6;
    
    assign temp0 = address << 2;
    assign temp1 = current_pc + 1;
    assign temp2 = imm_32 << 2;
    assign temp3 = temp2 + temp1;
    assign temp4 = {temp1[31:28],temp0};
    
    mux_32 MUX1(branch, temp1, temp3, temp5);
    mux_32 MUX2(jump, temp5, temp4, temp6);
    
    always @ (posedge clk) begin
        if (temp6 > 32'd15) next = 32'd15;
        else next = temp6;
    end
    
endmodule

module mux_32(
    input en,
    input [31:0] a, b,
    output [31:0] out
    );
    
    assign out = (en == 0) ? a : b;
    
endmodule

module mux_5(
    input en,
    input [4:0] a, b,
    output [4:0] out
    );
    
    assign out = (en == 0) ? a : b;
    
endmodule