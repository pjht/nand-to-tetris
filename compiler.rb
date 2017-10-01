def compile(prog)
  temp={}
  nextvar=0
  code=""
  lines=[]
  i=0
  prog.split(";").each do |line|
    lines[i]=line.strip
    i+=1
  end
  lines.each do |line|
    line=line.split(" ")
    if line[0] == "var"
      temp[line[2]]=nextvar
      nextvar+=1
    end
    if line[0] == "let"
      code += "push constant #{line[3]}\npop temp #{temp[line[1]]}"
    end
  end
  return temp,code
end
