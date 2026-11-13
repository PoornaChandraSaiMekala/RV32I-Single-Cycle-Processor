# Design and Verification of a Single-Cycle RV32I-Subset Processor

A 32-bit single-cycle processor implementing a selected 12-instruction subset of RISC-V RV32I, supported by an independent reference model, a self-checking testbench, functional coverage, and RTL timing optimization.

> **Project scope:** RTL simulation, Vivado synthesis, and synthesis-stage timing analysis. Physical place-and-route, bitstream generation, and Basys 3 board testing are not part of the completed work.

## Project at a glance

|Item|Details|
|-|-|
|Processor organization|Single-cycle|
|Data width|32 bits|
|Instruction subset|12 operations|
|Register file|32 × 32 bits; x0 reads as zero|
|Instruction memory|256 × 32 bits|
|Data memory|256 × 32 bits (1 KiB)|
|Target device|Xilinx Artix-7 `xc7a35tcpg236-1`|
|Tool version in reported run|Vivado 2026.1|
|Clock constraint|10 ns (100 MHz)|
|Verification|Reference-model-based self-checking testbench|
|Regression result|15/15 tests passed in the supplied run|

## Supported instructions

|Type|Instructions|
|-|-|
|R-type|ADD, SUB, AND, OR, SLT|
|I-type|ADDI, LW|
|S-type|SW|
|B-type|BEQ, BNE|
|J-type|JAL|
|U-type|LUI|

This is a selected subset, not a complete implementation of the RV32I specification.

## Architecture

The top-level processor integrates the following blocks:

* Program counter and next-PC selection logic
* Instruction memory
* Control unit and ALU control
* Register file
* Immediate generator
* ALU and branch comparison logic
* Data memory and address-range checker
* Writeback selection logic

The processor remains single-cycle; no pipeline stages are introduced.

## Repository structure

RV32I-Single-Cycle-Processor/

│

├── README.md

│

├── RTL/

│   ├── rv32i\_processor.v

│   ├── alu.v

│   ├── alu\_control.v

│   ├── branch\_control.v

│   ├── control\_unit.v

│   ├── data\_memory.v

│   ├── addr\_range\_check.v

│   ├── immediate\_generator.v

│   ├── instruction\_memory.v

│   ├── next\_pc\_logic.v

│   ├── pc.v

│   ├── register\_file.v

│   └── writeback\_mux.v

│

├── Verification/

│   ├── rv32i\_reference\_model.sv

│   ├── rv32i\_functional\_coverage.sv

│   ├── tb\_rv32i\_unified.sv

│   ├── tb\_addr\_range\_check.sv

│   └── tb\_data\_memory\_hwreset.sv

│

├── Program/

│   └── program.mem

│

├── Constraints/

│   └── rv32i\_processor.xdc

│

├── Documentation/

│   └── RV32I\_Project\_Technical\_Documentation.pdf

│

└── Results/

&#x20;   ├── regression\_log.txt

&#x20;   ├── synthesis\_utilization.rpt

&#x20;   ├── timing\_summary.rpt

&#x20;   └── hardware\_reset\_log.txt

## Verification approach

The verification environment uses a reference model that maintains expected architectural state independently of the DUT. The unified self-checking testbench checks execution against the model, while a separate functional-coverage monitor tracks instruction and selected control-flow and safety scenarios.

The supplied regression transcript reports:

* 15 of 15 regression tests passed.
* 385 instruction commits.
* Supported instruction coverage: 12/12 bins.
* Branch outcome coverage: 4/4 bins.
* JAL coverage: 4/4 bins.
* No reported out-of-range memory accesses, x0 protection violations, unexpected memory writes, or coverage-monitor violations.
* The standalone data-memory hardware-reset test reported zero errors.

These are results from the supplied test environment and test programs. They are not a formal proof over all possible programs.

## RTL optimization work

The optimized RTL includes these implementation changes:

1. **Dedicated memory-address calculation:** Separates the data-memory address calculation from the general ALU result path.
2. **Direct branch equality comparison:** Computes operand equality directly for BEQ/BNE decisions.
3. **Distributed data memory with valid-bit reset handling:** Uses a valid vector to provide logical reset behavior without resetting every distributed-memory storage bit in the hardware synthesis path.
4. **Split valid-bit write decoding:** Structures the valid-bit update decode into partial index decoders.

These changes retain the single-cycle organization. The project does not claim that area minimization was the primary objective.

## Reported synthesis and timing results

The following values are from the supplied Vivado synthesis reports for the optimized source snapshot.

### Resource utilization

|Resource|Used|Utilization|
|-|-:|-:|
|Slice LUTs|1,362|6.55%|
|LUT as logic|1,234|5.93%|
|LUT as memory|128|1.33%|
|Slice registers|702|1.69%|
|Distributed RAM primitives|128 RAMS64E|—|
|Block RAM|0|0%|
|DSP|0|0%|
|CARRY4|34|—|
|BUFG|1|3.13%|

### Timing summary

|Metric|Reported result|
|-|-:|
|Clock period|10.000 ns|
|WNS|+0.915 ns|
|TNS|0.000 ns|
|Setup failing endpoints|0|
|WHS|+0.113 ns|
|THS|0.000 ns|
|Hold failing endpoints|0|
|WPWS|+3.750 ns|

The supplied synthesized-design timing report meets the 10 ns clock constraint. The slack-based estimate of the limiting setup path is 9.085 ns, or approximately 110.1 MHz. This is an estimate from synthesis timing, not a guaranteed post-route frequency or measured hardware result.

The report also lists 202 bonded IOBs against 106 available. The top-level design exposes a wide trace interface intended for verification. This is a board-integration limitation if all trace ports were to be brought to Basys 3 pins; board implementation is outside this project's scope.

## Running the project

The repository contains the RTL, verification sources, memory initialization file, and XDC used in the project package. To reproduce the work:

1. Open Vivado and create or open a Verilog project.
2. Select the target part `xc7a35tcpg236-1`.
3. Add the files under `RTL/` as design sources.
4. Add the required files under `Verification/` as simulation sources.
5. Ensure `program.mem` is available at the path expected by `$readmemh` in `instruction_memory.v` (for example, set the simulation working directory or copy the file into that directory).
6. Add `Constraints/rv32i_processor.xdc` for the 100 MHz clock constraint.
7. Set `rv32i_processor` as the synthesis top and `tb_rv32i_unified` as the simulation top when running the corresponding flows.
8. Run the unified regression and then run synthesis.
9. Save the reports generated by the exact source snapshot and Vivado run.

The precise simulation compile order and simulator-specific settings should be checked in the project if the testbench uses simulator-specific SystemVerilog features. Do not treat this README as a substitute for the simulator's compile log.

## Constraints and limitations

* Only the 12 listed instruction operations are implemented.
* The design is single-cycle and does not include pipelining.
* Instruction and data memories are each 256 × 32 bits.
* Only word load/store operations are included; byte and halfword operations are not implemented.
* The coverage environment treats out-of-range data-memory accesses as errors; the reported regression contains none.
* The supplied RTL's out-of-range load behavior is not claimed to match the reference model for invalid addresses. Such accesses are outside the legal tested workload.
* The reported timing is synthesis-stage timing, not post-route timing.
* No bitstream generation, physical FPGA programming, or board-level validation is claimed.

## Suggested citation / attribution

If you reuse this repository or adapt the design, retain appropriate attribution to the original project author and identify any modifications you make. Add external references for any ISA or tool documentation used in future revisions.

## License

No license has been assigned yet. Unless a license is added, normal copyright restrictions apply; do not assume the repository is open for unrestricted reuse.

