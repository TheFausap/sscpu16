# CPU
# 256 banks x 64KB
# each memory location 16bit
# in the instruction there's the bank number
# in the R7 there's the location

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
	my ($m, $f) = @_;
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
# FE; INS;

# LDM (R->M)
# 00001RRRBBBBBBBB
# OPR; MBO; MBI; RI; RO;
# MA; MI;


# LDI (I->M)
# 00010000BBBBBBBB
# IIIIIIIIIIIIIIII
# OPR; MBO; MBI; MA;
# FE; IMM; MI;

# STM (M->R)
# 00011RRRBBBBBBBB
# OPR; MBO: MBI; RI; RO;
# MA; MO;

# SECA (F) 
# SECS (F)
# SEZA (F)
# SEZS (F)
# SEVA (F)
# SEVS (F)
# SES (F)
# MULR (R,R)
# DIVR (R,R)

# JMP (M)
# JCA (M)
# JCS (M)
# JVA (M)
# JVS (M)
# JZA (M)
# JZS (M)

# NOP ()
# HLT ()

my $pc = 0x1000;
my $bus = 0;
my $bank = 0;
my $mar = 0;

sub FE {
	$bus = $mem[0][$pc];
	$pc = $pc + 1;
}

sub MA {
	$mar = $mem[7];
}

sub MBO {
	$bus = ($bus << 3) % 0x7fff;
	$bus = $bus >> 3;
}

sub MBI {
	$bank = $bus;
}

sub RI {
	$bus = $bus >> 8;
}

sub RO {
	$bus = $mem[0][$bus];
}

sub MI {
	$mem[$bank][$mar] = $bus;	
}

sub MO {
	$mem[0][$bus] = $mem[$bank][$mar];
}

sub INS {
	$bus = ($mem[0][$pc] >> 11) % 0xffff;
}

sub OPR {
	$bus = ($mem[0][$pc] << 5) % 0xffff;
	$bus = $bus >> 5;
}

sub IMM {
	$bus = $mem[0][$pc];
}

$mem[0][0x1000] = 0b1110101110101010;
