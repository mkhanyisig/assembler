# Template by Bruce A. Maxwell, 2015
#
# implements a simple assembler for the following assembly language
# 
# - One instruction or label per line.
#
# - Blank lines are ignored.
#
# - Comments start with a # as the first character and all subsequent
# - characters on the line are ignored.
#
# - Spaces delimit instruction elements.
#
# - A label ends with a colon and must be a single symbol on its own line.
#
# - A label can be any single continuous sequence of printable
# - characters; a colon or space terminates the symbol.
#
# - All immediate and address values are given in decimal.
#
# - Address values must be positive
#
# - Negative immediate values must have a preceeding '-' with no space
# - between it and the number.
#

# Language definition:
#
# LOAD D A	 - load from address A to destination D
# LOADA D A	 - load using the address register from address A + RE to destination D
# STORE S A	 - store value in S to address A
# STOREA S A - store using the address register the value in S to address A + RE
# BRA L		 - branch to label A
# BRAZ L	 - branch to label A if the CR zero flag is set
# BRAN L	 - branch to label L if the CR negative flag is set
# BRAO L	 - branch to label L if the CR overflow flag is set
# BRAC L	 - branch to label L if the CR carry flag is set
# CALL L	 - call the routine at label L
# RETURN	 - return from a routine
# HALT		 - execute the halt/exit instruction
# PUSH S	 - push source value S to the stack
# POP D		 - pop form the stack and put in destination D
# OPORT S	 - output to the global port from source S
# IPORT D	 - input from the global port to destination D
# ADD A B C	 - execute C <= A + B
# SUB A B C	 - execute C <= A - B
# AND A B C	 - execute C <= A and B	 bitwise
# OR  A B C	 - execute C <= A or B	 bitwise
# XOR A B C	 - execute C <= A xor B	 bitwise
# SHIFTL A C - execute C <= A shift left by 1
# SHIFTR A C - execute C <= A shift right by 1
# ROTL A C	 - execute C <= A rotate left by 1
# ROTR A C	 - execute C <= A rotate right by 1
# MOVE A C	 - execute C <= A where A is a source register
# MOVEI V C	 - execute C <= value V
#

# 2-pass assembler
# pass 1: read through the instructions and put numbers on each instruction location
#		  calculate the label values
#
# pass 2: read through the instructions and build the machine instructions
#

# Mkhanyisi Gamedze
# CS232 Project 8 : Assembler
# 

import sys

# NO NEED TO CHANGE
# converts d to an 8-bit 2-s complement binary value
def dec2comp8( d, linenum ):
	try:
		if d > 0:
			l = d.bit_length()
			v = "00000000"
			v = v[0:8-l] + format( d, 'b')
		elif d < 0:
			dt = 128 + d
			l = dt.bit_length()
			v = "10000000"
			v = v[0:8-l] + format( dt, 'b')[:]
		else:
			v = "00000000"
	except:
		print 'Invalid decimal number on line %d' % (linenum)
		exit()

	return v

# DEFAULT NO NEED TO CHANGE
# converts d to an 8-bit unsigned binary value
def dec2bin8( d, linenum ):
	if d > 0:
		l = d.bit_length()
		v = "00000000"
		v = v[0:8-l] + format( d, 'b' )
	elif d == 0:
		v = "00000000"
	else:
		print 'Invalid address on line %d: value is negative' % (linenum)
		exit()

	return v


# Tokenizes the input data, discarding white space and comments
# returns the tokens as a list of lists, one list for each line.
#
# The tokenizer also converts each character to lower case.
def tokenize( fp ):
	tokens = []

	# start of the file
	fp.seek(0)

	lines = fp.readlines()

	# strip white space and comments from each line
	for line in lines:
		ls = line.strip()
		uls = ''
		for c in ls:
			if c != '#':
				uls = uls + c
			else:
				break

		# skip blank lines
		if len(uls) == 0:
			continue

		# split on white space
		words = uls.split()

		newwords = []
		for word in words:
			newwords.append( word.lower() )

		tokens.append( newwords )
	print "done tokenizing\n"
	return tokens


# reads through the file and returns a dictionary of all location
# labels with their line numbers
def pass1( tokens ):
	# figure out what line number corresponds to each symbol
	
	# function variables 
	tkns = [] # actual instructions
	dict = {}
	index = 0
	print "branching addresses"
	for t in tokens:
		# check symbol ID that characterizes branch symbol ":"
		if t[0][-1] == ":" :
			# capture that token excluding ":"
			dict[t[0][:-1]]=index
			print " "+t[0]+"   \n"
		else:
			tkns.append(t)
			index+=1
	print "*****"
	
	# return (tokens, labels dictionary)
	return tkns , dict

# More thorough. Reads through tokens and creates machine assembly code
def pass2( tokens, labels ):
	# Register Symbol tables dictionary (case insensitive, so all lower case) (3 bit representation)
	table_b ={'ra' : '000', 'rb' : '001', 'rc':'010','rd': '011','re':'100','sp': '101'}
	table_c={'ra' : '000', 'rb' : '001', 'rc':'010','rd': '011','re':'100','sp': '101','pc':'110','cr':'111'}
	table_d={'ra' : '000', 'rb' : '001', 'rc':'010','rd': '011','re':'100','sp': '101','pc':'110','ir':'111'}
	table_e={'ra' : '000', 'rb' : '001', 'rc':'010','rd': '011','re':'100','sp': '101','zeros':'110','ones':'111'}
	
	# the machine instructions
	
	# setup format
	ass_txt = "DEPTH=256;\nWIDTH=16;\nADDRESS_RADIX=HEX;\nDATA_RADIX=BIN;\nCONTENT\nBEGIN\n"
	
	# begin writing instructions for each token
	index=0
	for token in tokens:
		ass_txt+="\n"+("%02X" % index)+":"
		# opcode(mnemonic) specific command
		if token[0]== 'load':
			# Load from address A to register D. A is in [0, 255]
			if token[1] in table_b and int(token[2])<255 and int(token[2])>=0:
				ass_txt+='0000'+'0'+table_b[token[1]]+dec2bin8(int(token[2]), index)
			else:
				exit() # destination source invalid
		 
		elif token[0]== 'loada':
			# Load from address [A + RE] to register D. A is in [0, 255]
			if token[1] in table_b and int(token[2])<255 and int(token[2])>=0:
				ass_txt+='0000'+'1'+table_b[token[1]]+dec2comp8(int(token[2]), index)
			else:
				exit() # destination source invalid
		elif token[0]=='store':
			# Store the value in register S to address A. A is in [0,255]
			if token[1] in table_b and int(token[2])<255 and int(token[2])>=0:
				ass_txt+='0001'+'0'+table_b[token[1]]+dec2bin8(int(token[2]), index)
			else:
				exit() # destination source invalid
		elif token[0]=='storea':
			# Store the value in register S to address [A + RE]. A is in [0, 255]
			if token[1] in table_b and int(token[2])<255 and int(token[2])>=0:
				ass_txt+='0001'+'1'+table_b[token[1]]+dec2comp8(int(token[2]), index)
			else:
				exit() # destination source invalid
		elif token[0]=='bra':
			# Unconditional branch to label L
			if token[1] in table_b and int(token[2])<255 and int(token[2])>=0:
				ass_txt+='0010'+'0000'+dec2bin8(labels[token[1]], index)
			else:
				exit() # destination source invalid
		elif token[0]== 'braz':
			# Branch to label L if the CR zero flag is set
			# validate label L
			if token[1] in labels:
				ass_txt+='0011'+'0000'+dec2bin8(labels[token[1]], index)
			else:
				# branch destination not valid
				exit()
		elif token[0]== 'bran':
			# Branch to label L if the CR negative flag is set
			# validate label L
			if token[1] in labels:
				ass_txt+='0011'+'0010'+dec2bin8(labels[token[1]], index)
			else:
				# branch destination not valid
				exit()
		elif token[0]=='brao':
			# Branch to label L if the CR overflow flag is set
			# validate label L
			if token[1] in labels:
				ass_txt+='0011'+'0001'+dec2bin8(labels[token[1]], index)
			else:
				# branch destination not valid
				exit()
		elif token[0]=='brac':
			# Branch to label L if the CR carry flag is set
			# validate label L
			if token[1] in labels:
				ass_txt+='0011'+'0011'+dec2bin8(labels[token[1]], index)
			else:
				# branch destination not valid
				exit()
		elif token[0]=='call':
			# Call the routine at label L
			# validate label L
			if token[1] in labels:
				ass_txt+='0011'+'01'+'00'+dec2bin8(labels[token[1]], index)
			else:
				# branch destination not valid
				exit()
		elif token[0]=='return':
			# return from a routine
			ass_txt+='0011100000000000'
			
		elif token[0]=='exit' or token[0]=='halt':
			# execute the halt/exit instruction
			ass_txt+='0011110000000000'
		elif token[0]=='push':
			# Push register S onto the stack and increment SP
			if token[1] in table_c:
				ass_txt+='0100'+table_c[token[1]]+'000000000'
			else:
				exit()
		elif token[0]=='pop':
			# Decrement SP and put the top value on the stack into register S
			if token[1] in table_c:
				ass_txt+='0101'+table_c[token[1]]+'000000000'
			else:
				exit()
		elif token[0]=='oport':
			# Send register S to the output port
			if token[1] in table_d:
				ass_txt+='0110'+table_d[token[1]]+'000000000'
			else:
				exit()
		elif token[0]=='iport':
			# Assign to register D the value of the input port
			if token[1] in table_b:
				ass_txt+='0111'+table_d[token[1]]+'0000000000'
			else:
				exit()
		elif token[0]=='add':
			# Execute C <= A + B, where A, B, C are registers
			if token[1] in table_e and token[2] in table_e and token[3] in table_b:
				ass_txt+='1000'+table_e[token[1]]+table_e[token[2]]+'000'+table_b[token[3]]
			else:
				exit()
		elif token[0]=='sub':
			# Execute C <= A - B, where A, B, C are registers
			if token[1] in table_e and token[2] in table_e and token[3] in table_b:
				ass_txt+='1001'+table_e[token[1]]+table_e[token[2]]+'000'+table_b[token[3]]
			else:
				exit()
		elif token[0]=='and':
			# Execute C <= A and B, bitwise, where A, B, C are registers
			if token[1] in table_e and token[2] in table_e and token[3] in table_b:
				ass_txt+='1010'+table_e[token[1]]+table_e[token[2]]+'000'+table_b[token[3]]
			else:
				exit()
		elif token[0]=='or':
			# Execute C <= A or B, bitwise, where A, B, C are registers
			if token[1] in table_e and token[2] in table_e and token[3] in table_b:
				ass_txt+='1011'+table_e[token[1]]+table_e[token[2]]+'000'+table_b[token[3]]
			else:
				exit()
		elif token[0]=='xor':
			# Execute C <= A xor B, bitwise, where A, B, C are registers
			if token[1] in table_e and token[2] in table_e and token[3] in table_b:
				ass_txt+='1100'+table_e[token[1]]+table_e[token[2]]+'000'+table_b[token[3]]
			else:
				exit()
		elif token[0]=='shiftl':
			# Execute C <= A shifted left by 1, where A, C are registers
			if token[1] in table_e and token[2] in table_b:
				ass_txt+='1101'+'0'+table_e[token[1]]+'00000'+table_b[token[2]]
			else:
				exit()
		elif token[0]=='shiftr':
			# Execute C <= A shifted right by 1, where A, C are registers
			if token[1] in table_e and token[2] in table_b:
				ass_txt+='1101'+'1'+table_e[token[1]]+'00000'+table_b[token[2]]
			else:
				exit()
		elif token[0]=='rotl':
			# Execute C <= A rotated left by 1, where A, C are registers
			if token[1] in table_e and token[2] in table_b:
				ass_txt+='1110'+'0'+table_e[token[1]]+'00000'+table_b[token[2]]
			else:
				exit()
		elif token[0]=='rotr':
			# Execute C <= A rotated right by 1, where A, C are registers
			if token[1] in table_e and token[2] in table_b:
				ass_txt+='1110'+'1'+table_e[token[1]]+'00000'+table_b[token[2]]
			else:
				exit()
		elif token[0]=='move':
			# Execute C <= A where A and C are registers
			if token[1] in table_d and token[2] in table_b:
				ass_txt+='1111'+'0'+table_d[token[1]]+'00000'+table_b[token[2]]
			else:
				exit()
		elif token[0]=='movei':
			# Execute C <= A where A is an 8-bit 2's complement value and C is a register
			if int(token[1])<255 and int(token[1])>=0 and token[2] in table_d:
				ass_txt+='1111'+'1'+dec2comp8(int(token[1]),index)+table_d[token[2]]
			else:
				exit()
		else:
			print "ERROR\n Instruction : "+token[0]+"  is not defined\n"
			exit()
			
		index+=1
		ass_txt+=";"
		 
	if "%02X" % index != "FF":
		ass_txt+="\n["+("%02X"%index)+"..FF] : 1111111111111111; \nEND"
		
		
		return ass_txt

def main( argv ):
	if len(argv) < 2:
		print 'Usage: python %s <filename>' % (argv[0])
		exit()

	fp = file( argv[1], 'rU' )

	tokens = tokenize( fp )

	fp.close()

	# execute pass1 and pass2 then print it out as an MIF file
	tkns, labels =pass1(tokens)
	print "\n*****\ntokens\n"
	print tokens
	print "\n*****\n"
	text=pass2(tkns,labels)
	print text
	# create file
	assembly_file = open("assemble.mif","w")
	assembly_file.write(text)
	assembly_file.close()

	return


if __name__ == "__main__":
	main(sys.argv)
	