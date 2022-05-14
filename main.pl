# CPU
# 256 banks x 64KB
# each memory location 16bit
# in the instruction there's the bank number
# in the R7 there's the location
use Switch;

my @mem;

for ((0..255)) {
	$mem[$_] = (0 x 65535);
}

# 16bits wide registry
# mem[0] .. mem[7] = registry R0-R7
# mem[8]           = Acc register
# mem[9]           = Sub register
# mem[10]          = Flag register
#                  = (xxxxxxxxCCVVZZSx)
# C = carry, V = overflow, Z = zero, S = signed

sub extrfl {
	my ($f) = @_;
	if ($f eq "C") {
		my $rA = $mem[0][10] & 0x0080;
		my $rS = $mem[0][10] & 0x0040;
	} elsif ($f eq "V") {
		my $rA = $mem[0][10] & 0x0020;
		my $rS = $mem[0][10] & 0x0010;
	} elsif ($f eq "Z") {
		my $rA = $mem[0][10] & 0x0008;
		my $rS = $mem[0][10] & 0x0004;
	} elsif ($f eq "S") {
		my $rA = $mem[0][10] & 0x0002;
		my $rS = $mem[0][10] & 0x0001; # not used
	}
	
	return ($rA, $rS);
}

# mem[11] .. mem[267] = stack (256 locs)

my $tos = 11;
my $bos = 267;
my $sp = $bos;

sub push {
	my ($v) = @_;
	$mem[0][$sp] = $v;
	$sp = $sp - 1;
}

sub pop {
	my $v = $mem[0][$sp];
	$sp = $sp + 1;
	return $v;
}

### INSTRUCTION SET
### 5bits
# FE; INS; ALU;

# LDM (R->M)
# 00001 RRRBBBBBBBB
# OPR; MBO; MBI; RI; RO;
# MA; MI;

# LDI (I->M)
# 00010 000BBBBBBBB
# IIIIIIIIIIIIIIII
# OPR; MBO; MBI; MA;
# FE; ALU; MI;

# STM (M->R)
# 00111 RRRBBBBBBBB
# OPR; MBO; MBI; RI; RO;
# MA; MO;

# STIR (I->R)
# 00011 RRR00000000
# OPR; RI; SR;
# FE; ALU; MI;

# SECA (F) 
# SECS (F)
# SEZA (F)
# SEZS (F)
# SEVA (F)
# SEVS (F)
# SES (F)

# CLA (A)
# 00000 00000000001
# OPR;

# CLS (S)
# 00000 00000000010
# OPR;

# ADD (R)
# 00100 RRR00000000
# OPR; RI; AAR;

# SUB (R)
# 00100 RRR00000001
# OPR; RI; ASR;

# MULR (R,R)
# DIVR (R,R)

# JMP (M)
# 00101 000MMMMMMMM
# OPR; MBO;

# JCA (M)
# 00101 001MMMMMMMM
# OPR; MBO;

# JCS (M)
# 00101 010MMMMMMMM
# OPR; MBO;

# JVA (M)
# 00101 011MMMMMMMM
# OPR; MBO;

# JVS (M)
# 00101 100MMMMMMMM
# OPR; MBO;

# JZA (M)
# 00101 101MMMMMMMM
# OPR; MBO;

# JZS (M)
# 00101 110MMMMMMMM
# OPR; MBO;

# NOP ()
# HLT ()

my $pc   = 0x1000;
my $ir   = 0; # instruction register
my $r15  = 0; # internal scratch register (for OPR)
my $bus  = 0;
my $bank = 0;
my $mar  = 0;
my $hlt  = 0; # halt flag

sub FE {
	$bus = $mem[0][$pc];
	$pc = $pc + 1;
}

sub MA {
	$mar = $mem[0][7];
}

sub AAR {
	$mem[0][$bus] = $mem[0][$bus] + $mem[0][8];
}

sub ASR {
	$mem[0][$bus] = $mem[0][$bus] + $mem[0][9];
}

sub SR {
	$mar = $bus;
}

sub SO {
	$bus = $mem[0][9];
}

sub MBO {
	$bus = ($opr & 0b00011111111);
}

sub MBI {
	$bank = $bus;
}

sub RI {
	$bus = ($opr & 0b11100000000)>>8;
}

sub RO {
	$bus = $mem[0][$bus];
}

sub MI {
	if ($ir == 3) {
		$mem[0][$mar] = $bus;
	} else {
		$mem[$bank][$mar] = $bus;
	}
	
}

sub MO {
	$mem[0][$bus] = $mem[$bank][$mar];
}

sub INS {
	$ir = ($bus >> 11) % 0xffff;
}

sub OPR {
	$opr = ($bus & 0x07ff);
	print "OPR = $opr\n";
}

sub ALU {
	my $s = $mem[0][10] & 2;
	$mem[0][8] = 0; $mem[0][9] = 0;
	my ($fA, $fS) = extrfl("C");
	$mem[0][8] = $mem[0][8] + $mem[0][0] + $fA;
	$mem[0][9] = $mem[0][9] - $mem[0][0] + $fS;
	if ($s == 0) {	
		if ($mem[0][8] > 65535) {
			$mem[0][8] = $mem[0][8] % 0xffff;
			$mem[0][10] = $mem[0][10] | 0x0080;
			$mem[0][10] = $mem[0][10] | 0x0020;
		}
		if ($mem[0][9] < -65535) {
			$mem[0][9] = ($mem[0][9] % 0xffff);
			$mem[0][10] = $mem[0][10] | 0x0040;
			$mem[0][10] = $mem[0][10] | 0x0010;
		}
	} else {
		if ($mem[0][8] > 32767) {
			$mem[0][8] = $mem[0][8] % 0x7fff;
			$mem[0][10] = $mem[0][10] | 0x0080;
		}
		if ($mem[0][9] < -32768) {
			$mem[0][9] = ($mem[0][9] % 0x7fff);
			$mem[0][10] = $mem[0][10] | 0x0040;
		}
	}
	if ($mem[0][8] == 0) {
		$mem[0][10] = $mem[0][10] | 0x0008;
	}
	if ($mem[0][9] == 0) {
		$mem[0][10] = $mem[0][10] | 0x0004;
	}
	print "A   = $mem[0][8]\n";
	print "B   = $mem[0][9]\n";
}

=begin comment
$mem[0][0x1000] = 0b0001111100000000; # STIR R7
$mem[0][0x1001] = 0b0011000000010000; # 0x3010
$mem[0][0x1002] = 0b0001000000000000; # LDI B0
$mem[0][0x1003] = 0b0001000111100111; # 0x11e7
$mem[0][0x1004] = 0b0001100000000000; # STIR R0
$mem[0][0x1005] = 0b0001000000010111; # 0x1017
$mem[0][0x1006] = 0b0000100000000000; # LDM R0,B0
$mem[0][0x1007] = 0b0011111000000000; # STM B0,R6
$mem[0][0x1008] = 0b0000000000000001; # CLA
$mem[0][0x1009] = 0b0010011000000000; # ADD R6
$mem[0][0x1010] = 0b0000000000000001; # CLA
$mem[0][0x1011] = 0b0010011000000001; # SUB R6
$mem[0][0x1012] = 0b0010011000000001; # SUB R6
$mem[0][0x1020] = 0b0000011111111111; # HLT
=cut

$mem[0][0x1000] = 0b0001100000000000; # STIR R0
$mem[0][0x1001] = 0b0001000000010111; # 0x1017
$mem[0][0x1002] = 0b0001100000000000; # STIR R0
$mem[0][0x1003] = 0b0000000000000010; # 0x2
$mem[0][0x1004] = 0b0000000000000001; # CLA
$mem[0][0x1005] = 0b0010011000000000; # ADD R6
$mem[0][0x1006] = 0b0010011000000000; # ADD R6
$mem[0][0x1007] = 0b0010011000000000; # ADD R6
$mem[0][0x1008] = 0b0001100000000000; # STIR R0
$mem[0][0x1009] = 0b0000000000000001; # 0x1
$mem[0][0x100a] = 0b0010011000000001; # SUB R6
$mem[0][0x100b] = 0b0000011111111111; # HLT

while ($hlt != 1) {
	FE(); INS(); 
	print "INS: $ir\n";
	ALU();
	switch($ir) {
		case 0	{ 
			OPR();
			switch($opr) {
				case 0x7ff { $hlt = 1;}
				case 0x1   { $mem[0][8] = 0;}
				case 0x2   { $mem[0][9] = 0;}
			}
		}
		case 3	{ OPR(); RI(); SR(); FE(); MI(); }
		case 2	{ OPR(); MBO(); MBI(); MA(); FE(); MI(); }
		case 1  { OPR(); MBO(); MBI(); RI(); RO(); MA(); MI(); }
		case 7	{ OPR(); MBO(); MBI(); RI(); MA(); MO(); }
		case 4  { OPR(); 
			if (($opr & 0x1) == 0) {
				RI(); AAR(); 
			} else {
				RI(); ASR();
			}
		}
		case 5 { OPR(); MBO();
			
			switch($opr & 0x700) {
				case 0x0	{ $pc = $bus; }
				case 0x100	{ 
					my ($fA, $fS) = extrfl("C"); 
					if ($fA == 1) { $pc = $bus; }
				}
				case 0x200	{ 
					my ($fA, $fS) = extrfl("C"); 
					if ($fS == 1) { $pc = $bus; }
				}
				case 0x300	{ 
					my ($fA, $fS) = extrfl("V"); 
					if ($fA == 1) { $pc = $bus; }
				}
				case 0x400	{ 
					my ($fA, $fS) = extrfl("V"); 
					if ($fS == 1) { $pc = $bus; }
				}
				case 0x500	{ 
					my ($fA, $fS) = extrfl("Z"); 
					if ($fA == 1) { $pc = $bus; }
				}
				case 0x600	{ 
					my ($fA, $fS) = extrfl("Z"); 
					if ($fS == 1) { $pc = $bus; }
				}
			}
		}
	} 
}

print "MEM = $mem[0][0x3010]\n";
print "R0  = $mem[0][0]\n";
print "R1  = $mem[0][1]\n";
print "R2  = $mem[0][2]\n";
print "R3  = $mem[0][3]\n";
print "R4  = $mem[0][4]\n";
print "R5  = $mem[0][5]\n";
print "R6  = $mem[0][6]\n";
print "R7  = $mem[0][7]\n";
print "A   = $mem[0][8]\n";
print "B   = $mem[0][9]\n";
