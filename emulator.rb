$debug=true
$pfdebug=true
$fdebug=false
$mname="the initialization code"
$arg=[]
$local=[]
$static=[]
$pointer=[nil,nil]
$temp=[nil,nil,nil,nil,nil,nil,nil,nil]
$heap=[]
$stack=[]
$labels={}
$gstack=[]
$funcs={}
def runvmcommand(cmd,lno)
  def putsd(arg)
    if $debug
      puts arg
    end
  end
  def putspfd(arg)
    if $pfdebug or $debug
      puts arg
    end
  end
  def putsdf(arg)
    if $fdebug
      puts arg
    end
  end
  def raised(etype,arg=nil)
    if arg==nil
      raise etype
    else
      raise etype,arg
    end
  end
  def checklistbounds(lname,list,index,lno=nil)
    if index > list.length-1
      if lno
        raised "Line #{lno}: Index #{index} is out of bounds for #{lname}"
      else
        raised "Index #{index} is out of bounds for #{lname}"
      end
      exit
    end
  end
  oldstack=$stack
  funcdef=false
  pflowc=false
  cmd=cmd.split(" ")
  op=cmd.shift
  putsd "#{op} "+cmd.join(" ") unless op == "function" or op==nil or op=="#"
  case op
  when "add"
    $stack.push($stack.pop+$stack.pop)
  when "sub"
    second=$stack.pop
    first=$stack.pop
    $stack.push(first-second)
  when "neg"
    $stack.push(-$stack.pop)
  when "push"
    cmd[1]=cmd[1].to_i
    case cmd[0]
    when "argument"
      checklistbounds("arg",$arg,cmd[1],lno)
      $stack.push($arg[cmd[1]])
    when "local"
      checklistbounds("local",$local,cmd[1],lno)
      $stack.push($local[cmd[1]])
    when "static"
      $stack.push($static[cmd[1]])
    when "constant"
      $stack.push(cmd[1])
    when "this"
      $stack.push($heap[$pointer[0]+cmd[1]])
    when "that"
      $stack.push($heap[$pointer[1]+cmd[1]])
    when "temp"
      checklistbounds("temp",$temp,cmd[1],lno)
      $stack.push($temp[cmd[1]])
    when "pointer"
      checklistbounds("pointer",$pointer,cmd[1],lno)
      $stack.push($pointer[cmd[1]])
    end
  when "pop"
    cmd[1]=cmd[1].to_i
    case cmd[0]
    when "local"
      checklistbounds("local",$local,cmd[1],lno)
      $local[cmd[1]]=$stack.pop
      putsd "New local:#{$local}"
    when "static"
      $static[cmd[1]]=$stack.pop
      putsd "New static:#{$static}"
    when "this"
      $heap[$pointer[0]+cmd[1]]=$stack.pop
      putsd "New heap:#{$heap}"
    when "that"
      $heap[$pointer[1]+cmd[1]]=$stack.pop
      putsd "New heap:#{$heap}"
    when "pointer"
      checklistbounds("pointer",$pointer,cmd[1],lno)
      $pointer[cmd[1]]=$stack.pop
      putsd "New pointer:#{$pointer}"
    when "temp"
      checklistbounds("temp",$temp,cmd[1],lno)
      $temp[cmd[1]]=$stack.pop
      putsd "New temp:#{$temp}"
    end
  when "label"
    $labels[cmd[0]]=lno+1
    putsd "New labels:#{$labels}"
  when "goto"
    pflowc=true
    nlno=$labels[cmd[0]]
  when "if-goto"
    pflowc=true
    if $stack.pop == 0
      nlno=$labels[cmd[1]]
    end
  when "call"
    if $funcs[cmd[0]]==nil
      puts "Line #{lno}: Function #{cmd[0]} is undefined"
      exit
    end
    pflowc=true
    args=[]
    i=cmd[1].to_i-1
    if i == -1
      i=0
    else
      while i >= 0
        args[i]=$stack.pop
        i-=1
      end
    end
    hash={"local"=>$local,"arg"=>$arg,"pointer"=>$pointer,"stack"=>$stack,"ret"=>lno+1,"mname"=>$mname}
    $gstack.push(hash)
    $arg=args
    $local=Array.new($funcs[cmd[0]][1])
    nlno=$funcs[cmd[0]][0]
    $mname=cmd[0]
    puts "Transferring control from #{hash["mname"]} to #{$mname}"
    putsd "New arg:#{$arg}"
    putsd "New local:#{$local}"
    putsd "Stack is now cleared"
  when "function"
    funcdef=true
    $funcs[cmd[0]]=[lno+1,cmd[1].to_i]
    putsdf "New funcs:#{$funcs}"
  when "return"
    pflowc=true
    hash=$gstack.pop
    putspfd "Transferring control from #{$mname} to method #{hash["mname"]}"
    ostack=$stack
    $stack=hash["stack"]
    rval=ostack.pop
    unless rval == nil
      $stack.push(rval)
    end
    $local=hash["local"]
    $arg=hash["arg"]
    $pointer=hash["pointer"]
    nlno=hash["ret"]
    $mname=hash["mname"]
    putsd "New arg:#{$arg}"
    putsd "New local:#{$local}"
    putsd "New pointer:#{$pointer}"
  when "halt"
    return lno,funcdef,true
  end
  unless pflowc
    nlno=lno+1
  end
  putsd "New stack:#{$stack}" unless op=="function" or op=="call" or (oldstack==[] and $stack==[])
  undef checklistbounds
  undef raised
  undef putsd
  undef putspfd
  undef putsdf
  return nlno,funcdef,false
end
def runprog(prog)
  prog=prog.split("\n")
  i=1
  temp={}
  prog.each do |line|
    temp[i]=line
    i+=1
  end
  prog=temp
  lno=1
  while lno <= prog.length
    lno,funcdef,halt=runvmcommand(prog[lno],lno)
    break if halt
    if funcdef
      i=lno
      while i <= prog.length
        if prog[i]=="return"
          lno=i+1
          break
        end
        i+=1
      end
    end
  end
  puts "Program halted. Heap:#{$heap} "
  if $stack[0]
    puts "Return value:#{$stack[0]}"
  end
end
prog=<<-END
# Memory class

function Memory.alloc 0
  push static 0
  pop temp 0
  push static 0
  push argument 0
  add
  pop static 0
  push temp 0
return

# Array class

function x[y]=z 0
  push argument 0
  push argument 1
  add
  pop pointer 0
  push argument 2
  pop this 0
return

function x[y] 0
  push argument 0
  push argument 1
  add
  pop pointer 0
  push this 0
return

# Test class
function Test.new 0
  # this=Memory.alloc(2)
  push constant 1
  call Memory.alloc 1
  pop pointer 0
  # this.var=0
  push constant 0
  pop this 0
  # this.var2=0
  push constant 0
  pop this 1
  # push return value
  push pointer 0
return
function Test.var= 0
  push argument 0
  pop pointer 0
  push argument 1
  pop this 0
return

function Test.var 0
  push argument 0
  pop pointer 0
  push this 0
return
function Test.var2= 0
  push argument 0
  pop pointer 0
  push argument 1
  pop this 1
return

function Test.var2 0
  push argument 0
  pop pointer 0
  push this 1
return

# Main class
function Main.main 1
  # Set t=Test.new
  call Test.new 0
  pop local 0
  # t.var=10
  push local 0
  push constant 10
  call Test.var= 2
  # t.var2=11
  push local 0
  push constant 11
  call Test.var2= 2
return

# Sys class
function Sys.init 0
  call Main.main
return
# Init code
push constant 0
pop static 0
call Sys.init 0
halt
END
boundtest=<<-END
pop pointer 2
END
runprog(prog)
