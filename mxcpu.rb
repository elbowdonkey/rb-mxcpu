require 'pry'

class MXCPU
  attr_accessor :acc
  attr_accessor :inc
  attr_accessor :pc
  attr_accessor :registers
  attr_accessor :bytes
  attr_accessor :cycles
  attr_accessor :descriptions

  def initialize(opts = {})
    @pc = opts[:pc] || 0
    @inc = opts[:inc] || 0
    @acc = opts[:acc] || 0
    @cycles = 0
    @verbose = opts[:verbose] || false
    @registers = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    @current_op = nil
    @labels = {}
    @instructions = []
    @comments = []

    if opts[:registers]
      opts[:registers].each do |register|
        @registers[register[:pos]] = register[:value]
      end
    end
  end

  def vizualize
    puts current_state_as_string(:decimal) if @verbose
  end

  def simulate(program)
    if program.scan("\n").any?
      # long form
      @bytes = []
      program.split(/\n/).each do |line|
        address, instruction, comment = line.scan(/(^[0-9A-Z][0-9A-Z]):(.*)(#.*$?)/i).flatten
        @bytes << instruction.strip
        @comments << comment
      end
      @bytes = @bytes.join(" ").split(" ")
    else
      @bytes = program.split(/\s/)
    end

    @bytes[@bytes.size - 1] = "halt" if @bytes.last == "00"

    while true
      @cycles += 1
      break if @cycles > 1000
      break if @bytes[@pc + 1].nil? # same as halt
      step
    end
  end

  def step
    if self.respond_to? @bytes[@pc].to_sym
      operation = @bytes[@pc].to_sym
    else
      operation = (@bytes[@pc].hex).to_s(16).downcase.to_sym
    end

    operand_1 = !@bytes[@pc + 1].nil? ? @bytes[@pc + 1].hex : nil
    operand_2 = !@bytes[@pc + 2].nil? ? @bytes[@pc + 2].hex : nil

    @current_op = [operation, operand_1, operand_2]

    self.send(operation, operand_1, operand_2)
    vizualize
  end

  def current_state_as_string(format = :hex)
    output = []

    base = 10 if format == :decimal
    base = 16 if format == :hex
    prefix = "" if format == :decimal
    prefix = "0x" if format == :hex

    memory_results = @registers.map {|m| "#{prefix}#{m.to_s(base)}" }

    current_op = [@current_op[0]]
    current_op << @current_op[1].to_s(16)
    current_op << @current_op[2].to_s(16) if !@current_op[2].nil?

    current_op = current_op.join(" ")

    stats = {
      cycle: @cycles,
      op: "#{current_op}",
      pc: "#{prefix}#{@pc.to_s(base)}",
      inc: "#{prefix}#{@inc.to_s(base)}",
      acc: "#{prefix}#{@acc.to_s(base)}",
      memory: "#{memory_results.join(",")}"
    }

    stats.each do |key, value|
      output << "#{key.to_s.upcase.rjust(10)}: #{value}"
    end

    output << "\n"

    output.join("\n")
  end

  def to_hash
    hsh = {}
    @bytes.each_with_index do |byte, index|
      key = "%02x" % index
      hsh[key] = [byte, @bytes[index + 1]]  if ["B1", "C0", "C1", "D0", "D1", "D2"].include? byte
      hsh[key] = [byte, @bytes[index + 1], @bytes[index + 2]]  if ["B2", "B3"].include? byte
      hsh[key] = [byte] if ["C2", "C3", "C4", "C5", "C6"].include? byte
      hsh[key] = ["00"] if byte == "halt" && index == @bytes.size-1
      hsh[key] = hsh[key].join(" ") if !hsh[key].nil?
    end
    hsh
  end

  def to_s
    @bytes.join(" ")
  end

  def to_longform
    program = []
    index = 0
    to_hash.each do |key, value|
      program << "#{key.upcase}: #{value.ljust(10)} #{@comments[index]}"
      index += 1
    end

    program.join("\n")
  end

  # standard operations

  def b1(*args)
    operand_1 = args[0]
    @pc = operand_1
  end

  def b2(*args)
    operand_1 = args[0]
    operand_2 = args[1]
    if @registers[operand_1] == @acc
      @pc = operand_2
    else
      @pc += 3
    end
  end

  def b3(*args)
    operand_1 = args[0]
    operand_2 = args[1]

    if @acc == operand_1
      @pc = operand_2
    else
      @pc += 3
    end
  end

  def c0(*args)
    operand_1 = args[0]
    @acc += @registers[operand_1]
    @pc += 2
  end

  def c1(*args)
    operand_1 = args[0]
    @acc += operand_1
    @pc += 2
  end

  def c2(*args)
    @inc += 1
    @pc += 1
  end

  def c3(*args)
    @inc -= 1
    @pc += 1
  end

  def c4(*args)
    @inc = 0
    @pc += 1
  end

  def c5(*args)
    @acc = @inc
    @pc += 1
  end

  def c6(*args)
    @inc = @acc
    @pc += 1
  end

  def d0(*args)
    operand_1 = args[0]
    @acc = @registers[operand_1]
    @pc += 2
  end

  def d1(*args)
    operand_1 = args[0]
    @acc = operand_1
    @pc += 2
  end

  def d2(*args)
    operand_1 = args[0]
    @registers[operand_1] = @acc
    @pc += 2
  end

  def halt(*args)
    @pc = @bytes.size - 1
  end
end
