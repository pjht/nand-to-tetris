$types=[:int,:void]
$functable={}
$cfunc=nil
$outfile=nil

class CompilationError < StandardError; end

class String
  def is_integer?
    self.to_i.to_s == self
  end
end

def is_var(var)
  return false if var.class!=Symbol
  vartable=$functable[$cfunc][:vars]
  argtable=$functable[$cfunc][:args]
  if vartable.include? var or argtable.include? var
    return true
  else
    return false
  end
end

def get_index(var)
  vartable=$functable[$cfunc][:vars]
  argtable=$functable[$cfunc][:args]
  if vartable.include? var
    return vartable.find_index(var),"local"
  else
    if argtable.include? var
      return argtable.find_index(var),"argument"
    end
    raise CompilationError,"No such variable #{var}"
  end
end

def push(obj)
  if obj.class == Symbol
    index,segment=get_index(obj)
    $outfile.puts "push #{segment} #{index}"
  elsif obj.class == String
    if obj.is_integer?
      $outfile.puts "push constant #{obj}"
    elsif is_var(obj.to_sym)
      index,segment=get_index(obj.to_sym)
      $outfile.puts "push #{segment} #{index}"
    else
      raise CompilationError, "Cannot push #{obj}, is not a variable or a number."
    end
  elsif obj.is_a? Numeric
    $outfile.puts "push constant #{obj}"
  else
    raise CompilationError, "Cannot push #{obj}, is not a variable or a number."
  end
end

def pop(var)
  if var.class != Symbol and !is_var(var)
    raise CompilationError, "Cannot push #{var}, is not a variable."
  end
  index,segment=get_index(var)
  $outfile.puts "pop #{segment} #{index}"
end

def tokenize_line(line)
  split_line=line.split(" ")
  cmd=split_line.shift.to_sym
  tokens=[]
  if $types.include? cmd
    if /(\w+)\((.*)\) \{/.match(split_line.join(" "))
      tokens.push(:func)
      tokens.push(cmd)
      tokens.push($1.to_sym)
      args=[]
      $2.split(",").each do |arg|
        temp=arg.split(" ")
        args.push(temp[1].to_sym)
      end
      tokens.push(args)
    else
      tokens.push(:newvar)
      tokens.push(cmd)
      tokens.push(split_line[0].to_sym)
    end
  else
    if /(\w+)\((.*)\)/.match(cmd)
      tokens.push(:call)
      tokens.push($1.to_sym)
      args=[]
      $2.split(",").each do |arg|
        args.push(arg.to_sym)
      end
      tokens.push(args)
    end
    if split_line[0] == "="
      tokens.push(:assignment)
      tokens.push(cmd)
      tokens.push(split_line[1])
    end
    if cmd == "}"
      tokens.push(:endfunc)
    end
    if cmd == :return
      tokens.push(:return)
      tokens.push(split_line[0])
    end
  end
  return tokens
end

def phase_one(tokens)
  if $cfunc==nil and tokens[0] != :func
    raise CompilationError, "Code must be inside a fuction, for line #{tokens}"
  end
  case tokens[0]
  when :func
    $functable[tokens[2]]={:vars=>[],:code=>[], :type=>tokens[1], :args=>tokens[3]}
    $cfunc=tokens[2]
  when :endfunc
    $cfunc=nil
  when :newvar
    $functable[$cfunc][:vars].push(tokens[2])
  else
    $functable[$cfunc][:code].push(tokens) if tokens != []
  end
end

def phase_two
  $functable.each do |func,info|
    $cfunc=func
    vars=info[:vars]
    $outfile.puts "function Main.#{func.to_s} #{vars.length}"
    info[:code].each do |line|
      action=line.shift
      case action
      when :assignment
        if line[1].is_integer? or is_var(line[1])
          push(line[1])
        else
          parsed_line=tokenize_line(line[1])
          parsed_line=[""] if parsed_line==nil
          if parsed_line[0]==:call
            parsed_line[2].each do |arg|
              push(arg)
            end
            nargs=$functable[parsed_line[1]][:args].length
            $outfile.puts "call Main.#{parsed_line[1]} #{nargs}"
          else
            if line[1].include? "+"
              operands=line[1].split("+")
              op="add"
            end
            if line[1].include? "-"
              operands=line[1].split("-")
              op="sub"
            end
            push(operands[0])
            push(operands[1])
            $outfile.puts(op)
          end
        end
        pop(line[0])
      when :call
        line[1].each do |arg|
          push(arg)
        end
        nargs=$functable[line[0]][:args].length
        $outfile.puts "call Main.#{line[0]} #{nargs}"
      when :return
        push(line[0])
      end
    end
    if info[:type]==:void
      push(0)
    end
    $outfile.puts "return"
    $outfile.puts("")
  end
end

def write_init
  sysfile=File.new("Sys.vm","w")
  sysfile.puts("function Sys.init 0")
  sysfile.puts("call Main.main 0")
  sysfile.puts("label halt")
  sysfile.puts("goto halt")
  sysfile.puts("")
end

if !File.exists? "vmprog"
  Dir.mkdir("vmprog")
  Dir.chdir("vmprog")
  write_init()
else
  Dir.chdir("vmprog")
end

$outfile=File.new("Main.vm","w")

prog=<<-END
void main() {
int x
x = 10
int y
y = x+17
int z
z = testfunc(y)
}
int testfunc(int c) {
int x
x = c-7
return x
}
END

prog.each_line do |line|
  phase_one(tokenize_line(line))
end

puts $functable

phase_two()
