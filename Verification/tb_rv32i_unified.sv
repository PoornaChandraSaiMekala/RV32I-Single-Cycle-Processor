`timescale 1ns / 1ps

module tb_rv32i_unified;

    // =========================================================
    // 1. CLOCK, RESETS AND CONTROL
    // =========================================================

    reg clk;
    reg reset;
    reg coverage_reset;
    reg coverage_report_enable;

    wire coverage_error;

    integer total_errors;
    integer test_errors_before;
    integer x0_write_attempts;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // =========================================================
    // 2. DUT TRACE SIGNALS
    // =========================================================

    wire trace_valid;
    wire [31:0] trace_pc;
    wire [31:0] trace_instruction;
    wire [31:0] trace_next_pc;

    wire trace_reg_write;
    wire [4:0] trace_rd;
    wire [31:0] trace_write_data;

    wire trace_mem_write;
    wire [31:0] trace_mem_address;
    wire [31:0] trace_mem_write_data;


    // =========================================================
    // 3. REFERENCE MODEL SIGNALS
    // =========================================================

    wire model_valid;
    wire [31:0] model_pc;
    wire [31:0] model_instruction;
    wire [31:0] model_next_pc;

    wire model_reg_write;
    wire [4:0] model_rd;
    wire [31:0] model_write_data;

    wire model_mem_write;
    wire [31:0] model_mem_address;
    wire [31:0] model_mem_write_data;


    // =========================================================
    // 4. PROGRAM STORAGE
    // =========================================================

    reg [31:0] program_data [0:255];
    reg [10:0] t10_random_value;
    reg [10:0] t10_different_value;
    
    integer t10_errors_before;
    integer i;
    integer t12_i;
    integer t12_j;
    integer t12_error_count;
    integer t13_i;
    integer t13_start_errors;
    integer t15_rs2_before;
    
    reg [31:0] t12_register_snapshot [0:31];
    reg [31:0] t12_memory_snapshot [0:255];

    // =========================================================
    // 5. DUT
    // =========================================================

    rv32i_processor dut (
        .clk(clk),
        .reset(reset),

        .trace_valid(trace_valid),
        .trace_pc(trace_pc),
        .trace_instruction(trace_instruction),
        .trace_next_pc(trace_next_pc),

        .trace_reg_write(trace_reg_write),
        .trace_rd(trace_rd),
        .trace_write_data(trace_write_data),

        .trace_mem_write(trace_mem_write),
        .trace_mem_address(trace_mem_address),
        .trace_mem_write_data(trace_mem_write_data)
    );


    // =========================================================
    // 6. REFERENCE MODEL
    // =========================================================

    rv32i_reference_model #(
        .DEPTH(256)
    ) model (
        .clk(clk),
        .reset(reset),

        .model_valid(model_valid),
        .model_pc(model_pc),
        .model_instruction(model_instruction),
        .model_next_pc(model_next_pc),

        .model_reg_write(model_reg_write),
        .model_rd(model_rd),
        .model_write_data(model_write_data),

        .model_mem_write(model_mem_write),
        .model_mem_address(model_mem_address),
        .model_mem_write_data(model_mem_write_data)
    );


    // =========================================================
    // 7. PERSISTENT FUNCTIONAL COVERAGE MONITOR
    // =========================================================

    rv32i_functional_coverage coverage (

        .clk(clk),
        .reset(reset),
        .coverage_reset(coverage_reset),
        .report_enable(coverage_report_enable),

        .trace_valid(trace_valid),
        .trace_pc(trace_pc),
        .trace_instruction(trace_instruction),
        .trace_next_pc(trace_next_pc),

        .trace_reg_write(trace_reg_write),
        .trace_rd(trace_rd),
        .trace_write_data(trace_write_data),

        .trace_mem_write(trace_mem_write),
        .trace_mem_address(trace_mem_address),
        .trace_mem_write_data(trace_mem_write_data),

        .coverage_error(coverage_error)

    );

    // =====================================================
    // T08: INSTRUCTION ENCODING FUNCTIONS
    // =====================================================
    
    function [31:0] encode_addi;
        input [4:0] rd;
        input [4:0] rs1;
        input [11:0] imm;
        begin
            encode_addi = {
                imm, rs1, 3'b000, rd, 7'b0010011
            };
        end
    endfunction
    
    
    function [31:0] encode_rtype;
        input [4:0] rd;
        input [4:0] rs1;
        input [4:0] rs2;
        input [2:0] funct3;
        input [6:0] funct7;
        begin
            encode_rtype = {
                funct7, rs2, rs1, funct3, rd, 7'b0110011
            };
        end
    endfunction
    
    // =====================================================
    // T10: BRANCH INSTRUCTION ENCODER
    // =====================================================

    function [31:0] encode_branch;
        input [4:0] rs1;
        input [4:0] rs2;
        input [12:0] imm;
        input [2:0] funct3;
    
        begin
            encode_branch = {
                imm[12],
                imm[10:5],
                rs2,
                rs1,
                funct3,
                imm[4:1],
                imm[11],
                7'b1100011
            };
        end
    endfunction
      
    // =====================================================
    // T10: JAL INSTRUCTION ENCODER
    // =====================================================
    
    function [31:0] encode_jal;
        input [4:0] rd;
        input [20:0] imm;
    
        begin
            encode_jal = {
                imm[20],
                imm[10:1],
                imm[11],
                imm[19:12],
                rd,
                7'b1101111
            };
        end
    endfunction    
    
    function [31:0] xorshift32;
        input [31:0] x;
        reg [31:0] y;
        begin
            y = x;
            y = y ^ (y << 13);
            y = y ^ (y >> 17);
            y = y ^ (y << 5);
            xorshift32 = y;
        end
    endfunction 
    
    // =====================================================
    // T09: LOAD WORD ENCODING
    // =====================================================
    
    function [31:0] encode_lw;
        input [4:0] rd;
        input [4:0] rs1;
        input [11:0] imm;
        begin
            encode_lw = {
                imm,
                rs1,
                3'b010,
                rd,
                7'b0000011
            };
        end
    endfunction
    
    
    // =====================================================
    // T09: STORE WORD ENCODING
    // =====================================================
    
    function [31:0] encode_sw;
        input [4:0] rs2;
        input [4:0] rs1;
        input [11:0] imm;
        begin
            encode_sw = {
                imm[11:5],
                rs2,
                rs1,
                3'b010,
                imm[4:0],
                7'b0100011
            };
        end
    endfunction    
    
    // =========================================================
    // 8. PROGRAM INITIALIZATION TASK
    // =========================================================

    task automatic clear_program;

        integer j;

        begin

            for (j = 0; j < 256; j = j + 1)
                program_data[j] = 32'h00000013;

        end

    endtask


    // =========================================================
    // 9. LOAD PROGRAM INTO BOTH MEMORIES
    // =========================================================

    task automatic load_program;

        integer j;

        begin

            // CPU must remain in reset while loading.

            if (reset !== 1'b1) begin

                $display("ERROR: Attempted program load outside reset");
                total_errors = total_errors + 1;

            end

            for (j = 0; j < 256; j = j + 1) begin

                dut.instruction_memory_inst.memory[j] =
                    program_data[j];

                model.instruction_mem[j] =
                    program_data[j];

            end

        end

    endtask


    // =========================================================
    // 10. COMMON SCOREBOARD EXECUTION TASK
    // =========================================================

    task automatic run_test;

        input integer instruction_count;
        input [8*40-1:0] test_name;

        integer c;
        integer r;
        integer m;

        begin

            test_errors_before = total_errors;

            $display("");
            $display("==============================================");
            $display("STARTING TEST: %0s", test_name);
            $display("Expected commits: %0d", instruction_count);
            $display("==============================================");


            // -------------------------------------------------
            // RESET CPU AND REFERENCE MODEL
            // Coverage counters are NOT reset here.
            // -------------------------------------------------

            reset = 1'b1;

            repeat (2)
                @(posedge clk);

            @(negedge clk);

            reset = 1'b0;

            #1;


            // -------------------------------------------------
            // INSTRUCTION-BY-INSTRUCTION SCOREBOARD
            // -------------------------------------------------

            for (c = 0; c < instruction_count; c = c + 1) begin

                if (c != 0) begin

                    @(negedge clk);
                    #1;

                end


                // =============================================
                // PRE-COMMIT COMPARISONS
                // =============================================

                if (trace_valid !== model_valid) begin

                    $display(
                        "ERROR: %0s cycle %0d VALID mismatch",
                        test_name, c
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_valid !== 1'b1) begin

                    $display(
                        "ERROR: %0s cycle %0d invalid DUT trace",
                        test_name, c
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_pc !== model_pc) begin

                    $display(
                        "ERROR: %0s cycle %0d PC DUT=%h MODEL=%h",
                        test_name, c, trace_pc, model_pc
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_instruction !== model_instruction) begin

                    $display(
                        "ERROR: %0s cycle %0d INSTR DUT=%h MODEL=%h",
                        test_name, c,
                        trace_instruction, model_instruction
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_next_pc !== model_next_pc) begin

                    $display(
                        "ERROR: %0s cycle %0d NEXT_PC DUT=%h MODEL=%h",
                        test_name, c,
                        trace_next_pc, model_next_pc
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_reg_write !== model_reg_write) begin

                    $display(
                        "ERROR: %0s cycle %0d REG_WRITE mismatch",
                        test_name, c
                    );

                    total_errors = total_errors + 1;

                end


                if (trace_reg_write === 1'b1) begin

                    if (trace_rd !== model_rd) begin

                        $display(
                            "ERROR: %0s cycle %0d RD mismatch",
                            test_name, c
                        );

                        total_errors = total_errors + 1;

                    end


                    if (trace_write_data !== model_write_data) begin

                        $display(
                            "ERROR: %0s cycle %0d WRITE_DATA mismatch",
                            test_name, c
                        );

                        total_errors = total_errors + 1;

                    end

                end


                if (trace_mem_write !== model_mem_write) begin

                    $display(
                        "ERROR: %0s cycle %0d MEM_WRITE mismatch",
                        test_name, c
                    );

                    total_errors = total_errors + 1;

                end


                // Check effective address for LW and SW.

                if (
                    trace_instruction[6:0] == 7'b0000011 ||
                    trace_instruction[6:0] == 7'b0100011
                ) begin

                    if (trace_mem_address !== model_mem_address) begin

                        $display(
                            "ERROR: %0s cycle %0d MEM_ADDRESS mismatch",
                            test_name, c
                        );

                        total_errors = total_errors + 1;

                    end

                end


                if (trace_mem_write === 1'b1) begin

                    if (
                        trace_mem_write_data !==
                        model_mem_write_data
                    ) begin

                        $display(
                            "ERROR: %0s cycle %0d MEM_WRITE_DATA mismatch",
                            test_name, c
                        );

                        total_errors = total_errors + 1;

                    end

                end


                $display(
                    "%0s COMMIT %0d | PC=%h | INSTR=%h | NEXT_PC=%h",
                    test_name, c,
                    trace_pc,
                    trace_instruction,
                    trace_next_pc
                );
                // =============================================
                // RAW x0 WRITE-ATTEMPT VERIFICATION
                // =============================================
                
                if (
                    trace_valid === 1'b1 &&
                    trace_rd == 5'd0 &&
                    (
                        trace_instruction[6:0] == 7'b0110011 || // R-type
                        trace_instruction[6:0] == 7'b0010011 || // ADDI
                        trace_instruction[6:0] == 7'b0000011 || // LW
                        trace_instruction[6:0] == 7'b1101111 || // JAL
                        trace_instruction[6:0] == 7'b0110111    // LUI
                    )
                ) begin
                
                    if (dut.RegWrite !== 1'b1) begin
                
                        $display(
                            "ERROR: %0s cycle %0d expected raw RegWrite=1 for rd=x0",
                            test_name, c
                        );
                
                        total_errors = total_errors + 1;
                
                    end
                
                    if (dut.rd !== 5'd0) begin
                
                        $display(
                            "ERROR: %0s cycle %0d destination is not x0",
                            test_name, c
                        );
                
                        total_errors = total_errors + 1;
                
                    end
                
                    x0_write_attempts = x0_write_attempts + 1;
                
                end
                
                // =============================================
                // COMMIT INSTRUCTION
                // =============================================

                @(posedge clk);

                #1;


                // =============================================
                // COMPARE ALL 32 REGISTERS
                // =============================================

                for (r = 0; r < 32; r = r + 1) begin

                    if (
                        dut.register_file_inst.registers[r] !==
                        model.registers[r]
                    ) begin

                        $display(
                            "ERROR: %0s cycle %0d REGISTER x%0d DUT=%h MODEL=%h",
                            test_name,
                            c,
                            r,
                            dut.register_file_inst.registers[r],
                            model.registers[r]
                        );

                        total_errors = total_errors + 1;

                    end

                end


                // =============================================
                // COMPARE ALL 256 MEMORY LOCATIONS
                // =============================================

                for (m = 0; m < 256; m = m + 1) begin

                    if (
                        dut.data_memory_inst.memory[m] !==
                        model.data_mem[m]
                    ) begin

                        $display(
                            "ERROR: %0s cycle %0d MEMORY[%0d] DUT=%h MODEL=%h",
                            test_name,
                            c,
                            m,
                            dut.data_memory_inst.memory[m],
                            model.data_mem[m]
                        );

                        total_errors = total_errors + 1;

                    end

                end

            end


            // -------------------------------------------------
            // END CURRENT TEST
            // -------------------------------------------------


            #1;

            if (total_errors == test_errors_before) begin

                $display("");
                $display("PASS: %0s", test_name);
                $display("PASS: All instruction traces matched");
                $display("PASS: All registers matched");
                $display("PASS: All memory locations matched");

            end

            else begin

                $display("");
                $display("FAIL: %0s", test_name);

                $display(
                    "Errors in this test: %0d",
                    total_errors - test_errors_before
                );

            end

            $display("==============================================");

        end

    endtask

    // =====================================================
    // T08: PSEUDO-RANDOM ARITHMETIC TEST
    // =====================================================
    
    task automatic generate_random_arithmetic;
    
        integer j;
        integer idx;
        reg [31:0] seed;
    
        begin
    
            clear_program();
    
            idx = 0;
            seed = 32'hA5C39E71;
    
            // Initialize source registers.
            program_data[idx] = encode_addi(
                5'd1, 5'd0, 12'd123
            );
            idx = idx + 1;
    
            program_data[idx] = encode_addi(
                5'd2, 5'd0, 12'd456
            );
            idx = idx + 1;
    
            // 36 iterations, six of each R-type operation.
            for (j = 0; j < 36; j = j + 1) begin
    
                seed = xorshift32(seed);
    
                program_data[idx] = encode_addi(
                    5'd1, 5'd1, seed[11:0]
                );
                idx = idx + 1;
    
                seed = xorshift32(seed);
    
                program_data[idx] = encode_addi(
                    5'd2, 5'd2, seed[11:0]
                );
                idx = idx + 1;
    
                case (j / 6)
    
                    // ADD
                    0: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b000, 7'b0000000
                    );
    
                    // SUB
                    1: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b000, 7'b0100000
                    );
    
                    // AND
                    2: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b111, 7'b0000000
                    );
    
                    // OR
                    3: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b110, 7'b0000000
                    );
    
                    // SLT
                    4: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b010, 7'b0000000
                    );
    
                    // ADD again: sixth group is ADD
                    5: program_data[idx] = encode_rtype(
                        5'd3, 5'd1, 5'd2,
                        3'b000, 7'b0000000
                    );
    
                endcase
    
                idx = idx + 1;
    
            end
    
            $display("T08 generated instruction count = %0d", idx);
    
        end
    
    endtask

    // =====================================================
    // T09: PSEUDO-RANDOM MEMORY TEST GENERATOR
    // =====================================================
    
    task automatic generate_random_memory;
    
        integer j;
        integer idx;
        integer offset;
    
        reg [31:0] seed;
        reg [11:0] random_imm;
    
        begin
    
            clear_program();
    
            idx = 0;
            seed = 32'hB47E219D;
    
            // -------------------------------------------------
            // 1. Initialize base register x1 = 0
            // -------------------------------------------------
    
            program_data[idx] = encode_addi(
                5'd1, 5'd0, 12'd0
            );
            idx = idx + 1;
    
    
            // -------------------------------------------------
            // 2. Read untouched memory locations
            // -------------------------------------------------
    
            program_data[idx] = encode_lw(
                5'd10, 5'd1, 12'd0
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd11, 5'd1, 12'd4
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd12, 5'd1, 12'd64
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd13, 5'd1, 12'd256
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd14, 5'd1, 12'd512
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd15, 5'd1, 12'd768
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd16, 5'd1, 12'd1000
            );
            idx = idx + 1;
    
            program_data[idx] = encode_lw(
                5'd17, 5'd1, 12'd1020
            );
            idx = idx + 1;
    
    
            // -------------------------------------------------
            // 3. Pseudo-random store/load operations
            // -------------------------------------------------
    
            for (j = 0; j < 24; j = j + 1) begin
    
                // Generate pseudo-random data.
                seed = xorshift32(seed);
                random_imm = seed[11:0];
    
                // Force a known value at the highest address.
                if (j == 2)
                    random_imm = 12'h321;
    
    
                // Select addresses.
                case (j)
    
                    0: offset = 0;
                    1: offset = 4;
                    2: offset = 1020;
                    3: offset = 0;
    
                    default: begin
                        seed = xorshift32(seed);
    
                        // Word indexes 1 through 254.
                        // Byte addresses 4 through 1016.
                        offset = 4 * (1 + (seed[7:0] % 254));
                    end
    
                endcase
    
    
                // ---------------------------------------------
                // Generate data in x2
                // ---------------------------------------------
    
                program_data[idx] = encode_addi(
                    5'd2, 5'd0, random_imm
                );
                idx = idx + 1;
    
    
                // ---------------------------------------------
                // Store x2 into selected memory location
                // ---------------------------------------------
    
                program_data[idx] = encode_sw(
                    5'd2, 5'd1, offset[11:0]
                );
                idx = idx + 1;
    
    
                // ---------------------------------------------
                // Load the same location into rotating registers
                // ---------------------------------------------
    
                program_data[idx] = encode_lw(
                    5'd10 + (j % 8),
                    5'd1,
                    offset[11:0]
                );
                idx = idx + 1;
    
            end
    
    
            // -------------------------------------------------
            // 4. Directed overwrite and load-to-store dependency
            // -------------------------------------------------
    
            // x2 = 123
            program_data[idx] = encode_addi(
                5'd2, 5'd0, 12'd123
            );
            idx = idx + 1;
    
            // SW x2, 0(x1)
            program_data[idx] = encode_sw(
                5'd2, 5'd1, 12'd0
            );
            idx = idx + 1;
    
            // LW x3, 0(x1)
            program_data[idx] = encode_lw(
                5'd3, 5'd1, 12'd0
            );
            idx = idx + 1;
    
            // SW x3, 8(x1)
            program_data[idx] = encode_sw(
                5'd3, 5'd1, 12'd8
            );
            idx = idx + 1;
    
            // LW x4, 8(x1)
            program_data[idx] = encode_lw(
                5'd4, 5'd1, 12'd8
            );
            idx = idx + 1;
    
    
            $display("");
            $display("T09 generated instruction count = %0d", idx);
    
        end
    
    endtask

    // =====================================================
    // T10: RANDOMIZED CONTROL-FLOW PROGRAM
    // =====================================================
    
    task automatic generate_random_control_flow;
    
        reg [31:0] seed;
    
        begin
    
            clear_program();
    
            seed = 32'hC10F10A7;
    
            // Generate deterministic pseudo-random operands.
            seed = xorshift32(seed);
    
            t10_random_value = seed[10:0];
    
            // Guarantee that x3 differs from x1 and x2.
            t10_different_value =
                t10_random_value ^ 11'h155;
    
    
            // -------------------------------------------------
            // INITIALIZE OPERANDS
            // -------------------------------------------------
    
            // 0: ADDI x1,x0,random_value
            program_data[0] = encode_addi(
                5'd1, 5'd0, {1'b0, t10_random_value}
            );
    
            // 1: ADDI x2,x0,random_value
            program_data[1] = encode_addi(
                5'd2, 5'd0, {1'b0, t10_random_value}
            );
    
            // 2: BEQ x1,x2,+8
            // Taken: skip instruction 3.
            program_data[2] = encode_branch(
                5'd1, 5'd2, 13'd8, 3'b000
            );
    
            // 3: Poison instruction; must be skipped.
            program_data[3] = encode_addi(
                5'd20, 5'd0, 12'd99
            );
    
    
            // -------------------------------------------------
            // FORWARD BRANCHES
            // -------------------------------------------------
    
            // 4: BNE x1,x2,+8
            // Not taken because x1 == x2.
            program_data[4] = encode_branch(
                5'd1, 5'd2, 13'd8, 3'b001
            );
    
            // 5: ADDI x3,x0,different_value
            program_data[5] = encode_addi(
                5'd3, 5'd0, {1'b0, t10_different_value}
            );
    
            // 6: BNE x1,x3,+8
            // Taken because x1 != x3.
            program_data[6] = encode_branch(
                5'd1, 5'd3, 13'd8, 3'b001
            );
    
            // 7: Poison instruction; must be skipped.
            program_data[7] = encode_addi(
                5'd21, 5'd0, 12'd99
            );
    
            // 8: BEQ x1,x3,+8
            // Not taken.
            program_data[8] = encode_branch(
                5'd1, 5'd3, 13'd8, 3'b000
            );
    
    
            // -------------------------------------------------
            // BACKWARD BNE LOOP
            // -------------------------------------------------
    
            // 9: Initialize x4.
            program_data[9] = encode_addi(
                5'd4, 5'd0, 12'd2
            );
    
            // 10: Initialize loop counter x5 = 2.
            program_data[10] = encode_addi(
                5'd5, 5'd0, 12'd2
            );
    
            // 11: Decrement x5.
            program_data[11] = encode_addi(
                5'd5, 5'd5, -12'sd1
            );
    
            // 12: BNE x5,x0,-4
            // First execution: taken.
            // Second execution: not taken.
            program_data[12] = encode_branch(
                5'd5, 5'd0, -13'sd4, 3'b001
            );
    
    
            // -------------------------------------------------
            // FORWARD BEQ
            // -------------------------------------------------
    
            // 13: x6 = 0.
            program_data[13] = encode_addi(
                5'd6, 5'd0, 12'd0
            );
    
            // 14: BEQ x6,x0,+8
            // Taken.
            program_data[14] = encode_branch(
                5'd6, 5'd0, 13'd8, 3'b000
            );
    
            // 15: Poison instruction; must be skipped.
            program_data[15] = encode_addi(
                5'd22, 5'd0, 12'd99
            );
    
    
            // -------------------------------------------------
            // FORWARD JAL
            // -------------------------------------------------
    
            // 16: JAL x7,+8
            // Link address = 68.
            program_data[16] = encode_jal(
                5'd7, 21'd8
            );
    
            // 17: Poison instruction; must be skipped.
            program_data[17] = encode_addi(
                5'd23, 5'd0, 12'd99
            );
    
    
            // -------------------------------------------------
            // BACKWARD JAL LOOP
            // -------------------------------------------------
    
            // 18: x11 = 2.
            program_data[18] = encode_addi(
                5'd11, 5'd0, 12'd2
            );
    
            // 19: x10 = 0.
            program_data[19] = encode_addi(
                5'd10, 5'd0, 12'd0
            );
    
            // 20: Increment x10.
            program_data[20] = encode_addi(
                5'd10, 5'd10, 12'd1
            );
    
            // 21: BEQ x10,x11,+8
            // First execution: not taken.
            // Second execution: taken.
            program_data[21] = encode_branch(
                5'd10, 5'd11, 13'd8, 3'b000
            );
    
            // 22: JAL x12,-8
            // Backward jump to instruction 20.
            // Link address = 92.
            program_data[22] = encode_jal(
                5'd12, -21'sd8
            );
    
    
            // -------------------------------------------------
            // JAL WITH rd = x0
            // -------------------------------------------------
    
            // 23: JAL x0,+8
            // Must jump without changing x0.
            program_data[23] = encode_jal(
                5'd0, 21'd8
            );
    
            // 24: Poison instruction; must be skipped.
            program_data[24] = encode_addi(
                5'd24, 5'd0, 12'd99
            );
    
    
            // -------------------------------------------------
            // DEPENDENCY AFTER JAL
            // -------------------------------------------------
    
            // 25: ADDI x13,x12,0
            // Reads the JAL link value.
            program_data[25] = encode_addi(
                5'd13, 5'd12, 12'd0
            );
    
            // 26: ADDI x14,x13,1
            // RAW dependency on x13.
            program_data[26] = encode_addi(
                5'd14, 5'd13, 12'd1
            );
    
            // 27: BNE x13,x12,-4
            // Not taken because x13 == x12.
            program_data[27] = encode_branch(
                5'd13, 5'd12, -13'sd4, 3'b001
            );
    
    
            // -------------------------------------------------
            // FINAL INSTRUCTIONS
            // -------------------------------------------------
    
            // 28: ADDI x15,x0,42
            program_data[28] = encode_addi(
                5'd15, 5'd0, 12'd42
            );
    
            // 29: NOP
            program_data[29] = 32'h00000013;
    
    
            $display(
                "T10 generated program words = 30"
            );
    
            $display(
                "T10 random operand = %0d",
                t10_random_value
            );
    
            $display(
                "T10 different operand = %0d",
                t10_different_value
            );
    
        end
    
    endtask
    
    // =========================================================
    // 11. MAIN REGRESSION
    // =========================================================

    initial begin

        reset = 1'b1;
        coverage_reset = 1'b1;
        coverage_report_enable = 1'b0;

        total_errors = 0;

        clear_program();


        // -----------------------------------------------------
        // ONE-TIME COVERAGE RESET
        // -----------------------------------------------------

        @(posedge clk);

        #1;

        coverage_reset = 1'b0;


        // =====================================================
        // T01: REGISTER DEPENDENCY / LOAD-USE REGRESSION
        // =====================================================

        clear_program();

        program_data[0]  = 32'h00500093;
        program_data[1]  = 32'h00308113;
        program_data[2]  = 32'h001101b3;
        program_data[3]  = 32'h40218233;
        program_data[4]  = 32'h0011f2b3;
        program_data[5]  = 32'h0022e333;
        program_data[6]  = 32'h00602023;
        program_data[7]  = 32'h00002383;
        program_data[8]  = 32'h00138413;
        program_data[9]  = 32'h007404b3;
        program_data[10] = 32'hffd48093;
        program_data[11] = 32'h00908533;
        program_data[12] = 32'h06350013;
        program_data[13] = 32'h00a005b3;
        program_data[14] = 32'h00158613;
        program_data[15] = 32'h00b606b3;
        program_data[16] = 32'h00000013;

        load_program();

        run_test(17, "T01_REGISTER_DEPENDENCY");


        // -----------------------------------------------------
        // T01 DIRECTED CHECKS
        // -----------------------------------------------------

        if (dut.register_file_inst.registers[0] !== 32'd0)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[1] !== 32'd24)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[2] !== 32'd8)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[3] !== 32'd13)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[4] !== 32'd5)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[5] !== 32'd5)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[6] !== 32'd13)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[7] !== 32'd13)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[8] !== 32'd14)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[9] !== 32'd27)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[10] !== 32'd51)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[11] !== 32'd51)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[12] !== 32'd52)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[13] !== 32'd103)
            total_errors = total_errors + 1;

        if (dut.data_memory_inst.memory[0] !== 32'd13)
            total_errors = total_errors + 1;


        // =====================================================
        // T02: ARITHMETIC CORNER-CASE REGRESSION
        // =====================================================
        
        // Reset CPU and reference model before loading T02.
        // Coverage counters must remain untouched.
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        
        #1;
        
        clear_program();

        // ADDI x1,x0,2047
        program_data[0] = 32'h7ff00093;

        // ADDI x2,x0,-2048
        program_data[1] = 32'h80000113;

        // ADD x3,x1,x2
        program_data[2] = 32'h002081b3;

        // SUB x4,x1,x2
        program_data[3] = 32'h40208233;

        // SLT x5,x2,x1
        program_data[4] = 32'h001122b3;

        // SLT x6,x1,x2
        program_data[5] = 32'h0020a333;

        // ADDI x7,x0,-1
        program_data[6] = 32'hfff00393;

        // ADDI x8,x0,1
        program_data[7] = 32'h00100413;

        // ADD x9,x7,x8
        program_data[8] = 32'h008384b3;

        // SUB x10,x7,x8
        program_data[9] = 32'h40838533;

        // AND x11,x7,x8
        program_data[10] = 32'h0083f5b3;

        // OR x12,x7,x8
        program_data[11] = 32'h0083e633;

        // LUI x13,0x80000
        program_data[12] = 32'h800006b7;

        // ADDI x14,x13,-1
        program_data[13] = 32'hfff68713;

        // SLT x15,x13,x14
        program_data[14] = 32'h00e6a7b3;

        // SLT x16,x14,x13
        program_data[15] = 32'h00d72833;

        // ADDI x17,x0,0
        program_data[16] = 32'h00000893;

        // ADDI x18,x17,0
        program_data[17] = 32'h00088913;

        // SW x3,0(x0)
        program_data[18] = 32'h00302023;

        // LW x19,0(x0)
        program_data[19] = 32'h00002983;

        // NOP
        program_data[20] = 32'h00000013;

        load_program();

        run_test(21, "T02_ARITHMETIC_CORNER_CASES");


        // -----------------------------------------------------
        // T02 DIRECTED CHECKS
        // -----------------------------------------------------

        $display("");
        $display("T02 ARITHMETIC DIRECTED CHECKS");

        if (dut.register_file_inst.registers[1] !== 32'h000007ff)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[2] !== 32'hfffff800)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[3] !== 32'hffffffff)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[4] !== 32'h00000fff)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[5] !== 32'd1)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[6] !== 32'd0)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[9] !== 32'd0)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[10] !== 32'hfffffffe)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[11] !== 32'd1)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[12] !== 32'hffffffff)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[13] !== 32'h80000000)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[14] !== 32'h7fffffff)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[15] !== 32'd1)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[16] !== 32'd0)
            total_errors = total_errors + 1;

        if (dut.register_file_inst.registers[19] !== 32'hffffffff)
            total_errors = total_errors + 1;

        if (dut.data_memory_inst.memory[0] !== 32'hffffffff)
            total_errors = total_errors + 1;

        // =====================================================
        // T03: SLT SIGNED BOUNDARY CASES
        // =====================================================
        
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        clear_program();
        
        // 0: x1 = 0x80000000 (minimum signed integer)
        program_data[0]  = 32'h800000b7; // LUI x1, 0x80000
        
        // 1: x2 = -1
        program_data[1]  = 32'hfff00113; // ADDI x2, x0, -1
        
        // 2: minimum integer < -1 : TRUE
        program_data[2]  = 32'h0020a1b3; // SLT x3, x1, x2
        
        // 3: -1 < minimum integer : FALSE
        program_data[3]  = 32'h00112233; // SLT x4, x2, x1
        
        // 4: x5 = 0x80000000
        program_data[4]  = 32'h800002b7; // LUI x5, 0x80000
        
        // 5: x5 = 0x7FFFFFFF
        program_data[5]  = 32'hfff28293; // ADDI x5, x5, -1
        
        // 6: minimum integer < maximum integer : TRUE
        program_data[6]  = 32'h0050a333; // SLT x6, x1, x5
        
        // 7: maximum integer < minimum integer : FALSE
        program_data[7]  = 32'h0012a3b3; // SLT x7, x5, x1
        
        // 8: x8 = 0
        program_data[8]  = 32'h00000413; // ADDI x8, x0, 0
        
        // 9: 0 < 0 : FALSE
        program_data[9]  = 32'h008424b3; // SLT x9, x8, x8
        
        // 10: 0 < -1 : FALSE
        program_data[10] = 32'h00242533; // SLT x10, x8, x2
        
        // 11: -1 < 0 : TRUE
        program_data[11] = 32'h008125b3; // SLT x11, x2, x8
        
        // 12: x12 = 1
        program_data[12] = 32'h00100613; // ADDI x12, x0, 1
        
        // 13: 0 < 1 : TRUE
        program_data[13] = 32'h00c426b3; // SLT x13, x8, x12
        
        // 14: 1 < 0 : FALSE
        program_data[14] = 32'h00862733; // SLT x14, x12, x8
        
        // 15: -1 < -1 : FALSE
        program_data[15] = 32'h002127b3; // SLT x15, x2, x2
        
        load_program();
        
        run_test(16, "T03_SLT_SIGNED_BOUNDARY_CASES");
        $display("");
        $display("T03 SLT SIGNED BOUNDARY DIRECTED CHECKS");
        
        // Minimum signed integer
        if (dut.register_file_inst.registers[1] !== 32'h80000000) begin
            $display("FAIL: x1 expected 80000000");
            total_errors = total_errors + 1;
        end
        
        // Negative one
        if (dut.register_file_inst.registers[2] !== 32'hffffffff) begin
            $display("FAIL: x2 expected ffffffff");
            total_errors = total_errors + 1;
        end
        
        // Minimum < -1
        if (dut.register_file_inst.registers[3] !== 32'h00000001) begin
            $display("FAIL: x3 expected 1");
            total_errors = total_errors + 1;
        end
        
        // -1 < minimum
        if (dut.register_file_inst.registers[4] !== 32'h00000000) begin
            $display("FAIL: x4 expected 0");
            total_errors = total_errors + 1;
        end
        
        // Maximum signed integer
        if (dut.register_file_inst.registers[5] !== 32'h7fffffff) begin
            $display("FAIL: x5 expected 7fffffff");
            total_errors = total_errors + 1;
        end
        
        // Minimum < maximum
        if (dut.register_file_inst.registers[6] !== 32'h00000001) begin
            $display("FAIL: x6 expected 1");
            total_errors = total_errors + 1;
        end
        
        // Maximum < minimum
        if (dut.register_file_inst.registers[7] !== 32'h00000000) begin
            $display("FAIL: x7 expected 0");
            total_errors = total_errors + 1;
        end
        
        // Zero
        if (dut.register_file_inst.registers[8] !== 32'h00000000) begin
            $display("FAIL: x8 expected 0");
            total_errors = total_errors + 1;
        end
        
        // 0 < 0
        if (dut.register_file_inst.registers[9] !== 32'h00000000) begin
            $display("FAIL: x9 expected 0");
            total_errors = total_errors + 1;
        end
        
        // 0 < -1
        if (dut.register_file_inst.registers[10] !== 32'h00000000) begin
            $display("FAIL: x10 expected 0");
            total_errors = total_errors + 1;
        end
        
        // -1 < 0
        if (dut.register_file_inst.registers[11] !== 32'h00000001) begin
            $display("FAIL: x11 expected 1");
            total_errors = total_errors + 1;
        end
        
        // Positive one
        if (dut.register_file_inst.registers[12] !== 32'h00000001) begin
            $display("FAIL: x12 expected 1");
            total_errors = total_errors + 1;
        end
        
        // 0 < 1
        if (dut.register_file_inst.registers[13] !== 32'h00000001) begin
            $display("FAIL: x13 expected 1");
            total_errors = total_errors + 1;
        end
        
        // 1 < 0
        if (dut.register_file_inst.registers[14] !== 32'h00000000) begin
            $display("FAIL: x14 expected 0");
            total_errors = total_errors + 1;
        end
        
        // -1 < -1
        if (dut.register_file_inst.registers[15] !== 32'h00000000) begin
            $display("FAIL: x15 expected 0");
            total_errors = total_errors + 1;
        end
        
        $display("T03 SLT DIRECTED CHECKS COMPLETED");        
        // =====================================================
        // T04: MULTI-ADDRESS MEMORY TEST
        // =====================================================
        
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        clear_program();
        
        // Initialize base address and data
        program_data[0] = 32'h01000093; // ADDI x1, x0, 16
        program_data[1] = 32'h05500113; // ADDI x2, x0, 85
        program_data[2] = 32'h02a00193; // ADDI x3, x0, 42
        
        // Store at two different addresses
        program_data[3] = 32'h0020a023; // SW x2, 0(x1)
        program_data[4] = 32'h0030a223; // SW x3, 4(x1)
        
        // Load from both addresses
        program_data[5] = 32'h0000a203; // LW x4, 0(x1)
        program_data[6] = 32'h0040a283; // LW x5, 4(x1)
        
        // Overwrite first memory location
        program_data[7] = 32'h07f00113; // ADDI x2, x0, 127
        program_data[8] = 32'h0020a023; // SW x2, 0(x1)
        
        // Read overwritten value
        program_data[9] = 32'h0000a303; // LW x6, 0(x1)
        
        load_program();
        
        run_test(10, "T04_MULTI_ADDRESS_MEMORY");
        $display("");
        $display("T04 MULTI-ADDRESS MEMORY DIRECTED CHECKS");
        
        // Register checks
        if (dut.register_file_inst.registers[4] !== 32'h00000055) begin
            $display("FAIL: x4 expected 00000055");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[5] !== 32'h0000002a) begin
            $display("FAIL: x5 expected 0000002a");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[6] !== 32'h0000007f) begin
            $display("FAIL: x6 expected 0000007f");
            total_errors = total_errors + 1;
        end
        
        // Memory checks
        if (dut.data_memory_inst.memory[4] !== 32'h0000007f) begin
            $display("FAIL: Memory[4] expected 0000007f");
            total_errors = total_errors + 1;
        end
        
        if (dut.data_memory_inst.memory[5] !== 32'h0000002a) begin
            $display("FAIL: Memory[5] expected 0000002a");
            total_errors = total_errors + 1;
        end
        
        $display("T04 MEMORY DIRECTED CHECKS COMPLETED");
        
        // =====================================================
        // T05: BEQ CORNER CASES
        // =====================================================
        
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        clear_program();
        
        // -----------------------------------------------------
        // Forward BEQ: equal positive operands (TAKEN)
        // -----------------------------------------------------
        program_data[0]  = 32'h00500093; // ADDI x1, x0, 5
        program_data[1]  = 32'h00500113; // ADDI x2, x0, 5
        program_data[2]  = 32'h00208463; // BEQ x1, x2, +8 (TAKEN)
        program_data[3]  = 32'h06300513; // ADDI x10, x0, 99 (SKIPPED)
        
        // -----------------------------------------------------
        // Forward BEQ: unequal operands (NOT TAKEN)
        // -----------------------------------------------------
        program_data[4]  = 32'h00100193; // ADDI x3, x0, 1
        program_data[5]  = 32'h00200213; // ADDI x4, x0, 2
        program_data[6]  = 32'h00418463; // BEQ x3, x4, +8 (NOT TAKEN)
        program_data[7]  = 32'h05800513; // ADDI x10, x0, 88 (SKIPPED)
        
        // -----------------------------------------------------
        // Forward BEQ: equal negative operands (TAKEN)
        // -----------------------------------------------------
        program_data[8]  = 32'hffd00293; // ADDI x5, x0, -3
        program_data[9]  = 32'hffd00313; // ADDI x6, x0, -3
        program_data[10] = 32'h00628463; // BEQ x5, x6, +8 (TAKEN)
        program_data[11] = 32'h04d00513; // ADDI x10, x0, 77 (SKIPPED)
        
        // -----------------------------------------------------
        // Forward BEQ: equal zero operands (TAKEN)
        // -----------------------------------------------------
        program_data[12] = 32'h00000393; // ADDI x7, x0, 0
        program_data[13] = 32'h00000413; // ADDI x8, x0, 0
        program_data[14] = 32'h00838463; // BEQ x7, x8, +8 (TAKEN)
        program_data[15] = 32'h04200513; // ADDI x10, x0, 66 (SKIPPED)
        
        // -----------------------------------------------------
        // Backward BEQ: taken once, then not taken
        // -----------------------------------------------------
        program_data[16] = 32'h00000513; // ADDI x10, x0, 0
        program_data[17] = 32'h00150513; // ADDI x10, x10, 1
        program_data[18] = 32'h00200593; // ADDI x11, x0, 2
        program_data[19] = 32'h00150513; // ADDI x10, x10, 1
        program_data[20] = 32'hfeb50ee3; // BEQ x10, x11, -4
        
        // Final instruction
        program_data[21] = 32'h06300613; // ADDI x12, x0, 99
        
        load_program();
        
        run_test(21, "T05_BEQ_CORNER_CASES"); 
        $display("");
        $display("T05 BEQ DIRECTED CHECKS");
        
        // Equal positive operands
        if (dut.register_file_inst.registers[1] !== 32'd5)
            total_errors = total_errors + 1;
        
        if (dut.register_file_inst.registers[2] !== 32'd5)
            total_errors = total_errors + 1;
        
        // Unequal operands
        if (dut.register_file_inst.registers[3] !== 32'd1)
            total_errors = total_errors + 1;
        
        if (dut.register_file_inst.registers[4] !== 32'd2)
            total_errors = total_errors + 1;
        
        // Equal negative operands
        if (dut.register_file_inst.registers[5] !== 32'hfffffffd)
            total_errors = total_errors + 1;
        
        if (dut.register_file_inst.registers[6] !== 32'hfffffffd)
            total_errors = total_errors + 1;
        
        // Equal zero operands
        if (dut.register_file_inst.registers[7] !== 32'd0)
            total_errors = total_errors + 1;
        
        if (dut.register_file_inst.registers[8] !== 32'd0)
            total_errors = total_errors + 1;
        
        // All skipped instructions must leave x9 unchanged
        if (dut.register_file_inst.registers[9] !== 32'd0) begin
            $display("FAIL: x9 changed unexpectedly");
            total_errors = total_errors + 1;
        end
        
        // Backward branch loop result
        if (dut.register_file_inst.registers[10] !== 32'd3) begin
            $display("FAIL: x10 expected 3, got %h",
                     dut.register_file_inst.registers[10]);
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[11] !== 32'd2)
            total_errors = total_errors + 1;
        
        // Final instruction after backward branch
        if (dut.register_file_inst.registers[12] !== 32'd99) begin
            $display("FAIL: x12 expected 99");
            total_errors = total_errors + 1;
        end
        
        if (total_errors == 0)
            $display("PASS: T05 BEQ directed checks");
        
        $display("T05 BEQ DIRECTED CHECKS COMPLETED");        

        // =====================================================
        // T06: JAL CORNER CASES - CORRECTED
        // =====================================================
        
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        clear_program();
        
        // Forward JAL with rd=x5
        program_data[0]  = 32'h00500093; // ADDI x1, x0, 5
        program_data[1]  = 32'h008002ef; // JAL x5, +8
        program_data[2]  = 32'h06300513; // ADDI x10, x0, 99 (SKIPPED)
        program_data[3]  = 32'h00700113; // ADDI x2, x0, 7
        
        // Forward JAL with rd=x0
        program_data[4]  = 32'h0080006f; // JAL x0, +8
        program_data[5]  = 32'h05800593; // ADDI x11, x0, 88 (SKIPPED)
        program_data[6]  = 32'h00900193; // ADDI x3, x0, 9
        
        // Initialize loop variables OUTSIDE the loop
        program_data[7]  = 32'h00000213; // ADDI x4, x0, 0
        program_data[8]  = 32'h00200313; // ADDI x6, x0, 2
        
        // Loop begins here: PC = 0x24
        program_data[9]  = 32'h00120213; // ADDI x4, x4, 1
        
        // Exit when x4 == x6
        program_data[10] = 32'h00620463; // BEQ x4, x6, +8
        
        // Backward JAL: jump from 0x2C to 0x24
        program_data[11] = 32'hff9ff3ef; // JAL x7, -8
        
        // Final instruction after loop
        program_data[12] = 32'h03700413; // ADDI x8, x0, 55
        
        load_program();
        
        run_test(13, "T06_JAL_CORNER_CASES");
        $display("");
        $display("T06 JAL DIRECTED CHECKS");
        
        // Initial register
        if (dut.register_file_inst.registers[1] !== 32'd5) begin
            $display("FAIL: x1 expected 5");
            total_errors = total_errors + 1;
        end
        
        // Forward JAL destination and return address
        if (dut.register_file_inst.registers[5] !== 32'h00000008) begin
            $display("FAIL: x5 expected 00000008, got %h",
                     dut.register_file_inst.registers[5]);
            total_errors = total_errors + 1;
        end
        
        // Instruction after forward JAL
        if (dut.register_file_inst.registers[2] !== 32'd7) begin
            $display("FAIL: x2 expected 7");
            total_errors = total_errors + 1;
        end
        
        // JAL rd=x0 must not write return address
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
            $display("FAIL: x0 changed unexpectedly");
            total_errors = total_errors + 1;
        end
        
        // Skipped instruction checks
        if (dut.register_file_inst.registers[10] !== 32'd0) begin
            $display("FAIL: x10 should remain zero");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[11] !== 32'd0) begin
            $display("FAIL: x11 should remain zero");
            total_errors = total_errors + 1;
        end
        
        // Instruction after second forward jump
        if (dut.register_file_inst.registers[3] !== 32'd9) begin
            $display("FAIL: x3 expected 9");
            total_errors = total_errors + 1;
        end
        
        // Backward JAL loop result
        if (dut.register_file_inst.registers[4] !== 32'd2) begin
            $display("FAIL: x4 expected 2");
            total_errors = total_errors + 1;
        end
        
        // Backward JAL return address
        if (dut.register_file_inst.registers[7] !== 32'h00000030) begin
            $display("FAIL: x7 expected 00000030, got %h",
                     dut.register_file_inst.registers[7]);
            total_errors = total_errors + 1;
        end
        
        // Loop exit instruction
        if (dut.register_file_inst.registers[8] !== 32'd55) begin
            $display("FAIL: x8 expected 55");
            total_errors = total_errors + 1;
        end
        
        if (total_errors == 0)
            $display("PASS: T06 JAL directed checks");
        
        $display("T06 JAL DIRECTED CHECKS COMPLETED");                                       
        
        // =====================================================
        // T07: BNE CORNER CASES
        // =====================================================
        
        reset = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        clear_program();
        
        // -----------------------------------------------------
        // Forward BNE: unequal positive operands (TAKEN)
        // -----------------------------------------------------
        
        program_data[0]  = 32'h00500093; // ADDI x1, x0, 5
        program_data[1]  = 32'h00300113; // ADDI x2, x0, 3
        program_data[2]  = 32'h00209463; // BNE x1, x2, +8 (TAKEN)
        program_data[3]  = 32'h06300693; // ADDI x13, x0, 99 (SKIPPED)
        
        // -----------------------------------------------------
        // Forward BNE: equal operands (NOT TAKEN)
        // -----------------------------------------------------
        
        program_data[4]  = 32'h00700193; // ADDI x3, x0, 7
        program_data[5]  = 32'h00700213; // ADDI x4, x0, 7
        program_data[6]  = 32'h00419463; // BNE x3, x4, +8 (NOT TAKEN)
        
        // -----------------------------------------------------
        // Forward BNE: unequal negative operands (TAKEN)
        // -----------------------------------------------------
        
        program_data[7]  = 32'hffd00293; // ADDI x5, x0, -3
        program_data[8]  = 32'hffe00313; // ADDI x6, x0, -2
        program_data[9]  = 32'h00629463; // BNE x5, x6, +8 (TAKEN)
        program_data[10] = 32'h05800713; // ADDI x14, x0, 88 (SKIPPED)
        
        // -----------------------------------------------------
        // Forward BNE: zero versus nonzero (TAKEN)
        // -----------------------------------------------------
        
        program_data[11] = 32'h00000393; // ADDI x7, x0, 0
        program_data[12] = 32'h00100413; // ADDI x8, x0, 1
        program_data[13] = 32'h00839463; // BNE x7, x8, +8 (TAKEN)
        program_data[14] = 32'h04200793; // ADDI x15, x0, 66 (SKIPPED)
        
        // -----------------------------------------------------
        // Initialize backward branch loop OUTSIDE the loop
        // -----------------------------------------------------
        
        program_data[15] = 32'h00000493; // ADDI x9, x0, 0
        program_data[16] = 32'h00200593; // ADDI x11, x0, 2
        
        // -----------------------------------------------------
        // Loop starts at PC = 0x44
        // -----------------------------------------------------
        
        program_data[17] = 32'h00148493; // ADDI x9, x9, 1
        
        // BNE x9, x11, -4
        // First execution: x9=1, x11=2 -> TAKEN
        // Second execution: x9=2, x11=2 -> NOT TAKEN
        
        program_data[18] = 32'hfeb49ee3; // BNE x9, x11, -4
        
        // -----------------------------------------------------
        // Final instruction after loop
        // -----------------------------------------------------
        
        program_data[19] = 32'h06300613; // ADDI x12, x0, 99
        
        load_program();
        
        run_test(19, "T07_BNE_CORNER_CASES");
        $display("");
        $display("T07 BNE DIRECTED CHECKS");
        
        // Positive operands
        if (dut.register_file_inst.registers[1] !== 32'd5) begin
            $display("FAIL: x1 expected 5");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[2] !== 32'd3) begin
            $display("FAIL: x2 expected 3");
            total_errors = total_errors + 1;
        end
        
        // Equal operands
        if (dut.register_file_inst.registers[3] !== 32'd7) begin
            $display("FAIL: x3 expected 7");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[4] !== 32'd7) begin
            $display("FAIL: x4 expected 7");
            total_errors = total_errors + 1;
        end
        
        // Negative operands
        if (dut.register_file_inst.registers[5] !== 32'hfffffffd) begin
            $display("FAIL: x5 expected fffffffd");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[6] !== 32'hfffffffe) begin
            $display("FAIL: x6 expected fffffffe");
            total_errors = total_errors + 1;
        end
        
        // Zero and nonzero operands
        if (dut.register_file_inst.registers[7] !== 32'd0) begin
            $display("FAIL: x7 expected 0");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[8] !== 32'd1) begin
            $display("FAIL: x8 expected 1");
            total_errors = total_errors + 1;
        end
        
        // Backward loop
        if (dut.register_file_inst.registers[9] !== 32'd2) begin
            $display("FAIL: x9 expected 2, got %h",
                     dut.register_file_inst.registers[9]);
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[11] !== 32'd2) begin
            $display("FAIL: x11 expected 2");
            total_errors = total_errors + 1;
        end
        
        // Skipped instruction checks
        if (dut.register_file_inst.registers[13] !== 32'd0) begin
            $display("FAIL: x13 should remain zero");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[14] !== 32'd0) begin
            $display("FAIL: x14 should remain zero");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[15] !== 32'd0) begin
            $display("FAIL: x15 should remain zero");
            total_errors = total_errors + 1;
        end
        
        // Final instruction
        if (dut.register_file_inst.registers[12] !== 32'd99) begin
            $display("FAIL: x12 expected 99, got %h",
                     dut.register_file_inst.registers[12]);
            total_errors = total_errors + 1;
        end
        
        if (total_errors == 0)
            $display("PASS: T07 BNE directed checks");
        
        $display("T07 BNE DIRECTED CHECKS COMPLETED");        
        
        // =====================================================
        // T08: PSEUDO-RANDOM ARITHMETIC
        // =====================================================
        
        reset = 1'b1;
        
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1;
        
        generate_random_arithmetic();
        
        load_program();
        
        run_test(110, "T08_RANDOM_ARITHMETIC");
        
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
            $display("FAIL: T08 x0 is not zero");
            total_errors = total_errors + 1;
        end
        
        $display("T08 RANDOM ARITHMETIC DIRECTED CHECKS COMPLETED");       
        // =====================================================
        // T09: PSEUDO-RANDOM MEMORY REGRESSION
        // =====================================================
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        #1;
        
        generate_random_memory();
        
        load_program();
        
        run_test(86, "T09_RANDOM_MEMORY");
        
        
        // -----------------------------------------------------
        // T09 DIRECTED CHECKS
        // -----------------------------------------------------
        
        $display("");
        $display("T09 RANDOM MEMORY DIRECTED CHECKS");
        
        // x0 must remain zero.
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
            $display("FAIL: T09 x0 changed");
            total_errors = total_errors + 1;
        end
        
        // Final overwrite at memory address 0.
        if (dut.data_memory_inst.memory[0] !== 32'd123) begin
            $display("FAIL: Memory[0] expected 123, got %h",
                     dut.data_memory_inst.memory[0]);
            total_errors = total_errors + 1;
        end
        
        // Load-to-store dependency result at address 8.
        if (dut.data_memory_inst.memory[2] !== 32'd123) begin
            $display("FAIL: Memory[2] expected 123, got %h",
                     dut.data_memory_inst.memory[2]);
            total_errors = total_errors + 1;
        end
        
        // Highest valid word address: 0x3FC.
        if (dut.data_memory_inst.memory[255] !== 32'h00000321) begin
            $display("FAIL: Memory[255] expected 00000321, got %h",
                     dut.data_memory_inst.memory[255]);
            total_errors = total_errors + 1;
        end
        
        // Final load result.
        if (dut.register_file_inst.registers[3] !== 32'd123) begin
            $display("FAIL: x3 expected 123");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[4] !== 32'd123) begin
            $display("FAIL: x4 expected 123");
            total_errors = total_errors + 1;
        end
        
        if (total_errors == 0)
            $display("PASS: T09 directed memory checks");
        
        $display("T09 RANDOM MEMORY DIRECTED CHECKS COMPLETED");                
        // =====================================================
        // T10: RANDOMIZED CONTROL-FLOW REGRESSION
        // =====================================================
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        
        #1;
        
        generate_random_control_flow();
        
        load_program();
        
        t10_errors_before = total_errors;
        
        // Expected executed instruction count = 29.
        run_test(29, "T10_RANDOM_CONTROL_FLOW");
        
        
        // =====================================================
        // T10 DIRECTED CHECKS
        // =====================================================
        
        $display("");
        $display("T10 RANDOMIZED CONTROL-FLOW DIRECTED CHECKS");
        
        
        // -----------------------------------------------------
        // RANDOMIZED OPERAND CHECKS
        // -----------------------------------------------------
        
        if (
            dut.register_file_inst.registers[1] !==
            dut.register_file_inst.registers[2]
        ) begin
            $display("FAIL: x1 and x2 should be equal");
            total_errors = total_errors + 1;
        end
        
        if (
            dut.register_file_inst.registers[1] ===
            dut.register_file_inst.registers[3]
        ) begin
            $display("FAIL: x1 and x3 should differ");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // BACKWARD BNE LOOP
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[5] !== 32'd0) begin
            $display("FAIL: x5 expected 0");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // FORWARD JAL
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[7] !== 32'd68) begin
            $display(
                "FAIL: x7 expected 68, got %0d",
                dut.register_file_inst.registers[7]
            );
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // BACKWARD JAL
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[12] !== 32'd92) begin
            $display(
                "FAIL: x12 expected 92, got %0d",
                dut.register_file_inst.registers[12]
            );
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // LOOP RESULT
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[10] !== 32'd2) begin
            $display("FAIL: x10 expected 2");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[11] !== 32'd2) begin
            $display("FAIL: x11 expected 2");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // JAL DEPENDENCY CHECKS
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[13] !== 32'd92) begin
            $display("FAIL: x13 expected 92");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[14] !== 32'd93) begin
            $display("FAIL: x14 expected 93");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[15] !== 32'd42) begin
            $display("FAIL: x15 expected 42");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // SKIPPED INSTRUCTION CHECKS
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[20] !== 32'd0) begin
            $display("FAIL: x20 was modified by a skipped instruction");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[21] !== 32'd0) begin
            $display("FAIL: x21 was modified by a skipped instruction");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[22] !== 32'd0) begin
            $display("FAIL: x22 was modified by a skipped instruction");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[23] !== 32'd0) begin
            $display("FAIL: x23 was modified by a skipped instruction");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[24] !== 32'd0) begin
            $display("FAIL: x24 was modified by a skipped instruction");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // x0 CHECK
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
            $display("FAIL: x0 was modified");
            total_errors = total_errors + 1;
        end
        
        
        if (total_errors == t10_errors_before) begin
            $display("PASS: T10 randomized control-flow checks");
        end
        else begin
            $display("FAIL: T10 directed checks");
        end
        
        $display("T10 RANDOMIZED CONTROL-FLOW CHECKS COMPLETED"); 

        // =====================================================
        // T11: REGISTER FILE x0 PROTECTION REGRESSION
        // =====================================================
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        #1;
        
        clear_program();
        
        // Reset the x0 write-attempt counter for T11.
        x0_write_attempts = 0;
        
        
        // -----------------------------------------------------
        // INITIALIZE SOURCE REGISTERS
        // -----------------------------------------------------
        
        // 0: ADDI x1, x0, 11
        program_data[0] = 32'h00b00093;
        
        // 1: ADDI x2, x0, 7
        program_data[1] = 32'h00700113;
        
        
        // -----------------------------------------------------
        // ATTEMPT 1: R-TYPE ADD TO x0
        // -----------------------------------------------------
        
        // 2: ADD x0, x1, x2
        // Expected write data = 18.
        // Register file must reject the write.
        
        program_data[2] = 32'h00208033;
        
        
        // -----------------------------------------------------
        // ATTEMPT 2: ADDI TO x0
        // -----------------------------------------------------
        
        // 3: ADDI x0, x1, 5
        // Expected write data = 16.
        
        program_data[3] = 32'h00508013;
        
        
        // -----------------------------------------------------
        // ATTEMPT 3: LUI TO x0
        // -----------------------------------------------------
        
        // 4: LUI x0, 0x12345
        // Expected write data = 0x12345000.
        
        program_data[4] = 32'h12345037;
        
        
        // -----------------------------------------------------
        // STORE DATA FOR LOAD TEST
        // -----------------------------------------------------
        
        // 5: SW x1, 0(x0)
        // Memory[0] = 11.
        
        program_data[5] = 32'h00102023;
        
        
        // -----------------------------------------------------
        // ATTEMPT 4: LW TO x0
        // -----------------------------------------------------
        
        // 6: LW x0, 0(x0)
        // Expected load data = 11.
        // Register file must reject the write.
        
        program_data[6] = 32'h00002003;
        
        
        // -----------------------------------------------------
        // ATTEMPT 5: JAL TO x0
        // -----------------------------------------------------
        
        // 7: JAL x0, +8
        // Must jump to instruction index 9.
        // Return address must not modify x0.
        
        program_data[7] = 32'h0080006f;
        
        
        // -----------------------------------------------------
        // POISON INSTRUCTION: MUST BE SKIPPED
        // -----------------------------------------------------
        
        // 8: ADDI x3, x0, 99
        
        program_data[8] = 32'h06300193;
        
        
        // -----------------------------------------------------
        // VERIFY READING x0 AFTER WRITE ATTEMPTS
        // -----------------------------------------------------
        
        // 9: ADDI x29, x0, 0
        // Expected x29 = 0.
        
        program_data[9] = 32'h00000e93;
        
        
        // -----------------------------------------------------
        // NORMAL REGISTER WRITES MUST STILL WORK
        // -----------------------------------------------------
        
        // 10: ADDI x31, x0, -1
        
        program_data[10] = 32'hfff00f93;
        
        
        // 11: ADD x30, x1, x2
        // Expected x30 = 18.
        
        program_data[11] = 32'h00208f33;
        
        
        // Final NOP
        program_data[12] = 32'h00000013;
        
        
        load_program();
        
        
        // -----------------------------------------------------
        // EXECUTE T11
        // -----------------------------------------------------
        
        // Index 8 is skipped by JAL.
        // Total executed instructions = 11.
        
        run_test(11, "T11_X0_PROTECTION");
        
        
        // =====================================================
        // T11 DIRECTED CHECKS
        // =====================================================
        
        $display("");
        $display("T11 REGISTER FILE PROTECTION CHECKS");
        
        
        // Five attempted writes to x0.
        if (x0_write_attempts !== 5) begin
        
            $display(
                "FAIL: Expected 5 x0 write attempts, got %0d",
                x0_write_attempts
            );
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: All 5 x0 write attempts detected");
        
        end
        
        
        // x0 must permanently remain zero.
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
        
            $display("FAIL: x0 was modified");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: x0 remains zero");
        
        end
        
        
        // Source registers.
        if (dut.register_file_inst.registers[1] !== 32'd11)
            total_errors = total_errors + 1;
        
        if (dut.register_file_inst.registers[2] !== 32'd7)
            total_errors = total_errors + 1;
        
        
        // ADDI x29,x0,0 proves x0 reads as zero.
        if (dut.register_file_inst.registers[29] !== 32'd0) begin
        
            $display("FAIL: x29 expected zero");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // Normal register writes must work.
        if (dut.register_file_inst.registers[31] !== 32'hffffffff) begin
        
            $display("FAIL: x31 expected ffffffff");
        
            total_errors = total_errors + 1;
        
        end
        
        
        if (dut.register_file_inst.registers[30] !== 32'd18) begin
        
            $display("FAIL: x30 expected 18");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // Poison instruction must remain skipped.
        if (dut.register_file_inst.registers[3] !== 32'd0) begin
        
            $display("FAIL: skipped instruction modified x3");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // JAL x0 must still perform the jump.
        if (dut.trace_pc !== 32'd48) begin
        
            $display("FAIL: unexpected final PC");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // Store must have written 11 to memory.
        if (dut.data_memory_inst.memory[0] !== 32'd11) begin
        
            $display("FAIL: Memory[0] expected 11");
        
            total_errors = total_errors + 1;
        
        end
        
        
        if (total_errors == 0)
            $display("PASS: T11 x0 protection directed checks");
        else
            $display("FAIL: T11 x0 protection directed checks");
        
        $display("T11 REGISTER FILE PROTECTION CHECKS COMPLETED");
 
        // =====================================================
        // T12: UNSUPPORTED INSTRUCTION SAFETY REGRESSION
        // =====================================================
        
        $display("");
        $display("==============================================");
        $display("T12: UNSUPPORTED INSTRUCTION SAFETY");
        $display("==============================================");
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        #1;
        
        clear_program();
        
        t12_error_count = 0;
        
        
        // -----------------------------------------------------
        // TWO VALID INITIALIZATION INSTRUCTIONS
        // -----------------------------------------------------
        
        // 0: ADDI x1, x0, 11
        program_data[0] = 32'h00b00093;
        
        // 1: ADDI x2, x0, 7
        program_data[1] = 32'h00700113;
        
        
        // -----------------------------------------------------
        // FOUR UNSUPPORTED INSTRUCTIONS
        // -----------------------------------------------------
        
        // 2: Invalid R-type instruction.
        // funct3 = 111, funct7 = 0100000.
        // Attempts to write x5.
        
        program_data[2] = 32'h4020f2b3;
        
        
        // 3: Invalid I-type instruction.
        // funct3 = 001 (unsupported SLLI in this subset).
        // Attempts to write x6.
        
        program_data[3] = 32'h00509313;
        
        
        // 4: LH x7, 0(x0)
        // Unsupported load type.
        // Attempts to read memory and write x7.
        
        program_data[4] = 32'h00001383;
        
        
        // 5: SH x1, 4(x0)
        // Unsupported store type.
        // Attempts to write memory location 1.
        
        program_data[5] = 32'h00101223;
        
        
        // -----------------------------------------------------
        // LOAD PROGRAM
        // -----------------------------------------------------
        
        load_program();
        
        
        // -----------------------------------------------------
        // EXECUTE THE TWO VALID INITIALIZATION INSTRUCTIONS
        // -----------------------------------------------------
        
        run_test(2, "T12_VALID_INITIALIZATION");
        
        
        // -----------------------------------------------------
        // SNAPSHOT ALL ARCHITECTURAL STATE
        // -----------------------------------------------------
        
        for (t12_i = 0; t12_i < 32; t12_i = t12_i + 1)
            t12_register_snapshot[t12_i] =
                dut.register_file_inst.registers[t12_i];
        
        for (t12_i = 0; t12_i < 256; t12_i = t12_i + 1)
            t12_memory_snapshot[t12_i] =
                dut.data_memory_inst.memory[t12_i];
        
        
        // -----------------------------------------------------
        // CHECK THE FOUR UNSUPPORTED INSTRUCTIONS
        // -----------------------------------------------------
        
        for (t12_i = 2; t12_i < 6; t12_i = t12_i + 1)
        begin
        
            @(negedge clk);
            #1;
        
            $display("");
            $display(
                "T12 CHECK | PC=%h | INSTR=%h",
                dut.trace_pc,
                dut.trace_instruction
            );
        
        
            // ---------------------------------------------
            // CHECK PC AND INSTRUCTION
            // ---------------------------------------------
        
            if (dut.trace_pc !== (t12_i * 4))
            begin
        
                $display(
                    "ERROR: T12 unexpected PC. Expected=%h Actual=%h",
                    (t12_i * 4),
                    dut.trace_pc
                );
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
        
        
            if (dut.trace_instruction !== program_data[t12_i])
            begin
        
                $display("ERROR: T12 instruction mismatch");
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
        
        
            // ---------------------------------------------
            // UNSUPPORTED INSTRUCTION MUST BE INVALID
            // ---------------------------------------------
        
            if (dut.trace_valid !== 1'b0)
            begin
        
                $display("ERROR: Unsupported instruction marked valid");
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
            else
            begin
        
                $display("PASS: Unsupported instruction identified");
        
            end
        
        
            // ---------------------------------------------
            // CHECK RAW CONTROL SIGNALS
            // ---------------------------------------------
        
            if (dut.RegWrite !== 1'b0)
            begin
        
                $display(
                    "ERROR: RegWrite asserted for unsupported instruction: %h",
                    dut.trace_instruction
                );
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
        
        
            if (dut.MemWrite !== 1'b0)
            begin
        
                $display(
                    "ERROR: MemWrite asserted for unsupported instruction: %h",
                    dut.trace_instruction
                );
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
        
        
            if (dut.MemRead !== 1'b0)
            begin
        
                $display(
                    "ERROR: MemRead asserted for unsupported instruction: %h",
                    dut.trace_instruction
                );
        
                t12_error_count = t12_error_count + 1;
                total_errors = total_errors + 1;
        
            end
        
        
            // ---------------------------------------------
            // COMMIT CLOCK EDGE
            // ---------------------------------------------
        
            @(posedge clk);
            #1;
        
        
            // ---------------------------------------------
            // VERIFY ALL 32 REGISTERS REMAIN UNCHANGED
            // ---------------------------------------------
        
            for (t12_j = 0; t12_j < 32; t12_j = t12_j + 1)
            begin
        
                if (
                    dut.register_file_inst.registers[t12_j]
                    !== t12_register_snapshot[t12_j]
                )
                begin
        
                    $display(
                        "ERROR: Register x%0d changed during unsupported instruction",
                        t12_j
                    );
        
                    t12_error_count = t12_error_count + 1;
                    total_errors = total_errors + 1;
        
                end
        
            end
        
        
            // ---------------------------------------------
            // VERIFY ALL 256 MEMORY LOCATIONS REMAIN UNCHANGED
            // ---------------------------------------------
        
            for (t12_j = 0; t12_j < 256; t12_j = t12_j + 1)
            begin
        
                if (
                    dut.data_memory_inst.memory[t12_j]
                    !== t12_memory_snapshot[t12_j]
                )
                begin
        
                    $display(
                        "ERROR: Memory[%0d] changed during unsupported instruction",
                        t12_j
                    );
        
                    t12_error_count = t12_error_count + 1;
                    total_errors = total_errors + 1;
        
                end
        
            end
        
        end
        
        
        // =====================================================
        // T12 FINAL DIRECTED CHECKS
        // =====================================================
        
        $display("");
        $display("T12 UNSUPPORTED INSTRUCTION SAFETY CHECKS");
        
        
        // Valid initialization must remain correct.
        if (dut.register_file_inst.registers[1] !== 32'd11)
        begin
        
            $display("ERROR: x1 initialization corrupted");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        if (dut.register_file_inst.registers[2] !== 32'd7)
        begin
        
            $display("ERROR: x2 initialization corrupted");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        // Unsupported instructions must not modify their destinations.
        if (dut.register_file_inst.registers[5] !== 32'd0)
        begin
        
            $display("ERROR: x5 modified by invalid R-type instruction");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        if (dut.register_file_inst.registers[6] !== 32'd0)
        begin
        
            $display("ERROR: x6 modified by invalid I-type instruction");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        if (dut.register_file_inst.registers[7] !== 32'd0)
        begin
        
            $display("ERROR: x7 modified by unsupported LH instruction");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        // SH must not modify memory[1].
        if (dut.data_memory_inst.memory[1] !== 32'd0)
        begin
        
            $display("ERROR: Memory[1] modified by unsupported SH");
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        // PC should have advanced past all four instructions.
        if (dut.trace_pc !== 32'h00000018)
        begin
        
            $display("ERROR: Unexpected final PC: %h", dut.trace_pc);
        
            t12_error_count = t12_error_count + 1;
            total_errors = total_errors + 1;
        
        end
        
        
        if (t12_error_count == 0)
        begin
        
            $display("PASS: All unsupported instructions blocked");
            $display("PASS: All registers remained unchanged");
            $display("PASS: All memory locations remained unchanged");
            $display("PASS: T12 UNSUPPORTED INSTRUCTION SAFETY");
        
        end
        else
        begin
        
            $display(
                "FAIL: T12 detected %0d errors",
                t12_error_count
            );
        
        end
        
        $display("T12 UNSUPPORTED INSTRUCTION SAFETY COMPLETED");
                       

        // =====================================================
        // T13: RESET AND RESTART REGRESSION
        // =====================================================
        
        $display("");
        $display("==============================================");
        $display("T13: RESET AND RESTART VERIFICATION");
        $display("==============================================");
        
        t13_start_errors = total_errors;
        
        
        // -----------------------------------------------------
        // INITIAL RESET AND PROGRAM PREPARATION
        // -----------------------------------------------------
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        #1;
        
        clear_program();
        
        
        // -----------------------------------------------------
        // LOAD SIX-INSTRUCTION PROGRAM
        // -----------------------------------------------------
        
        // 0: ADDI x1, x0, 11
        program_data[0] = 32'h00b00093;
        
        // 1: ADDI x2, x0, 7
        program_data[1] = 32'h00700113;
        
        // 2: SW x1, 0(x0)
        // Memory[0] = 11
        program_data[2] = 32'h00102023;
        
        // 3: ADD x3, x1, x2
        // x3 = 18
        program_data[3] = 32'h002081b3;
        
        // 4: SW x3, 4(x0)
        // Memory[1] = 18
        program_data[4] = 32'h00302223;
        
        // 5: LW x4, 0(x0)
        // x4 = 11
        program_data[5] = 32'h00002203;
        
        
        load_program();
        
        
        // =====================================================
        // STAGE 1: PARTIAL EXECUTION
        // =====================================================
        
        $display("");
        $display("T13 STAGE 1: PARTIAL PROGRAM EXECUTION");
        
        
        // Execute the first four instructions.
        run_test(4, "T13_PARTIAL_EXECUTION");
        
        
        // Verify state before reset.
        
        if (dut.register_file_inst.registers[1] !== 32'd11) begin
            $display("ERROR: Before reset, x1 expected 11");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[2] !== 32'd7) begin
            $display("ERROR: Before reset, x2 expected 7");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[3] !== 32'd18) begin
            $display("ERROR: Before reset, x3 expected 18");
            total_errors = total_errors + 1;
        end
        
        if (dut.data_memory_inst.memory[0] !== 32'd11) begin
            $display("ERROR: Before reset, memory[0] expected 11");
            total_errors = total_errors + 1;
        end
        
        if (dut.trace_pc !== 32'h00000010) begin
            $display("ERROR: Before reset, PC expected 0x10");
            total_errors = total_errors + 1;
        end
        
        
        // =====================================================
        // STAGE 2: ASSERT RESET DURING EXECUTION
        // =====================================================
        
        $display("");
        $display("T13 STAGE 2: ASSERTING RESET");
        
        
        // Assert reset at a falling edge.
        @(negedge clk);
        #1;
        
        reset = 1'b1;
        
        
        // Allow synchronous reset to take effect.
        @(posedge clk);
        #1;
        
        
        // -----------------------------------------------------
        // CHECK PROGRAM COUNTER RESET
        // -----------------------------------------------------
        
        if (dut.trace_pc !== 32'd0) begin
        
            $display(
                "ERROR: PC reset failed. Actual PC = %h",
                dut.trace_pc
            );
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: PC reset to zero");
        
        end
        
        
        // -----------------------------------------------------
        // CHECK ALL 32 REGISTERS
        // -----------------------------------------------------
        
        for (t13_i = 0; t13_i < 32; t13_i = t13_i + 1) begin
        
            if (dut.register_file_inst.registers[t13_i] !== 32'd0) begin
        
                $display(
                    "ERROR: Register x%0d not cleared. Value = %h",
                    t13_i,
                    dut.register_file_inst.registers[t13_i]
                );
        
                total_errors = total_errors + 1;
        
            end
        
        end
        
        
        // -----------------------------------------------------
        // CHECK ALL 256 DATA MEMORY LOCATIONS
        // -----------------------------------------------------
        
        for (t13_i = 0; t13_i < 256; t13_i = t13_i + 1) begin
        
            if (dut.data_memory_inst.memory[t13_i] !== 32'd0) begin
        
                $display(
                    "ERROR: Memory[%0d] not cleared. Value = %h",
                    t13_i,
                    dut.data_memory_inst.memory[t13_i]
                );
        
                total_errors = total_errors + 1;
        
            end
        
        end
        
        
        if (
            dut.register_file_inst.registers[0] === 32'd0 &&
            dut.register_file_inst.registers[1] === 32'd0 &&
            dut.register_file_inst.registers[2] === 32'd0 &&
            dut.register_file_inst.registers[3] === 32'd0 &&
            dut.data_memory_inst.memory[0] === 32'd0 &&
            dut.data_memory_inst.memory[1] === 32'd0
        ) begin
        
            $display("PASS: Register and memory reset checks");
        
        end
        else begin
        
            $display("FAIL: Register or memory reset checks");
        
        end
        
        
        // -----------------------------------------------------
        // INSTRUCTION MEMORY MUST RETAIN THE PROGRAM
        // -----------------------------------------------------
        
        if (
            dut.instruction_memory_inst.memory[0] !== 32'h00b00093 ||
            dut.instruction_memory_inst.memory[5] !== 32'h00002203
        ) begin
        
            $display("ERROR: Instruction memory contents changed during reset");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Instruction memory retained program");
        
        end
        
        
        // =====================================================
        // STAGE 3: RESTART PROGRAM AFTER RESET
        // =====================================================
        
        $display("");
        $display("T13 STAGE 3: RESTARTING PROGRAM");
        
        
        // Execute the complete six-instruction program again.
        run_test(6, "T13_RESTART_AFTER_RESET");
        
        
        // -----------------------------------------------------
        // FINAL ARCHITECTURAL CHECKS
        // -----------------------------------------------------
        
        $display("");
        $display("T13 FINAL RESTART CHECKS");
        
        
        // Registers
        if (dut.register_file_inst.registers[1] !== 32'd11) begin
            $display("ERROR: Restart x1 expected 11");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[2] !== 32'd7) begin
            $display("ERROR: Restart x2 expected 7");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[3] !== 32'd18) begin
            $display("ERROR: Restart x3 expected 18");
            total_errors = total_errors + 1;
        end
        
        if (dut.register_file_inst.registers[4] !== 32'd11) begin
            $display("ERROR: Restart x4 expected 11");
            total_errors = total_errors + 1;
        end
        
        // Memory
        if (dut.data_memory_inst.memory[0] !== 32'd11) begin
            $display("ERROR: Restart memory[0] expected 11");
            total_errors = total_errors + 1;
        end
        
        if (dut.data_memory_inst.memory[1] !== 32'd18) begin
            $display("ERROR: Restart memory[1] expected 18");
            total_errors = total_errors + 1;
        end
        
        // x0
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
            $display("ERROR: x0 changed after restart");
            total_errors = total_errors + 1;
        end
        
        // Final PC = 6 * 4 = 24
        if (dut.trace_pc !== 32'h00000018) begin
            $display("ERROR: Final restart PC expected 0x18");
            total_errors = total_errors + 1;
        end
        
        
        // -----------------------------------------------------
        // T13 FINAL STATUS
        // -----------------------------------------------------
        
        if (total_errors == t13_start_errors) begin
        
            $display("PASS: Reset cleared all registers");
            $display("PASS: Reset cleared all data memory");
            $display("PASS: Instruction memory retained program");
            $display("PASS: Processor restarted successfully");
            $display("PASS: T13 RESET AND RESTART");
        
        end
        else begin
        
            $display(
                "FAIL: T13 detected %0d errors",
                total_errors - t13_start_errors
            );
        
        end
        
        $display("T13 RESET AND RESTART VERIFICATION COMPLETED");
         
         // =====================================================
        // T14: BOUNDARY AND STRESS TEST
        // =====================================================
        
        $display("");
        $display("==============================================");
        $display("T14: BOUNDARY AND STRESS TEST");
        $display("==============================================");
        
        reset = 1'b1;
        
        repeat (2)
            @(posedge clk);
        
        @(negedge clk);
        #1;
        
        clear_program();
        
        
        // -----------------------------------------------------
        // MEMORY BOUNDARY TESTS
        // -----------------------------------------------------
        
        // 0: ADDI x1, x0, 0
        program_data[0] = 32'h00000093;
        
        // 1: ADDI x2, x0, 1020
        // Last valid word address in 256-word memory.
        program_data[1] = 32'h3fc00113;
        
        // 2: ADDI x3, x0, 85
        program_data[2] = 32'h05500193;
        
        // 3: SW x3, 0(x1)
        // Memory[0] = 85
        program_data[3] = 32'h0030a023;
        
        // 4: LW x4, 0(x1)
        // x4 = 85
        program_data[4] = 32'h0000a203;
        
        // 5: ADDI x3, x3, 1
        // x3 = 86
        program_data[5] = 32'h00118193;
        
        // 6: SW x3, 0(x1)
        // Overwrite Memory[0] = 86
        program_data[6] = 32'h0030a023;
        
        // 7: LW x5, 0(x1)
        // x5 = 86
        program_data[7] = 32'h0000a283;
        
        // 8: SW x3, 0(x2)
        // Memory[255] = 86
        program_data[8] = 32'h00312023;
        
        // 9: LW x6, 0(x2)
        // x6 = 86
        program_data[9] = 32'h00012303;
        
        
        // -----------------------------------------------------
        // SIGNED IMMEDIATE BOUNDARY TESTS
        // -----------------------------------------------------
        
        // 10: ADDI x7, x0, -2048
        program_data[10] = 32'h80000393;
        
        // 11: ADDI x8, x0, +2047
        program_data[11] = 32'h7ff00413;
        
        
        // -----------------------------------------------------
        // SIGNED ARITHMETIC TESTS
        // -----------------------------------------------------
        
        // 12: ADD x9, x7, x8
        // -2048 + 2047 = -1
        program_data[12] = 32'h008384b3;
        
        // 13: SLT x10, x7, x8
        // -2048 < 2047 = 1
        program_data[13] = 32'h0083a533;
        
        // 14: SLT x11, x8, x7
        // 2047 < -2048 = 0
        program_data[14] = 32'h007425b3;
        
        // 15: SUB x12, x7, x8
        // -2048 - 2047 = -4095
        program_data[15] = 32'h40838633;
        
        
        // -----------------------------------------------------
        // LOAD PROGRAM INTO DUT AND REFERENCE MODEL
        // -----------------------------------------------------
        
        load_program();
        
        
        // =====================================================
        // EXECUTE T14
        // =====================================================
        
        run_test(16, "T14_BOUNDARY_STRESS");
        
        
        // =====================================================
        // T14 DIRECTED CHECKS
        // =====================================================
        
        $display("");
        $display("T14 BOUNDARY AND STRESS DIRECTED CHECKS");
        
        
        // -----------------------------------------------------
        // MEMORY BASE ADDRESSES
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[1] !== 32'd0) begin
        
            $display("ERROR: x1 expected 0");
        
            total_errors = total_errors + 1;
        
        end
        
        if (dut.register_file_inst.registers[2] !== 32'd1020) begin
        
            $display("ERROR: x2 expected 1020");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // -----------------------------------------------------
        // REPEATED MEMORY WRITE AND LOAD
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[4] !== 32'd85) begin
        
            $display("ERROR: x4 expected 85");
        
            total_errors = total_errors + 1;
        
        end
        
        if (dut.register_file_inst.registers[5] !== 32'd86) begin
        
            $display("ERROR: x5 expected 86");
        
            total_errors = total_errors + 1;
        
        end
        
        if (dut.register_file_inst.registers[6] !== 32'd86) begin
        
            $display("ERROR: x6 expected 86");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // -----------------------------------------------------
        // LOWEST VALID MEMORY WORD
        // -----------------------------------------------------
        
        if (dut.data_memory_inst.memory[0] !== 32'd86) begin
        
            $display(
                "ERROR: Memory[0] expected 86, got %h",
                dut.data_memory_inst.memory[0]
            );
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Lowest memory word (index 0)");
        
        end
        
        
        // -----------------------------------------------------
        // HIGHEST VALID MEMORY WORD
        // -----------------------------------------------------
        
        if (dut.data_memory_inst.memory[255] !== 32'd86) begin
        
            $display(
                "ERROR: Memory[255] expected 86, got %h",
                dut.data_memory_inst.memory[255]
            );
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Highest memory word (index 255)");
        
        end
        
        
        // -----------------------------------------------------
        // IMMEDIATE BOUNDARIES
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[7] !== 32'hfffff800) begin
        
            $display("ERROR: Minimum signed immediate failed");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Minimum signed immediate (-2048)");
        
        end
        
        
        if (dut.register_file_inst.registers[8] !== 32'h000007ff) begin
        
            $display("ERROR: Maximum signed immediate failed");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Maximum signed immediate (+2047)");
        
        end
        
        
        // -----------------------------------------------------
        // SIGNED ADDITION
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[9] !== 32'hffffffff) begin
        
            $display("ERROR: Signed ADD boundary result incorrect");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Signed ADD boundary");
        
        end
        
        
        // -----------------------------------------------------
        // SIGNED COMPARISON
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[10] !== 32'd1) begin
        
            $display("ERROR: SLT negative versus positive failed");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: SLT negative < positive");
        
        end
        
        
        if (dut.register_file_inst.registers[11] !== 32'd0) begin
        
            $display("ERROR: SLT positive versus negative failed");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: SLT positive < negative correctly false");
        
        end
        
        
        // -----------------------------------------------------
        // SIGNED SUBTRACTION
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[12] !== 32'hfffff001) begin
        
            $display("ERROR: Signed SUB boundary result incorrect");
        
            total_errors = total_errors + 1;
        
        end
        else begin
        
            $display("PASS: Signed SUB boundary");
        
        end
        
        
        // -----------------------------------------------------
        // X0 PROTECTION
        // -----------------------------------------------------
        
        if (dut.register_file_inst.registers[0] !== 32'd0) begin
        
            $display("ERROR: x0 modified during T14");
        
            total_errors = total_errors + 1;
        
        end
        
        
        // -----------------------------------------------------
        // FINAL PC
        // -----------------------------------------------------
        
        if (dut.trace_pc !== 32'h00000040) begin
        
            $display(
                "ERROR: T14 final PC expected 0x40, got %h",
                dut.trace_pc
            );
        
            total_errors = total_errors + 1;
        
        end
        
        
        // -----------------------------------------------------
        // FINAL T14 STATUS
        // -----------------------------------------------------
        
        if (total_errors == 0) begin
        
            $display("PASS: T14 BOUNDARY AND STRESS DIRECTED CHECKS");
        
        end
        else begin
        
            $display("FAIL: T14 BOUNDARY AND STRESS DIRECTED CHECKS");
        
        end
        
        $display("T14 BOUNDARY AND STRESS TEST COMPLETED");

        // =====================================================
        // T15: RS2 HIGH-REGISTER CLASS COVERAGE
        // =====================================================

        $display("");
        $display("==============================================");
        $display("T15: RS2 HIGH-REGISTER CLASS COVERAGE");
        $display("==============================================");

        // Record existing coverage before executing T15.
        t15_rs2_before = coverage.rs2_class_count[3];

        // Reset CPU and reference model.
        // Functional coverage counters are preserved.
        reset = 1'b1;

        repeat (2)
            @(posedge clk);

        @(negedge clk);
        #1;

        clear_program();

        // 0: ADDI x20, x0, 7
        // Initialize a register in the x16-x31 class.
        program_data[0] = 32'h00700A13;

        // 1: ADDI x21, x0, 9
        // Initialize another register in the x16-x31 class.
        program_data[1] = 32'h00900A93;

        // 2: ADD x22, x1, x20
        // RS2 = x20 (high-register class).
        program_data[2] = 32'h01408B33;

        // 3: ADD x23, x20, x21
        // RS2 = x21 (high-register class).
        program_data[3] = 32'h015A0BB3;

        load_program();

        // Execute all four instructions.
        run_test(4, "T15_RS2_HIGH_REGISTER");

        // -----------------------------------------------------
        // T15 DIRECTED REGISTER CHECKS
        // -----------------------------------------------------

        $display("");
        $display("T15 DIRECTED REGISTER CHECKS");

        if (dut.register_file_inst.registers[20] !== 32'd7) begin
            $display("ERROR: x20 expected 7");
            total_errors = total_errors + 1;
        end
        else
            $display("PASS: x20 = 7");

        if (dut.register_file_inst.registers[21] !== 32'd9) begin
            $display("ERROR: x21 expected 9");
            total_errors = total_errors + 1;
        end
        else
            $display("PASS: x21 = 9");

        if (dut.register_file_inst.registers[22] !== 32'd7) begin
            $display("ERROR: x22 expected 7");
            total_errors = total_errors + 1;
        end
        else
            $display("PASS: x22 = 7");

        if (dut.register_file_inst.registers[23] !== 32'd16) begin
            $display("ERROR: x23 expected 16");
            total_errors = total_errors + 1;
        end
        else
            $display("PASS: x23 = 16");

        // -----------------------------------------------------
        // T15 FUNCTIONAL COVERAGE CHECK
        // -----------------------------------------------------

        if (coverage.rs2_class_count[3] !== t15_rs2_before + 2) begin

            $display(
                "ERROR: RS2 high-register coverage expected %0d, got %0d",
                t15_rs2_before + 2,
                coverage.rs2_class_count[3]
            );

            total_errors = total_errors + 1;
        end
        else begin

            $display(
                "PASS: RS2 x16-x31 coverage increased by 2 (total = %0d)",
                coverage.rs2_class_count[3]
            );

        end

        if (total_errors == 0)
            $display("PASS: T15 RS2 HIGH-REGISTER COVERAGE");
        else
            $display("FAIL: T15 RS2 HIGH-REGISTER COVERAGE");

        $display("T15 HIGH-REGISTER COVERAGE TEST COMPLETED");
                      
        // =====================================================
        // 12. FINAL FUNCTIONAL COVERAGE REPORT
        // =====================================================

        $display("");
        $display("==============================================");
        $display("UNIFIED REGRESSION COMPLETE");
        $display("==============================================");

        coverage_report_enable = 1'b1;

        #2;

        if (coverage_error !== 1'b0)
            total_errors = total_errors + 1;


        // =====================================================
        // 13. FINAL RESULT
        // =====================================================

        $display("");
        $display("==============================================");

        if (total_errors == 0) begin
        
            $display("T01 REGISTER DEPENDENCY       : PASS");
            $display("T02 ARITHMETIC CORNER CASES   : PASS");
            $display("T03 SLT SIGNED BOUNDARIES     : PASS");
            $display("T04 MULTI-ADDRESS MEMORY      : PASS");
            $display("T05 BEQ CORNER CASES          : PASS");
            $display("T06 JAL CORNER CASES          : PASS");
            $display("T07 BNE CORNER CASES          : PASS");
            $display("T08 RANDOM ARITHMETIC       : PASS");
            $display("T09 RANDOM MEMORY           : PASS");
            $display("T10 RANDOM CONTROL FLOW      : PASS");
            $display("T11 REGISTER FILE PROTECTION : PASS");
            if (t12_error_count == 0)
                $display("T12 UNSUPPORTED INSTRUCTION SAFETY : PASS");
            else
                $display("T12 UNSUPPORTED INSTRUCTION SAFETY : FAIL");
            $display("T13 RESET AND RESTART         : PASS");
            if (total_errors == 0)
                $display("T14 BOUNDARY AND STRESS : PASS");
            else
                $display("T14 BOUNDARY AND STRESS : FAIL");
            $display("T15 RS2 HIGH-REGISTER COVERAGE : PASS");
            $display("");
            $display("UNIFIED RV32I REGRESSION: ALL PASSED");
            $display("Total errors = 0");
        
        end
        
        else begin
        
            $display("UNIFIED RV32I REGRESSION: FAILED");
            $display("Total errors = %0d", total_errors);
        
        end

        $display("==============================================");

        $finish;

    end

endmodule
