`timescale 1ns / 1ps

module rv32i_processor (
    input wire clk,
    input wire reset,

    // Architectural trace / commit interface
    output wire        trace_valid,
    output wire [31:0] trace_pc,
    output wire [31:0] trace_instruction,
    output wire [31:0] trace_next_pc,

    output wire        trace_reg_write,
    output wire [4:0]  trace_rd,
    output wire [31:0] trace_write_data,

    output wire        trace_mem_write,
    output wire [31:0] trace_mem_address,
    output wire [31:0] trace_mem_write_data
);

    // ------------------------------------------------
    // 1. PROGRAM COUNTER
    // ------------------------------------------------

    wire [31:0] PC;
    wire [31:0] next_PC;
    wire [31:0] PCPlus4;
    wire [31:0] instruction;

    assign PCPlus4 = PC + 32'd4;

    pc pc_inst (
        .clk(clk),
        .reset(reset),
        .next_PC(next_PC),
        .PC(PC)
    );

    // ------------------------------------------------
    // 2. INSTRUCTION MEMORY
    // ------------------------------------------------

    instruction_memory instruction_memory_inst (
        .address(PC),
        .instruction(instruction)
    );

    // ------------------------------------------------
    // 3. INSTRUCTION FIELD EXTRACTION
    // ------------------------------------------------

    wire [6:0] opcode;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];


    // ------------------------------------------------
    // 4. UNIFIED CONTROL / INSTRUCTION DECODER
    // ------------------------------------------------

    wire InstructionValid;

    wire       RegWrite;
    wire       ALUSrc;
    wire       MemRead;
    wire       MemWrite;
    wire       Branch;
    wire       Jump;

    wire [1:0] WBSelect;
    wire [2:0] ImmType;
    wire [1:0] ALUOp;

    control_unit control_unit_inst (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),

        .InstructionValid(InstructionValid),

        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .Branch(Branch),
        .Jump(Jump),

        .WBSelect(WBSelect),
        .ImmType(ImmType),
        .ALUOp(ALUOp)
    );

    // ------------------------------------------------
    // 5. REGISTER FILE
    // ------------------------------------------------

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] write_data;

    register_file register_file_inst (
        .clk(clk),
        .reset(reset),
        .RegWrite(RegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // ------------------------------------------------
    // 6. IMMEDIATE GENERATOR
    // ------------------------------------------------

    wire [31:0] immediate;

    immediate_generator immediate_generator_inst (
        .instruction(instruction),
        .ImmType(ImmType),
        .immediate(immediate)
    );

    // ------------------------------------------------
    // 7. ALU CONTROL
    // ------------------------------------------------

    wire [2:0] ALUControl;

    alu_control alu_control_inst (
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7(funct7),
        .ALUControl(ALUControl)
    );

    // ------------------------------------------------
    // 8. ALU
    // ------------------------------------------------

    wire [31:0] alu_B;
    wire [31:0] ALUResult;
    wire        Zero;
    wire        Equal;
    wire        addr_in_range;

    assign alu_B = ALUSrc ? immediate : read_data2;

    alu alu_inst (
        .A(read_data1),
        .B(alu_B),
        .ALUControl(ALUControl),
        .Result(ALUResult),
        .Zero(Zero),
        .Equal(Equal)
    );

    // ------------------------------------------------
    // 9. BRANCH CONTROL
    // ------------------------------------------------

    wire BranchTaken;

    branch_control branch_control_inst (
        .funct3(funct3),
        .Branch(Branch),
        .Zero(Equal),   // A==B (== SUB result zero for BEQ/BNE)
        .BranchTaken(BranchTaken)
    );

    // ------------------------------------------------
    // 10. DATA MEMORY
    // ------------------------------------------------

    wire [31:0] MemoryData;

    // ------------------------------------------------------------
    // Dedicated memory-address path (timing optimisation E1)
    //
    // LW/SW always use ALUOp=ADD and ALUSrc=1, so the effective address is
    // exactly  rs1 + immediate.  Feeding data_memory from this dedicated
    // sum removes two logic stages from the load/store path that the ALU
    // result needs but the address does not:
    //     * the ALUSrc mux (alu_B)
    //     * the ALU result-select mux (ADD/SUB/AND/OR/SLT/PASS)
    // Only address[9:2] is consumed by the 256-word memory, so only a
    // 10-bit adder is built; the range test works on the operands.
    // trace_mem_address still reports the full ALUResult (unchanged).
    // ------------------------------------------------------------
    wire [9:0]  mem_addr_lo = read_data1[9:0] + immediate[9:0];
    wire [31:0] mem_address = {22'b0, mem_addr_lo};

    // Carry-free in-window test on the adder operands (rs1 + immediate)
    addr_range_check #(.LOW_BITS(10)) addr_range_check_inst (
        .a(read_data1),
        .b(immediate),
        .in_range(addr_in_range)
    );

    data_memory #(
        .DEPTH(256),
        .HW_RESET_CLEAR(1)   // spec: warm reset must clear logical memory contents
    ) data_memory_inst (
        .clk(clk),
        .reset(reset),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(mem_address),
        .addr_in_range(addr_in_range),
        .write_data(read_data2),
        .read_data(MemoryData)
    );

    // ------------------------------------------------
    // 11. WRITEBACK MUX
    // ------------------------------------------------

    writeback_mux writeback_mux_inst (
        .ALUResult(ALUResult),
        .MemoryData(MemoryData),
        .PCPlus4(PCPlus4),
        .WBSelect(WBSelect),
        .WriteData(write_data)
    );

    // ------------------------------------------------
    // 12. NEXT PC LOGIC
    // ------------------------------------------------

    next_pc_logic next_pc_logic_inst (
        .PC(PC),
        .PCPlus4(PCPlus4),
        .Branch(Branch),
        .BranchTaken(BranchTaken),
        .Jump(Jump),
        .Immediate(immediate),
        .next_PC(next_PC)
    );


    // ------------------------------------------------
    // 15. TRACE / COMMIT INTERFACE
    // ------------------------------------------------

    assign trace_valid = InstructionValid;

    assign trace_pc = PC;
    assign trace_instruction = instruction;
    assign trace_next_pc = next_PC;

    // x0 cannot be architecturally written.
    assign trace_reg_write = RegWrite && (rd != 5'd0);

    assign trace_rd = rd;
    assign trace_write_data = write_data;

    assign trace_mem_write = MemWrite;
    assign trace_mem_address = ALUResult;
    assign trace_mem_write_data = read_data2;

`ifndef SYNTHESIS
    // Simulation-only guard: for LW/SW the dedicated address path must equal
    // the ALU result (word index) and the range flag must match the ALU sum.
    always @(posedge clk) begin
        if (!reset && (MemRead || MemWrite)) begin
            if (mem_address[9:2] !== ALUResult[9:2])
                $display("ERROR: mem_address/ALU mismatch t=%0t %h vs %h", $time, mem_address, ALUResult);
            if (addr_in_range !== (ALUResult[31:10] == 22'b0))
                $display("ERROR: addr_in_range mismatch t=%0t ALU=%h flag=%b", $time, ALUResult, addr_in_range);
        end
    end
`endif

endmodule
