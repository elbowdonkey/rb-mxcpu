require_relative "mxcpu"

RSpec::Matchers.define :have_machine_state do |attr_hash|
  match do |actual|
    actual.instance_variable_get("@acc") == attr_hash[:acc] &&
    actual.instance_variable_get("@inc") == attr_hash[:inc] &&
    actual.instance_variable_get("@pc") == attr_hash[:pc] &&
    actual.instance_variable_get("@registers") == attr_hash[:registers]
  end

  failure_message do |actual|
    message = []
    message << "Expected ACC to be #{expected[:acc]} and got #{actual.instance_variable_get("@acc")}" if expected[:acc] != actual.instance_variable_get("@acc")
    message << "Expected INC to be #{expected[:inc]} and got #{actual.instance_variable_get("@inc")}" if expected[:inc] != actual.instance_variable_get("@inc")
    message << "Expected PC to be #{expected[:pc]} and got #{actual.instance_variable_get("@pc")}" if expected[:pc] != actual.instance_variable_get("@pc")
    message << "Expected Registers to be #{expected[:registers]} and got #{actual.instance_variable_get("@registers")}" if expected[:registers] != actual.instance_variable_get("@registers")

    message.join("\n")
  end
end

RSpec.describe MXCPU do
  let(:verbose) { false }
  let(:options) { {} }
  let(:cpu) { MXCPU.new({verbose: verbose}.merge(options)).tap { |m| m.simulate(program) } }

  describe "simple incrementer" do
    let(:program) { "C2 C2 C2 00" }
    let(:expected_state) { { pc: 3, inc: 3, acc: 0, registers: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] } }
    it { expect(cpu).to have_machine_state expected_state }
  end

  describe "mx sample" do
    let(:program) { "C4 D1 00 D2 00 C2 C5 B3 0B 10 C0 00 D2 00 B1 05 00" }
    let(:expected_state) { { pc: 16, inc: 11, acc: 11, registers: [55, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] } }
    it { expect(cpu).to have_machine_state expected_state }
  end

  describe "when acc eq operand_1" do
    let(:options) { { registers: [{pos: 0, value: 10}] } }
    let(:program) { "B2 00 04 C2 00" }
    let(:expected_state) { { pc: 4, inc: 1, acc: 0, registers: [10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] } }
    it { expect(cpu).to have_machine_state expected_state }
  end

  describe "MX Exercise 1" do
    let(:supplied_number_a) { 78 }
    let(:supplied_number_b) { 103 }
    let(:expected_answer) { supplied_number_a + supplied_number_b }
    let(:options) { { registers: [{pos: 14, value: supplied_number_a}, {pos: 15, value: supplied_number_b}] } }
    let(:program) { "C0 0E C0 0F D2 00 00" }
    let(:expected_state) { { pc: 6, inc: 0, acc: 181, registers: [expected_answer, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, supplied_number_a, supplied_number_b] } }
    it { expect(cpu).to have_machine_state expected_state }
  end

  describe "Long form MX sample" do
    let(:program) do
      <<~PROGRAM
      00: C4           # Reset the counter
      01: D1 00        # Set accumulator to value
      03: D2 00        # Store accumulator in first memory slot (0x00)
      05: C2           # Loop begin.  Increment counter, should now be 1
      06: C5           # Transfer counter to accumulator
      07: B3 0B 10     # Check if accumulator is equal to 11, if so, jump to end of loop
      0A: C0 00        # Add accumulator with value in first memory slot (0x00)
      0C: D2 00        # Store accumulator back into first memory slot (0x00)
      0E: B1 05        # Jump to top of loop
      10: 00           # Halt program
      PROGRAM
    end

    let(:options) { {verbose: false} }
    let(:expected_state) { { pc: 16, inc: 11, acc: 11, registers: [55, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] } }
    it { expect(cpu).to have_machine_state expected_state }
  end

  describe "MX Exercise 2" do
    let(:program) do
      <<~PROGRAM
      00: B2 0F 1D   # return 0 if n = 0
      03: D1 01      # @acc = 1
      05: D2 02      # @registers[2] = @acc
      07: C5         # @acc = @inc
      08: D0 02      # @acc = @registers[2] LOOP START
      0A: C0 01      # @acc += @registers[1]
      0C: D2 00      # @registers[0] = @acc
      0E: D0 01      # @acc = @registers[1]
      10: D2 02      # @registers[2] = @acc
      12: D0 00      # @acc = @registers[0]
      14: D2 01      # @registers[1] = @acc
      16: C2         # @inc += 1
      17: C5         # @acc = @inc
      18: B2 0F 1D   # @acc == @registers[15] BREAK JMP TO END
      1B: B1 08      # JUMP TO LOOP START
      1D: 00         # HALT
      PROGRAM
    end

    context "when seed is 0" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 0}] } }
      let(:expected_state) { { pc: 29, inc: 0, acc: 0, registers: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 1" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 1}] } }
      let(:expected_state) { { pc: 29, inc: 1, acc: 1, registers: [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 2" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 2}] } }
      let(:expected_state) { { pc: 29, inc: 2, acc: 2, registers: [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 3" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 3}] } }
      let(:expected_state) { { pc: 29, inc: 3, acc: 3, registers: [2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 5" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 5}] } }
      let(:expected_state) { { pc: 29, inc: 5, acc: 5, registers: [5, 5, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 9" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 9}] } }
      let(:expected_state) { { pc: 29, inc: 9, acc: 9, registers: [34, 34, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 7" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 7}] } }
      let(:expected_state) { { pc: 29, inc: 7, acc: 7, registers: [13, 13, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7] } }
      it { expect(cpu).to have_machine_state expected_state }
    end

    context "when seed is 12" do
      let(:options) { {verbose: false, registers: [{pos: 15, value: 12}] } }
      let(:expected_state) { { pc: 29, inc: 12, acc: 12, registers: [144, 144, 89, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12] } }
      it { expect(cpu).to have_machine_state expected_state }
    end
  end

  describe  "helper methods" do
    describe "#to_hash" do
      let(:program) { "C2 D2 01 B3 05 06 00" }
      let(:expected_hash) do
        {
          "00" => "C2",
          "01" => "D2 01",
          "03" => "B3 05 06",
          "06" => "00"
        }
      end
      it { expect(cpu.to_hash).to eq expected_hash }
    end

    describe "square root" do
      let(:program) do
        <<~PROGRAM
        00: B2 0F 12   # if @acc == @registers[15] goto halt LOOP START
        03: D2 01      # registers[1] = acc
        05: C5         # acc = inc
        06: C0 01      # acc += registers[1]
        08: D2 01      # registers[1] = acc
        0A: C5         # acc = inc
        0B: C0 01      # acc += registers[1]
        0D: C1 01      # acc += 1
        0F: C2         # inc += 1
        10: B1 00      # GOTO LOOP START
        12: C5         # acc = inc
        13: D2 00      # registers[0] = acc
        15: 00         # Halt program
        PROGRAM
      end

      describe "whole squares" do
        describe "sqrt(9)" do
          let(:options) { {verbose: false, registers: [{pos: 15, value: 9}] } }
          it { expect(cpu.registers[0]).to eq 3 }
        end

        describe "sqrt(16)" do
          let(:options) { {verbose: false, registers: [{pos: 15, value: 16}] } }
          it { expect(cpu.registers[0]).to eq 4 }
        end

        describe "sqrt(25)" do
          let(:options) { {verbose: false, registers: [{pos: 15, value: 25}] } }
          it { expect(cpu.registers[0]).to eq 5 }
        end

        describe "sqrt(99)" do
          let(:options) { {verbose: false, registers: [{pos: 15, value: 9801}] } }
          it { expect(cpu.registers[0]).to eq 99 }
        end
      end

      describe "un-whole-y squares" do
        describe "sqrt(17)" do
          let(:options) { {verbose: false, registers: [{pos: 15, value: 17}] } }
          it { expect(cpu.registers[0]).to eq 0 }
        end
      end
    end
  end
end
