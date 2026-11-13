`timescale 1ns / 1ps

module rv32i_functional_coverage (

    input wire clk,
    input wire reset,
    input wire coverage_reset,
    input wire report_enable,

    input wire trace_valid,
    input wire [31:0] trace_pc,
    input wire [31:0] trace_instruction,
    input wire [31:0] trace_next_pc,

    input wire trace_reg_write,
    input wire [4:0] trace_rd,
    input wire [31:0] trace_write_data,

    input wire trace_mem_write,
    input wire [31:0] trace_mem_address,
    input wire [31:0] trace_mem_write_data,

    output reg coverage_error

);

    // =====================================================
    // 1. TOTAL INSTRUCTION COUNT
    // =====================================================

    integer total_commits;
    integer unsupported_count;


    // =====================================================
    // 2. INSTRUCTION COVERAGE
    // =====================================================

    integer count_add;
    integer count_sub;
    integer count_and;
    integer count_or;
    integer count_slt;

    integer count_addi;
    integer count_lw;
    integer count_sw;

    integer count_beq;
    integer count_bne;

    integer count_jal;
    integer count_lui;


    // =====================================================
    // 3. BRANCH COVERAGE
    // =====================================================

    integer beq_taken;
    integer beq_not_taken;

    integer bne_taken;
    integer bne_not_taken;

    integer branch_forward;
    integer branch_backward;


    // =====================================================
    // 4. JUMP COVERAGE
    // =====================================================

    integer jal_forward;
    integer jal_backward;

    integer jal_rd_zero;
    integer jal_rd_nonzero;


    // =====================================================
    // 5. IMMEDIATE COVERAGE
    // =====================================================

    integer addi_imm_positive;
    integer addi_imm_negative;
    integer addi_imm_zero;


    // =====================================================
    // 6. REGISTER CLASS COVERAGE
    //
    // Class 0: x0
    // Class 1: x1-x7
    // Class 2: x8-x15
    // Class 3: x16-x31
    // =====================================================

    integer rs1_class_count [0:3];
    integer rs2_class_count [0:3];
    integer rd_class_count  [0:3];

    integer rd_zero_suppressed;
    integer x0_write_violation;


    // =====================================================
    // 7. MEMORY COVERAGE
    //
    // Low  : word indices 0-63
    // Mid  : word indices 64-191
    // High : word indices 192-255
    // =====================================================

    integer lw_low;
    integer lw_mid;
    integer lw_high;

    integer sw_low;
    integer sw_mid;
    integer sw_high;

    integer lw_unaligned;
    integer sw_unaligned;

    integer memory_out_of_range;
    integer unexpected_memory_write;


    // =====================================================
    // 8. DEPENDENCY COVERAGE
    // =====================================================

    integer raw_rs1_count;
    integer raw_rs2_count;

    integer load_use_rs1_count;
    integer load_use_rs2_count;

    reg previous_reg_write;
    reg previous_load;

    reg [4:0] previous_rd;


    // =====================================================
    // 9. INTERNAL VARIABLES
    // =====================================================

    integer k;

    integer instruction_bins_hit;
    integer branch_bins_hit;
    integer jump_bins_hit;

    reg uses_rs1;
    reg uses_rs2;

    reg is_lw;
    reg is_sw;
    reg writes_rd;


    // =====================================================
    // 10. REGISTER CLASSIFICATION FUNCTION
    // =====================================================

    function automatic integer register_class;

        input [4:0] reg_number;

        begin

            if (reg_number == 5'd0)
                register_class = 0;

            else if (reg_number <= 5'd7)
                register_class = 1;

            else if (reg_number <= 5'd15)
                register_class = 2;

            else
                register_class = 3;

        end

    endfunction


    // =====================================================
    // 11. COVERAGE COUNTER RESET
    // =====================================================

    always @(posedge clk) begin

        if (coverage_reset) begin

            total_commits = 0;
            unsupported_count = 0;

            count_add = 0;
            count_sub = 0;
            count_and = 0;
            count_or = 0;
            count_slt = 0;

            count_addi = 0;
            count_lw = 0;
            count_sw = 0;

            count_beq = 0;
            count_bne = 0;

            count_jal = 0;
            count_lui = 0;

            beq_taken = 0;
            beq_not_taken = 0;

            bne_taken = 0;
            bne_not_taken = 0;

            branch_forward = 0;
            branch_backward = 0;

            jal_forward = 0;
            jal_backward = 0;

            jal_rd_zero = 0;
            jal_rd_nonzero = 0;

            addi_imm_positive = 0;
            addi_imm_negative = 0;
            addi_imm_zero = 0;

            rd_zero_suppressed = 0;
            x0_write_violation = 0;

            lw_low = 0;
            lw_mid = 0;
            lw_high = 0;

            sw_low = 0;
            sw_mid = 0;
            sw_high = 0;

            lw_unaligned = 0;
            sw_unaligned = 0;

            memory_out_of_range = 0;
            unexpected_memory_write = 0;

            raw_rs1_count = 0;
            raw_rs2_count = 0;

            load_use_rs1_count = 0;
            load_use_rs2_count = 0;

            previous_reg_write = 1'b0;
            previous_load = 1'b0;
            previous_rd = 5'd0;

            coverage_error = 1'b0;

            for (k = 0; k < 4; k = k + 1) begin

                rs1_class_count[k] = 0;
                rs2_class_count[k] = 0;
                rd_class_count[k] = 0;

            end

        end

        else if (reset) begin
        
            // Clear only the previous-instruction tracking.
            // Preserve all accumulated coverage counters.
        
            previous_reg_write = 1'b0;
            previous_load = 1'b0;
            previous_rd = 5'd0;
        
        end
        // =================================================
        // 12. SAMPLE EACH VALID INSTRUCTION COMMIT
        // =================================================

        else if ((reset === 1'b0) && (trace_valid === 1'b1)) begin

            total_commits = total_commits + 1;

            uses_rs1 = 1'b0;
            uses_rs2 = 1'b0;

            is_lw = 1'b0;
            is_sw = 1'b0;
            writes_rd = 1'b0;


            // ---------------------------------------------
            // INSTRUCTION DECODE AND COVERAGE
            // ---------------------------------------------

            case (trace_instruction[6:0])


                // -----------------------------------------
                // R-TYPE
                // -----------------------------------------

                7'b0110011: begin

                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    writes_rd = 1'b1;

                    case (trace_instruction[14:12])

                        3'b000: begin

                            if (trace_instruction[31:25] == 7'b0000000)
                                count_add = count_add + 1;

                            else if (
                                trace_instruction[31:25] == 7'b0100000
                            )
                                count_sub = count_sub + 1;

                            else
                                unsupported_count = unsupported_count + 1;

                        end

                        3'b111: begin

                            if (trace_instruction[31:25] == 7'b0000000)
                                count_and = count_and + 1;

                            else
                                unsupported_count = unsupported_count + 1;

                        end

                        3'b110: begin

                            if (trace_instruction[31:25] == 7'b0000000)
                                count_or = count_or + 1;

                            else
                                unsupported_count = unsupported_count + 1;

                        end

                        3'b010: begin

                            if (trace_instruction[31:25] == 7'b0000000)
                                count_slt = count_slt + 1;

                            else
                                unsupported_count = unsupported_count + 1;

                        end

                        default:
                            unsupported_count = unsupported_count + 1;

                    endcase

                end


                // -----------------------------------------
                // ADDI
                // -----------------------------------------

                7'b0010011: begin

                    if (trace_instruction[14:12] == 3'b000) begin

                        count_addi = count_addi + 1;

                        uses_rs1 = 1'b1;
                        writes_rd = 1'b1;

                        if (trace_instruction[31:20] == 12'd0)
                            addi_imm_zero = addi_imm_zero + 1;

                        else if (trace_instruction[31] == 1'b1)
                            addi_imm_negative =
                                addi_imm_negative + 1;

                        else
                            addi_imm_positive =
                                addi_imm_positive + 1;

                    end

                    else
                        unsupported_count = unsupported_count + 1;

                end


                // -----------------------------------------
                // LW
                // -----------------------------------------

                7'b0000011: begin

                    if (trace_instruction[14:12] == 3'b010) begin

                        count_lw = count_lw + 1;

                        uses_rs1 = 1'b1;
                        writes_rd = 1'b1;
                        is_lw = 1'b1;

                    end

                    else
                        unsupported_count = unsupported_count + 1;

                end


                // -----------------------------------------
                // SW
                // -----------------------------------------

                7'b0100011: begin

                    if (trace_instruction[14:12] == 3'b010) begin

                        count_sw = count_sw + 1;

                        uses_rs1 = 1'b1;
                        uses_rs2 = 1'b1;
                        is_sw = 1'b1;

                    end

                    else
                        unsupported_count = unsupported_count + 1;

                end


                // -----------------------------------------
                // BEQ / BNE
                // -----------------------------------------

                7'b1100011: begin

                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;

                    if (trace_instruction[31] == 1'b1)
                        branch_backward = branch_backward + 1;

                    else
                        branch_forward = branch_forward + 1;


                    if (trace_instruction[14:12] == 3'b000) begin

                        count_beq = count_beq + 1;

                        if (trace_next_pc != trace_pc + 32'd4)
                            beq_taken = beq_taken + 1;

                        else
                            beq_not_taken = beq_not_taken + 1;

                    end

                    else if (trace_instruction[14:12] == 3'b001) begin

                        count_bne = count_bne + 1;

                        if (trace_next_pc != trace_pc + 32'd4)
                            bne_taken = bne_taken + 1;

                        else
                            bne_not_taken = bne_not_taken + 1;

                    end

                    else
                        unsupported_count = unsupported_count + 1;

                end


                // -----------------------------------------
                // JAL
                // -----------------------------------------

                7'b1101111: begin

                    count_jal = count_jal + 1;
                    writes_rd = 1'b1;

                    if (trace_instruction[31] == 1'b1)
                        jal_backward = jal_backward + 1;

                    else
                        jal_forward = jal_forward + 1;

                    if (trace_instruction[11:7] == 5'd0)
                        jal_rd_zero = jal_rd_zero + 1;

                    else
                        jal_rd_nonzero = jal_rd_nonzero + 1;

                end


                // -----------------------------------------
                // LUI
                // -----------------------------------------

                7'b0110111: begin

                    count_lui = count_lui + 1;
                    writes_rd = 1'b1;

                end


                // -----------------------------------------
                // UNSUPPORTED OPCODE
                // -----------------------------------------

                default: begin

                    unsupported_count = unsupported_count + 1;

                end

            endcase


            // =================================================
            // 13. REGISTER CLASS COVERAGE
            // =================================================

            if (uses_rs1) begin

                rs1_class_count[
                    register_class(trace_instruction[19:15])
                ] = rs1_class_count[
                    register_class(trace_instruction[19:15])
                ] + 1;

            end


            if (uses_rs2) begin

                rs2_class_count[
                    register_class(trace_instruction[24:20])
                ] = rs2_class_count[
                    register_class(trace_instruction[24:20])
                ] + 1;

            end


            if (writes_rd) begin

                if (trace_instruction[11:7] == 5'd0)
                    rd_zero_suppressed = rd_zero_suppressed + 1;

                else
                    rd_class_count[
                        register_class(trace_instruction[11:7])
                    ] = rd_class_count[
                        register_class(trace_instruction[11:7])
                    ] + 1;

            end


            if (trace_reg_write && trace_rd == 5'd0) begin

                x0_write_violation = x0_write_violation + 1;
                coverage_error = 1'b1;

            end


            // =================================================
            // 14. MEMORY ADDRESS COVERAGE
            // =================================================

            if (is_lw) begin

                if (trace_mem_address[1:0] != 2'b00)
                    lw_unaligned = lw_unaligned + 1;

                if (trace_mem_address[31:2] > 30'd255)
                    memory_out_of_range = memory_out_of_range + 1;

                else if (trace_mem_address[31:2] < 30'd64)
                    lw_low = lw_low + 1;

                else if (trace_mem_address[31:2] < 30'd192)
                    lw_mid = lw_mid + 1;

                else
                    lw_high = lw_high + 1;

            end


            if (is_sw) begin

                if (!trace_mem_write)
                    unexpected_memory_write =
                        unexpected_memory_write + 1;

                if (trace_mem_address[1:0] != 2'b00)
                    sw_unaligned = sw_unaligned + 1;

                if (trace_mem_address[31:2] > 30'd255)
                    memory_out_of_range = memory_out_of_range + 1;

                else if (trace_mem_address[31:2] < 30'd64)
                    sw_low = sw_low + 1;

                else if (trace_mem_address[31:2] < 30'd192)
                    sw_mid = sw_mid + 1;

                else
                    sw_high = sw_high + 1;

            end

            else if (trace_mem_write) begin

                unexpected_memory_write =
                    unexpected_memory_write + 1;

            end


            // =================================================
            // 15. RAW DEPENDENCY COVERAGE
            //
            // Checks whether the current instruction reads
            // the destination of the immediately preceding
            // committed instruction.
            // =================================================

            if (previous_reg_write && previous_rd != 5'd0) begin

                if (
                    uses_rs1 &&
                    trace_instruction[19:15] == previous_rd
                ) begin

                    raw_rs1_count = raw_rs1_count + 1;

                    if (previous_load)
                        load_use_rs1_count =
                            load_use_rs1_count + 1;

                end


                if (
                    uses_rs2 &&
                    trace_instruction[24:20] == previous_rd
                ) begin

                    raw_rs2_count = raw_rs2_count + 1;

                    if (previous_load)
                        load_use_rs2_count =
                            load_use_rs2_count + 1;

                end

            end


            // =================================================
            // 16. REMEMBER PREVIOUS INSTRUCTION
            // =================================================
            if (unsupported_count != 0 ||
                x0_write_violation != 0 ||
                unexpected_memory_write != 0 ||
                memory_out_of_range != 0) begin
            
                coverage_error = 1'b1;
            
            end 
            previous_reg_write = trace_reg_write;
            previous_rd = trace_rd;
            previous_load = is_lw;

        end

    end


    // =====================================================
    // 17. FUNCTIONAL COVERAGE REPORT
    // =====================================================

    task print_report;

        integer instruction_bins_hit;
        integer branch_bins_hit;
        integer jump_bins_hit;
        integer n;

        begin

            instruction_bins_hit = 0;
            branch_bins_hit = 0;
            jump_bins_hit = 0;


            if (count_add > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_sub > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_and > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_or > 0)   instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_slt > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_addi > 0) instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_lw > 0)   instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_sw > 0)   instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_beq > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_bne > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_jal > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;

            if (count_lui > 0)  instruction_bins_hit =
                instruction_bins_hit + 1;


            if (beq_taken > 0)
                branch_bins_hit = branch_bins_hit + 1;

            if (beq_not_taken > 0)
                branch_bins_hit = branch_bins_hit + 1;

            if (bne_taken > 0)
                branch_bins_hit = branch_bins_hit + 1;

            if (bne_not_taken > 0)
                branch_bins_hit = branch_bins_hit + 1;


            if (jal_forward > 0)
                jump_bins_hit = jump_bins_hit + 1;

            if (jal_backward > 0)
                jump_bins_hit = jump_bins_hit + 1;

            if (jal_rd_zero > 0)
                jump_bins_hit = jump_bins_hit + 1;

            if (jal_rd_nonzero > 0)
                jump_bins_hit = jump_bins_hit + 1;


            $display("");
            $display("================================================");
            $display("       RV32I FUNCTIONAL COVERAGE REPORT");
            $display("================================================");

            $display("Total instruction commits : %0d", total_commits);
            $display("Unsupported instructions  : %0d", unsupported_count);

            $display("");
            $display("INSTRUCTION COVERAGE");

            $display("ADD  : %0d", count_add);
            $display("SUB  : %0d", count_sub);
            $display("AND  : %0d", count_and);
            $display("OR   : %0d", count_or);
            $display("SLT  : %0d", count_slt);

            $display("ADDI : %0d", count_addi);
            $display("LW   : %0d", count_lw);
            $display("SW   : %0d", count_sw);

            $display("BEQ  : %0d", count_beq);
            $display("BNE  : %0d", count_bne);

            $display("JAL  : %0d", count_jal);
            $display("LUI  : %0d", count_lui);

            $display(
                "Instruction bins hit : %0d / 12",
                instruction_bins_hit
            );

            $display(
                "Instruction bin coverage : %0d%%",
                (instruction_bins_hit * 100) / 12
            );


            $display("");
            $display("BRANCH COVERAGE");

            $display("BEQ taken       : %0d", beq_taken);
            $display("BEQ not taken   : %0d", beq_not_taken);

            $display("BNE taken       : %0d", bne_taken);
            $display("BNE not taken   : %0d", bne_not_taken);

            $display("Forward branches  : %0d", branch_forward);
            $display("Backward branches : %0d", branch_backward);

            $display(
                "Branch outcome bins hit : %0d / 4",
                branch_bins_hit
            );


            $display("");
            $display("JUMP COVERAGE");

            $display("Forward JAL  : %0d", jal_forward);
            $display("Backward JAL : %0d", jal_backward);

            $display("JAL rd=x0    : %0d", jal_rd_zero);
            $display("JAL rd!=x0   : %0d", jal_rd_nonzero);

            $display(
                "JAL bins hit : %0d / 4",
                jump_bins_hit
            );


            $display("");
            $display("IMMEDIATE COVERAGE");

            $display("Positive ADDI immediate : %0d",
                     addi_imm_positive);

            $display("Negative ADDI immediate : %0d",
                     addi_imm_negative);

            $display("Zero ADDI immediate     : %0d",
                     addi_imm_zero);


            $display("");
            $display("REGISTER CLASS COVERAGE");

            $display("RS1 classes:");
            $display("x0      : %0d", rs1_class_count[0]);
            $display("x1-x7   : %0d", rs1_class_count[1]);
            $display("x8-x15  : %0d", rs1_class_count[2]);
            $display("x16-x31 : %0d", rs1_class_count[3]);

            $display("RS2 classes:");
            $display("x0      : %0d", rs2_class_count[0]);
            $display("x1-x7   : %0d", rs2_class_count[1]);
            $display("x8-x15  : %0d", rs2_class_count[2]);
            $display("x16-x31 : %0d", rs2_class_count[3]);

            $display("Destination classes:");
            $display("x1-x7   : %0d", rd_class_count[1]);
            $display("x8-x15  : %0d", rd_class_count[2]);
            $display("x16-x31 : %0d", rd_class_count[3]);

            $display("rd=x0 instructions suppressed : %0d",
                     rd_zero_suppressed);

            $display("x0 write violations           : %0d",
                     x0_write_violation);


            $display("");
            $display("MEMORY COVERAGE");

            $display("LW low region  : %0d", lw_low);
            $display("LW mid region  : %0d", lw_mid);
            $display("LW high region : %0d", lw_high);

            $display("SW low region  : %0d", sw_low);
            $display("SW mid region  : %0d", sw_mid);
            $display("SW high region : %0d", sw_high);

            $display("LW unaligned accesses : %0d", lw_unaligned);
            $display("SW unaligned accesses : %0d", sw_unaligned);

            $display("Out-of-range accesses : %0d",
                     memory_out_of_range);

            $display("Unexpected memory writes : %0d",
                     unexpected_memory_write);


            $display("");
            $display("DEPENDENCY COVERAGE");

            $display("RAW dependency on rs1 : %0d", raw_rs1_count);
            $display("RAW dependency on rs2 : %0d", raw_rs2_count);

            $display("Load-use on rs1 : %0d", load_use_rs1_count);
            $display("Load-use on rs2 : %0d", load_use_rs2_count);


            $display("");
            $display("COVERAGE MONITOR STATUS");

            if (unsupported_count == 0 &&
                x0_write_violation == 0 &&
                unexpected_memory_write == 0 &&
                memory_out_of_range == 0) begin

                $display("PASS: No coverage monitor violations");

            end

            else begin

                $display("FAIL: Coverage monitor violations detected");

            end


            $display("================================================");

        end

    endtask


    // =====================================================
    // 18. PRINT REPORT WHEN REQUESTED BY TESTBENCH
    // =====================================================

    initial begin

        wait (report_enable === 1'b1);

        #1;

        print_report();

    end

endmodule
