import fileinput

def find_nex_prefix():

  lineList = list()
  default_subnet_prefix = '10.250.'
  third_digit = 0
  
  #Read all vnet prefiex in list
  with fileinput.input(files=('files/prefixfile')) as f:
    for line in f:
      token = line[0:(line.rindex('.'))]
      lineList.append(token)
  f.close

  vnet_prefix = default_subnet_prefix + str(third_digit)
  while ( vnet_prefix in lineList):

    third_digit += 1
    vnet_prefix = default_subnet_prefix + str(third_digit)
  
  print(vnet_prefix)


find_nex_prefix()
