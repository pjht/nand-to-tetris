# TODO: Make compilation two-phase:
=begin
Phase one will accept an array of tokens and update the tables accordingly.
Phase two wil take the data from the tables and do the actual compilation.
=end

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

def get_index(var)
  vartable=$functable[$cfunc][:vars]
  if vartable.include? var
    return vartable.find_index(var)
  else
    raise CompilationError,"No such variable #{var}"
  end
end

def tokenize_line(line)
  split_line=line.split(" ")
  cmd=split_line.shift.to_sym
  tokens=[]
  if $types.include? cmd
    if /(\w+)\((.*)\) \{/.match(split_line.join(" "))
      tokens.push(:func)
      tokens.push($1.to_sym)
      tokens.push($2)
    else
      tokens.push(:newvar)
      tokens.push(cmd)
      tokens.push(split_line[0].to_sym)
    end
  else
    if split_line[0] == "="
      tokens.push(:assignment)
      tokens.push(cmd.to_sym)
      tokens.push(split_line[1])
    end
    if cmd == "}"
      tokens.push(:endfunc)
    end
  end
  return tokens
end

def phase_one(tokens)
  if $cfunc==nil and tokens[0] != :func
    raise CompilationError, "Code must be inside a fuction"
  end
  case tokens[0]
  when :func
    $functable[tokens[1]]={:vars=>[],:code=>[]}
    $cfunc=tokens[1]
  when :endfunc
    $cfunc=nil
  when :newvar
    $functable[$cfunc][:vars].push(tokens[2])
  else
    $functable[$cfunc][:code].push(tokens)
  end
end

def phase_two
  $functable.each do |func,info|
    vars=info[:vars]
    $outfile.puts "function Main.#{func.to_s} #{vars.length}"
    info[:code].each do |line|
      #puts "Parsing line #{line}"
        action=line.shift
        case action
        when :assignment
          index=get_index(line[0])
          if line[1].is_integer?
            $outfile.puts "push constant #{line[1].to_i}"
            $outfile.puts "pop local #{index}"
          else
            index1=get_index(line[1])
            $outfile.puts "push local #{index1}"
          end
        end
    end
    $outfile.puts "return"
    $outfile.puts(" ")
  end
end

def write_init
  sysfile=File.new("Sys.vm","w")
  sysfile.puts("function Sys.init 0")
  sysfile.puts("call Main.main 0")
  sysfile.puts("label halt")
  sysfile.puts("goto halt")
  sysfile.puts(" ")
end
if !File.exists? "vmprog"
  Dir.mkdir("vmprog")
end
Dir.chdir("vmprog")
$outfile=File.new("Main.vm","w")
write_init()
phase_one(tokenize_line("int main() {"))
phase_one(tokenize_line("int x"))
phase_one(tokenize_line("x = 10"))
phase_one(tokenize_line("int y"))
phase_one(tokenize_line("y = 10"))
phase_one(tokenize_line("}"))
puts $functable
phase_two
