#!/usr/bin/perl

# The P65 Assembler, v 1.1
# Copyright (c) 2001,2 Michael Martin
# All rights reserved.
#
# Redistribution and use, with or without modification, are permitted
# provided that the following conditions are met:
#
# - Redistributions of the code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - The name of Michael Martin may not be used to endorse or promote
#   products derived from this software without specific prior written
#   permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

use strict;
use integer;

# Global variables

my $pc;               # Current program counter
my $linenum;          # Current line number
my $currentfile;      # Current file name
my @IR = ( );         # Intermediate Representation list
my @code = ( );       # Final binary
my @listings = ( );   # Final listing
my %segments = ( );   # Segment map for gensymming segment labels
my $segment = "text"; # Current segment


my ($codecount, $datacount, $fillercount);

my ($verbose, $trace, $printbin, $listing_flag);

# Error reporting routines

my $errorcount = 0;

sub asmerror {
    my $err = shift;
    print "ERROR: $currentfile:$linenum: $err\n";
    $errorcount++;
}

sub num_errors { return $errorcount; }

sub report_errors {
    my $errornum = $errorcount ? $errorcount : "No";
    my $errorname = ($errorcount == 1) ? "error" : "errors";
    if ($verbose || $errorcount) {
	print "$errornum $errorname\n";
    }
}

# Argument Evaluation Routines

sub create_arg {
    my ($prefix, $type, $val, $offset) = @_;
    return [$prefix, $type, $val, $offset];
}

sub can_evaluate {
    my $arg = shift;
    my ($prefix, $type, $val, $offset) = @$arg;
    return ($type eq "num" || label_exists($val));
}

sub hardcoded_arg {
    my $arg = shift;
    my ($prefix, $type, $val, $offset) = @$arg;
    return ($type eq "num");
}

sub eval_arg {
    my $result = 0;
    my $arg = shift;
    my ($prefix, $type, $val, $offset) = @$arg;
    if ($type eq "num") {
        $result = $val; 
    } else {
        $result = label_value($val);
    }
    $result += $offset;
    if ($prefix eq "<") {
        return $result % 256;
    } elsif ($prefix eq ">") {
        return $result / 256;
    } else {
        return $result;
    }
}

sub arg_as_string {
    my $arg = shift;
    my ($prefix, $type, $val, $offset) = @$arg;

    my $sign = ($offset < 0) ? "" : "+";
    my $suffix = ($offset == 0) ? "" : "${sign}$offset";

    if ($prefix eq "") {
        return "${val}$suffix";
    } else {
        return "${prefix}${val}$suffix";
    }
}

1;

# The IR Walker

sub walk {
    my $dispatchtable = shift;
    $pc = 0;
    for (@IR) {
        ($linenum, $currentfile) = @$_;
        my $node_type = $$_[2];
        push @listings,sprintf("%s,%s,%s,%s\n",$linenum,$currentfile,$node_type,$pc);
        if (exists $$dispatchtable{$node_type}) {
            &{$$dispatchtable{$node_type}}($_);
        } elsif (exists $$dispatchtable{"UNKNOWN"}) {
            &{$$dispatchtable{"UNKNOWN"}}($_);
        } else {
            asmerror "Unknown IR type $node_type";
        }
    }
}

# Labels support

my %labels = ( );  # Label -> PC hash

sub label_exists {
    my $label = shift;
    $label = lc $label;
    return ((exists $labels{$label}) || ($label eq "^"));
}

sub label_value {
    my $label = shift;
    if ($label eq "^") {
        return $pc;
    } else {
        $label = lc $label;
        return $labels{$label};
    }
}

sub set_label {
    my ($label, $value) = @_;
    $label = lc $label;
    $labels{$label} = $value;
}

sub defined_labels { return keys %labels; }

# Lexer: breaks lines into tokens

my $instrs="-adc-and-asl-bcc-bcs-beq-bit-bmi-bne-bpl-brk-bvc-bvs-clc-cld-cli-clv-cmp-cpx-cpy-dec-dex-dey-eor-inc-inx-iny-jmp-jsr-lda-ldx-ldy-lsr-nop-ora-pha-php-pla-plp-rol-ror-rti-rts-sbc-sec-sed-sei-sta-stx-sty-tax-tay-tsx-txa-txs-tya-";

my $instrs_6510="slo-rla-sre-rra-sax-lax-dcp-isb-anc-asr-arr-ane-ane-lxa-sbx-sha-shs-las-shx-";

sub is_opcode {
    my $id = shift;
    return $instrs =~ /-$id-/;
}

sub interpret_token {
    my $tok = shift;
    my $firstchar = substr($tok, 0, 1);
    my $rest = substr($tok, 1);
    if ($tok eq "") {
        return ();
    } elsif ($firstchar eq '"') {
        return ["STRING", $rest];
    } elsif ($firstchar eq "\$") {
        if ($rest =~ /^[0-9a-f]+$/i) {
            my $result = hex $rest;
            return ["NUM", $result];
        } else {
            asmerror("Expected a hex value, not '$rest'");
            return ["NUM", 0];
        }
    } elsif ($firstchar eq "\%") {
        if ($rest =~ /^[01]+$/) {
            my $result = 0;
            my @bits = split //, $rest;
            for (@bits) {
                $result *= 2;
                $result += $_;
            }
            return ["NUM", $result];
        } else {
            asmerror("Expected a binary value, not '$rest'");
            return ["NUM", 0];
        }
    } elsif ($firstchar eq "0") {
        if ($tok =~ /^[0-7]+$/i) {
            my $result = oct $tok;
            return ["NUM", $result];
        } else {
            asmerror("Expected an octal value, not '$rest'");
            return ["NUM", 0];
        }
    } elsif ($firstchar =~ /[1-9]/) {
        if ($tok =~ /^[0-9]+$/i) {
            my $result = int $tok;
            return ["NUM", $result];
        } else {
            asmerror("Expected a decimal value, not '$rest'");
            return ["NUM", 0];
        }
    } elsif ($firstchar eq "'") {
        if (substr($rest,1) eq "") {
            return ["NUM", ord $rest];
        } else {
            asmerror("Expected a character, not '$rest'");
            return ["NUM", 0];
        }
    } elsif ($firstchar =~ /[\#,<>():.+\-^*]/) {
        if ($rest ne "") { asmerror("lexer error: $tok can't happen"); }
        if ($firstchar eq "^") {
            return ["LABEL", "^"]; 
        } else {
            return [$firstchar];
        }
    } else {  # Label or opcode.
        my $id = lc($tok);
        if (is_opcode($id)) {
            return (["OPCODE", $id]);
        } elsif ($id eq "x") {
            return (["X"]);
        } elsif ($id eq "y") {
            return (["Y"]);
        } else {
            return (["LABEL", $id]);
        }
    }
}

sub interpret_EOL {
    return ["EOL"];
}

sub lex {
    my $input = shift;
    my @result = ();
    my $value = "";
    my ($quotemode, $backspacemode) = (0, 0);
    
    my @chars = split //, $input;
    
    for (@chars) {
        if ($backspacemode) {
            $backspacemode = 0;
            $value .= $_;
        } elsif ($_ eq "\\") {
            $backspacemode = 1;
        } elsif ($quotemode) {
            if ($_ eq '"') {
                $quotemode = 0;
            } else {
                $value .= $_;
            }
        } else {
            if ($_ eq ";") {
                push @result, interpret_token($value);
                $value = "";
                last;
            } elsif ($_ =~ /\s/) {
                push @result, interpret_token($value);
                $value = "";
            } elsif ($_ =~ /[\#<>,():.+\-^*]/) {
                push @result, interpret_token($value);
                push @result, interpret_token($_);
                $value = "";
            } elsif ($_ eq '"') {
                push @result, interpret_token($value);
                $value = '"';
                $quotemode = 1;
            } else {
                $value .= $_;
            }
        }
    }
    if ($backspacemode) { asmerror("Cannot end a line with a backspace"); }
    if ($quotemode) { asmerror("Unterminated string constant"); }

    push @result, interpret_token($value);    
    push @result, interpret_EOL();

    return @result;
}

# Opcode interpretation routines

my %opcodes = (
               adc_imm  => 0x69,
               adc_zp   => 0x65,
               adc_zpx  => 0x75,
               adc_abs  => 0x6D,
               adc_absx => 0x7D,
               adc_absy => 0x79,
               adc_indx => 0x61,
               adc_indy => 0x71,
               and_imm  => 0x29,
               and_zp   => 0x25,
               and_zpx  => 0x35,
               and_abs  => 0x2D,
               and_absx => 0x3D,
               and_absy => 0x39,
               and_indx => 0x21,
               and_indy => 0x31,
               asl_imp  => 0x0A,
               asl_zp   => 0x06,
               asl_zpx  => 0x16,
               asl_abs  => 0x0E,
               asl_absx => 0x1E,
               bcc_rel  => 0x90,
               bcs_rel  => 0xB0,
               beq_rel  => 0xF0,
               bit_zp   => 0x24,
               bit_abs  => 0x2C,
               bmi_rel  => 0x30,
               bne_rel  => 0xD0,
               bpl_rel  => 0x10,
               brk_imp  => 0x00,
               bvc_rel  => 0x50,
               bvs_rel  => 0x70,
               clc_imp  => 0x18,
               cld_imp  => 0xD8,
               cli_imp  => 0x58,
               clv_imp  => 0xB8,
               cmp_imm  => 0xC9,
               cmp_zp   => 0xC5,
               cmp_zpx  => 0xD5,
               cmp_abs  => 0xCD,
               cmp_absx => 0xDD,
               cmp_absy => 0xD9,
               cmp_indx => 0xC1,
               cmp_indy => 0xD1,
               cpx_imm  => 0xE0,
               cpx_zp   => 0xE4,
               cpx_abs  => 0xEC,
               cpy_imm  => 0xC0,
               cpy_zp   => 0xC4,
               cpy_abs  => 0xCC,
               dec_zp   => 0xC6,
               dec_zpx  => 0xD6,
               dec_abs  => 0xCE,
               dec_absx => 0xDE,
               dex_imp  => 0xCA,
               dey_imp  => 0x88,
               eor_imm  => 0x49,
               eor_zp   => 0x45,
               eor_zpx  => 0x55,
               eor_abs  => 0x4D,
               eor_absx => 0x5D,
               eor_absy => 0x59,
               eor_indx => 0x41,
               eor_indy => 0x51,
               inc_zp   => 0xE6,
               inc_zpx  => 0xF6,
               inc_abs  => 0xEE,
               inc_absx => 0xFE,
               inx_imp  => 0xE8,
               iny_imp  => 0xC8,
               jmp_abs  => 0x4C,
               jmp_ind  => 0x6C,
               jsr_abs  => 0x20,
               lda_imm  => 0xA9,
               lda_zp   => 0xA5,
               lda_zpx  => 0xB5,
               lda_abs  => 0xAD,
               lda_absx => 0xBD,
               lda_absy => 0xB9,
               lda_indx => 0xA1,
               lda_indy => 0xB1,
               ldx_imm  => 0xA2,
               ldx_zp   => 0xA6,
               ldx_zpy  => 0xB6,
               ldx_abs  => 0xAE,
               ldx_absy => 0xBE,
               ldy_imm  => 0xA0,
               ldy_zp   => 0xA4,
               ldy_zpx  => 0xB4,
               ldy_abs  => 0xAC,
               ldy_absx => 0xBC,
               lsr_imp  => 0x4A,
               lsr_zp   => 0x46,
               lsr_zpy  => 0x56,
               lsr_abs  => 0x4E,
               lsr_absy => 0x5E,
               nop_imp  => 0xEA,
               ora_imm  => 0x09,
               ora_zp   => 0x05,
               ora_zpx  => 0x15,
               ora_abs  => 0x0D,
               ora_absx => 0x1D,
               ora_absy => 0x19,
               ora_indx => 0x01,
               ora_indy => 0x11,
               pha_imp  => 0x48,
               php_imp  => 0x08,
               pla_imp  => 0x68,
               plp_imp  => 0x28,
               rol_imp  => 0x2A,
               rol_zp   => 0x26,
               rol_zpx  => 0x36,
               rol_abs  => 0x2E,
               rol_absx => 0x3E,
               ror_imp  => 0x6A,
               ror_zp   => 0x66,
               ror_zpx  => 0x76,
               ror_abs  => 0x6E,
               ror_absx => 0x7E,
               rti_imp  => 0x40,
               rts_imp  => 0x60,
               sbc_imm  => 0xE9,
               sbc_zp   => 0xE5,
               sbc_zpx  => 0xF5,
               sbc_abs  => 0xED,
               sbc_absx => 0xFD,
               sbc_absy => 0xF9,
               sbc_indx => 0xE1,
               sbc_indy => 0xF1,
               sec_imp  => 0x38,
               sed_imp  => 0xF8,
               sei_imp  => 0x78,
               sta_zp   => 0x85,
               sta_zpx  => 0x95,
               sta_abs  => 0x8D,
               sta_absx => 0x9D,
               sta_absy => 0x99,
               sta_indx => 0x81,
               sta_indy => 0x91,
               stx_zp   => 0x86,
               stx_zpy  => 0x96,
               stx_abs  => 0x8E,
               sty_zp   => 0x84,
               sty_zpx  => 0x94,
               sty_abs  => 0x8C,
               tax_imp  => 0xAA,
               tay_imp  => 0xA8,
               tya_imp  => 0x98,
               tsx_imp  => 0xBA,
               txa_imp  => 0x8A,
               txs_imp  => 0x9A,
               tya_imp  => 0x98
               );

my %opcodes_6510 = (
		    slo_indx => 0x03,
		    rla_indx => 0x23,
		    sre_indx => 0x43,
		    rra_indx => 0x63,
		    sax_indx => 0x83,
		    lax_indx => 0xa3,
		    dcp_indx => 0xc3,
		    isb_indx => 0xe3,
		    slo_zp   => 0x07,
		    rla_zp   => 0x27,
		    sre_zp   => 0x47,
		    rra_zp   => 0x67,
		    sax_zp   => 0x87,
		    lax_zp   => 0xa7,
		    dcp_zp   => 0xc7,
		    isb_zp   => 0xe7,
		    anc_imm  => 0x0b,
		    asr_imm  => 0x4b,
		    arr_imm  => 0x6b,
		    ane_imm  => 0x8b,
		    lxa_imm  => 0xab,
		    sbx_imm  => 0xcb,
		    slo_abs  => 0x0f,
		    rla_abs  => 0x2f,
		    sre_abs  => 0x4f,
		    rra_abs  => 0x6f,
		    sax_abs  => 0x8f,
		    lax_abs  => 0xaf,
		    dcp_abs  => 0xcf,
		    isb_abs  => 0xef,
		    slo_indy => 0x13,
		    rla_indy => 0x33,
		    sre_indy => 0x53,
		    rra_indy => 0x73,
		    sha_indy => 0x93,
		    lax_indy => 0xb3,
		    dcp_indy => 0xd3,
		    isb_indy => 0xf3,
		    slo_zpx  => 0x17,
		    rla_zpx  => 0x37,
		    sre_zpx  => 0x57,
		    rra_zpx  => 0x77,
		    sax_zpy  => 0x97,
		    lax_zpy  => 0xb7,
		    dcp_zpx  => 0xd7,
		    isb_zpx  => 0xf7,
		    slo_absy => 0x1b,
		    rla_absy => 0x3b,
		    sre_absy => 0x5b,
		    rra_absy => 0x7b,
		    shs_absy => 0x9b,
		    las_absy => 0xbb,
		    dcp_absy => 0xdb,
		    isb_absy => 0xfb,
		    shx_absy => 0x7e,
		    slo_absx => 0x1f,
		    rla_absx => 0x3f,
		    sre_absx => 0x5f,
		    rra_absx => 0x7f,
		    sha_absy => 0x9f,
		    lax_absy => 0xbf,
		    dcp_absx => 0xdf,
		    isb_absx => 0xff,
		    );

sub has_mode {
    my ($opcode, $mode) = @_;
    return exists $opcodes{"${opcode}_$mode"};
}

sub get_opcode {
    my ($opcode, $mode) = @_;
    return $opcodes{"${opcode}_$mode"};
}

# The parser

my @line;
my $temp_label_count;

# Pragma dispatch table

my %pragmas = (
               address => \&pragma_word,
               advance => \&pragma_advance,
               alias   => \&pragma_alias,
               ascii   => \&pragma_ascii,
               byte    => \&pragma_byte,
               word    => \&pragma_word,
	       checkpc => \&pragma_checkpc,
               include => \&pragma_include,
               incbin  => \&pragma_incbin,
               link    => \&pragma_link,
               org     => \&pragma_org,
	       segment => \&pragma_segment,
	       code    => \&pragma_code,
	       text    => \&pragma_code,
	       data    => \&pragma_data,
               space   => \&pragma_space,
               );

sub token_type {
    my $tok = shift;
    if ($tok) { return lc $$tok[0] };
}

sub token_value {
    my $tok = shift;
    if ($tok) { return $$tok[1] };
}

sub typematch {
    my ($token, $target) = @_;
    return (token_type($token) eq lc($target));
}

sub expect {
    my $actual = shift @line;
    for (@_) { if (typematch($actual, $_)) { return $actual; } }
    my $expected = join '", "', @_;
    asmerror "Expected \"$expected\"";
    return ["ERROR", 0];
}

sub lookahead {
    my ($range, @targets) = @_;
    my $result = 0;

    if (@line > $range) {
        my $actual = $line[$range];
        for (@targets) {
            if (typematch($actual, $_)) { return $actual; } 
        }
    }
}

sub add_IR {
    push @IR, [$linenum, $currentfile, @_];
}

sub parse_line {
    if (lookahead(0, "EOL")) { 
        return;
    } elsif (lookahead(1, ":")) {
        my $newlabel = token_value(expect("label"));
        expect ":";
        add_IR("LABEL", $newlabel, create_arg("","label","^",0));
        parse_line();
        return;
    } elsif (lookahead(0, ".")) {
        parse_pragma();
    } elsif (lookahead(0, "*")) {
        $temp_label_count++;
        expect "*";
        add_IR("LABEL", "\*$temp_label_count", create_arg("","label","^",0));
        parse_line();
    } else {
        parse_instr();
    }
    return;
}

sub parse_pragma {
    expect(".");
    my $pragma = token_value(expect("label"));
    if (exists $pragmas{$pragma}) {
        &{$pragmas{$pragma}}();
    } else {
        asmerror "Unknown pragma .$pragma";
    }
}

sub pragma_ascii {
    my $str = token_value(expect("string"));
    expect("EOL");
    my @data = map ord, split (//, $str);
    add_IR("BYTE", map {create_arg("","num",$_,0);} @data);
}

sub pragma_advance {
    my $target = parse_arg();
    expect("EOL");
    add_IR("ADVANCE", $target);
}

sub pragma_alias {
    my $newlabel = token_value(expect("label"));
    my $target = parse_arg();
    expect("EOL");
    add_IR("LABEL", $newlabel, $target);
}

sub segment_value {
    my $newsegment = shift;
    if (!exists($segments{$newsegment})) {
	return create_arg("", "num", 0, 0);
    }
    my $segcount = $segments{$newsegment};
    return (create_arg("", "label", "\*${newsegment}\*$segcount", 0));
}

sub set_segment {
    my $newsegment = shift;
    my $oldsegcount = $segments{$segment}+1;
    $segments{$segment} = $oldsegcount;
    add_IR("LABEL", "\*${segment}\*$oldsegcount", create_arg("","label","^",0));
    add_IR("SETPC", segment_value($newsegment));
    $segment = $newsegment;
}

sub pragma_segment {
    my $newsegment = token_value(expect("label"));
    expect("EOL");
    set_segment($newsegment);
}

sub pragma_code {
    expect("EOL");
    set_segment("text");
}

sub pragma_data {
    expect("EOL");
    set_segment("data");
}

sub pragma_byte {
    my $sep = ",";
    my @vals;
    while ($sep eq ",") {
        my $val = parse_arg();
        push @vals, $val;
        $sep = token_type(expect(",", "eol"));
    }
    add_IR("BYTE", @vals);
}

sub pragma_word {
    my $sep = ",";
    my @vals;
    while ($sep eq ",") {
        my $val = parse_arg();
        push @vals, $val;
        $sep = token_type(expect(",", "eol"));
    }
    add_IR("WORD", @vals);
}

sub pragma_include {
    my $file = token_value(expect("string"));
    expect("EOL");

    parsefile($file);
}

sub pragma_incbin {
    my $file = token_value(expect("string"));
    expect("EOL");

    local *INPUT;
    
    open INPUT, $file or die "Cannot open $file.  Dying painful death";
    binmode INPUT;
    my $line = "";
    my @bytes = ();
    while (read INPUT, $line, 1) {
        push @bytes, create_arg("", "num", unpack("C", $line), 0);
    }
    add_IR("BYTE", @bytes);
    close INPUT;
}

sub pragma_org {
    my $target = parse_arg();
    expect("EOL");
    add_IR("SETPC", $target);
}

sub pragma_checkpc {
    my $bound = parse_arg();
    expect("EOL");
    add_IR("CHECKPC", $bound);
}

sub pragma_link {
    my $file = token_value(expect("string"));
    my $target = parse_arg();
    expect("EOL");

    add_IR("SETPC", $target);
    parsefile($file);
}

sub pragma_space {
    my $newlabel = token_value(expect("label"));
    my $size = token_value(expect("num"));
    expect("EOL");

    add_IR("LABEL", $newlabel, create_arg("","label","^",0));
    add_IR("SETPC", create_arg("", "label", "^", $size));
}

sub parse_arg {
    my ($prefix, $arg, $offset) = ("", "", 0);
    if (lookahead(0, "<", ">")) {
        $prefix = token_type(expect("<", ">"));
    }
    my ($arg_type, $arg_val);
    if (lookahead(0, "+")) {
        my $target = $temp_label_count;
        $arg_type = "label";
        while(lookahead(0, "+") && !lookahead(1, "num")) {
            expect("+");
            $target++;
        }
        $arg_val = "\*$target";
    } elsif(lookahead(0, "-")) {
        my $target = $temp_label_count+1;
        $arg_type = "label";
        while(lookahead(0, "-") && !lookahead(1, "num")) {
            expect("-");
            $target--;
        }
        $arg_val = "\*$target";
    } else {
        my $arg = expect("num", "label");
        ($arg_type, $arg_val) = (token_type($arg), token_value($arg));
    }
    if (lookahead(0, "+", "-")) {
        my $sign = token_type(expect("+", "-"));
        my $val = token_value(expect("num"));
        $offset = ($sign eq "+") ? $val : -$val;
    }
    return create_arg($prefix, $arg_type, $arg_val, $offset);
}

sub parse_instr {
    my $opcode = token_value(expect("opcode"));
    my ($mode, $arg);
    
    if (lookahead(0, "#")) {
        $mode = ("IMMEDIATE");
        expect("#");
        $arg = parse_arg;
        expect("EOL");
    } elsif (lookahead(0, "(")) {
        # Some indirect mode.
        expect("(");
        $arg = parse_arg;
        if (lookahead(0, ",")) {
            $mode = ("INDIRECT-X");
            expect(","); expect("X"); expect(")"); expect("EOL");
        } else {
            expect(")");
            my $tok = token_type(expect(",", "EOL"));
            if ($tok eq "eol") {
                $mode = ("INDIRECT");
            } else {
                $mode = ("INDIRECT-Y");
                expect("Y"); expect("EOL");
            }
        }                       
    } elsif (lookahead(0, "EOL")) {
        $mode = ("IMPLIED");
        expect("EOL");
    } else { # Zero page or absolute (possibly indexed) or relative.
        $arg = parse_arg; 
        my $tok = token_type(expect("EOL", ","));
        if ($tok eq ",") {
            $tok = token_type(expect("x", "y"));
            if ($tok eq "x") {
                $mode = "MEMORY-X";
            } else {
                $mode = "MEMORY-Y";
            }
            expect("EOL");
        } else {
            $mode = "MEMORY";
        }
    }

    add_IR($mode, $opcode, $arg);
}

sub parsefile {
    my $filename = shift;
    local *INPUT;
    
    my $oldfilename = $currentfile;
    my $oldlinenum = $linenum;

    $currentfile = $filename;
    $linenum = 0;

    open INPUT, $filename or die "Cannot open $filename.  Dying painful death";
    while (<INPUT>) {
        $linenum++;
        @line = lex($_);        
        parse_line;
    }
    close INPUT;
    $linenum = $oldlinenum;
    $currentfile = $oldfilename;
}

sub parse {
    my $basefile = shift;

    $temp_label_count = 0;
    
    parsefile($basefile);
}

# The various passes that walk over the IR

my $instructions_collapsed;

sub verify_IR {
    if ($verbose) { print "Commencing IR Verification phase.\n"; }
    init_labels();
    check_labels();
}

sub instruction_select {
    if ($verbose) { print "Commencing instruction selection phase.\n"; }
    $instructions_collapsed = 1;
    while ($instructions_collapsed)
    {
        update_labels();
        select_zero_page();
    }
    normalize_modes();
}

my %easy_dispatch = (
                  "MEMORY" => \&easy_flat,
                  "MEMORY-X" => \&easy_x,
                  "MEMORY-Y" => \&easy_y,
                  "UNKNOWN" => \&no_op
                  );

sub find_easy_addr_modes {
    if ($verbose) { print "Finding hardcoded addresses\n"; }
    walk(\%easy_dispatch);
}

my %init_dispatch = (
                  "SETPC" => \&init_setpc,
		  "CHECKPC" => \&init_checkpc,
                  "LABEL" => \&init_label,
                  "ADVANCE" => \&init_advance,
                  "UNKNOWN" => \&no_op
                  );


sub init_labels {
    if ($verbose) { print "Verifying label definitions\n"; }
    walk(\%init_dispatch);
}

my %check_dispatch = (
                   "SETPC" => \&no_op,
		   "CHECKPC" => \&no_op,
                   "LABEL" => \&no_op,
                   "ADVANCE" => \&no_op,
                   "IMPLIED" => \&no_op,
                   "BYTE" => \&check_data,
                   "WORD" => \&check_data,
                   "UNKNOWN" => \&check_inst
                   );

sub check_labels {
    if ($verbose) { print "Verifying all expressions\n"; }
    walk(\%check_dispatch);
}

my %update_dispatch = (
                    "SETPC" => \&update_setpc,
		    "CHECKPC" => \&no_op,
                    "LABEL" => \&update_setlabel,
                    "ADVANCE" => \&update_setpc,
                    "BYTE" => \&update_byte,
                    "WORD" => \&update_word,
                    "IMMEDIATE" => \&update_2,
                    "IMPLIED" => \&update_1,
                    "INDIRECT" => \&update_3,
                    "INDIRECT-X" => \&update_2,
                    "INDIRECT-Y" => \&update_2,
                    "MEMORY-X" => \&update_3,
                    "MEMORY-Y" => \&update_3,
                    "MEMORY" => \&update_3,
                    "ABSOLUTE-X" => \&update_3,
                    "ABSOLUTE-Y" => \&update_3,
                    "ABSOLUTE" => \&update_3,
                    "ZERO-PAGE-X" => \&update_2,
                    "ZERO-PAGE-Y" => \&update_2,
                    "ZERO-PAGE" => \&update_2,
                    "RELATIVE" => \&update_2
                    );

sub update_labels {
    if ($verbose) { print "Computing label locations\n"; }
    walk(\%update_dispatch);
}

my %zp_dispatch = (
                   "MEMORY" => \&zp_collapse,
                   "MEMORY-X" => \&zp_collapse_x,
                   "MEMORY-Y" => \&zp_collapse_y,
                   "UNKNOWN" => \&no_op
                   );

sub select_zero_page {
    $instructions_collapsed = 0;
    if ($verbose) { print "Searching for zero page instructions\n"; }
    walk(\%zp_dispatch);
    if ($verbose) { print "$instructions_collapsed instructions found.\n"; }
}

my %norm_dispatch = (
                    "MEMORY" => \&norm_mode,
                    "MEMORY-X" => \&norm_mode_x,
                    "MEMORY-Y" => \&norm_mode_y,
                    "UNKNOWN" => \&no_op
                    );

sub normalize_modes {
    if ($verbose) { print "Canonicalizing addressing modes.\n"; }
    walk(\%norm_dispatch);
}

sub easy_flat {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    if (has_mode($opcode, "rel")) {
        $$node[2] = "RELATIVE";
    } elsif (hardcoded_arg($arg)) {
        my $target = eval_arg($arg);
        if (($target < 256) && has_mode($opcode, "zp")) {
            $$node[2] = "ZERO-PAGE";
        } else {
            $$node[2] = "ABSOLUTE";
        }
    }
}

sub easy_x {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    
    if (hardcoded_arg($arg)) {
        my $target = eval_arg($arg);
        if (($target < 256) && has_mode($opcode, "zpx")) {
            $$node[2] = "ZERO-PAGE-X";
        } else {
            $$node[2] = "ABSOLUTE-X";
        }
    }
}

sub easy_y {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    
    if (hardcoded_arg($arg)) {
        my $target = eval_arg($arg);
        if (($target < 256) && has_mode($opcode, "zpy")) {
            $$node[2] = "ZERO-PAGE-Y";
        } else {
            $$node[2] = "ABSOLUTE-Y";
        }
    }
}

sub no_op {
}

sub init_advance {
    my $node = shift;
    my $target;
    (undef, undef, undef, $target) = @$node;
    if (!can_evaluate($target)) {
        asmerror("Undefined or forward reference in .advance");
    }
}

sub init_setpc {
    my $node = shift;
    my $target;
    (undef, undef, undef, $target) = @$node;
    if (!can_evaluate($target)) {
        asmerror("Undefined or forward reference on program counter assign");
    }
}

sub init_checkpc {
    my $node = shift;
    my $target;
    (undef, undef, undef, $target) = @$node;
    if (!can_evaluate($target)) {
        asmerror("Undefined or forward reference on program counter check");
    }
}

sub init_label {
    my $node = shift;
    my (undef, undef, undef, $labelname, $labeltarget) = @$node;
    if (!can_evaluate($labeltarget)) {
        asmerror("Undefined or forward reference in .alias");
    }
    if (label_exists($labelname)) {
        asmerror("Duplicate label definition: $labelname");
    }
    set_label($labelname, 0);
}

sub check_inst {
    my $node = shift;
    my $arg = $$node[4];
    if (!can_evaluate($arg)) {
        my $badlabel = $$arg[2];
        asmerror("Undefined label '$badlabel'");
    }
}

sub check_data {
    my $node = shift;
    my @data;
    (undef, undef, undef, @data) = @$node;
    for (@data) {
        if (!can_evaluate($_)) {
            my $badlabel = $$_[2];
            asmerror("Undefined label '$badlabel'");
        }
    }
}

sub update_setpc {
    my $node = shift;
    my (undef, undef, undef, $target) = @$node;
    $pc = eval_arg($target);
}

sub update_byte {
    my $node = shift;
    my (undef, undef, undef, @data) = @$node;
    $pc += @data;
}

sub update_word {
    my $node = shift;
    my (undef, undef, undef, @data) = @$node;
    $pc += (@data*2);
}

sub update_1 {
    $pc++;
}

sub update_2 {
    $pc += 2;
}

sub update_3 {
    $pc += 3;
}

sub update_setlabel {
    my $node = shift;
    my (undef, undef, undef, $labelname, $labeltarget) = @$node;

    set_label($labelname, eval_arg($labeltarget));
}

sub zp_collapse {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    if (($target < 256) && has_mode($opcode, "zp")) {
        $instructions_collapsed++;
        if ($trace) { print "--> Collapsed instruction at $currentfile:$linenum.\n"; }
        $$node[2] = "ZERO-PAGE";
    }
}

sub zp_collapse_x {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    if (($target < 256) && has_mode($opcode, "zpx")) {
        $instructions_collapsed++;
        if ($trace) { print "--> Collapsed instruction at $currentfile:$linenum.\n"; }
        $$node[2] = "ZERO-PAGE-X";
    }
}

sub zp_collapse_y {
    my $node = shift;
    my (undef, undef, undef, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    if (($target < 256) && has_mode($opcode, "zpy")) {
        $instructions_collapsed++;
        if ($trace) { print "--> Collapsed instruction at $currentfile:$linenum.\n"; }
        $$node[2] = "ZERO-PAGE-Y";
    }
}

sub norm_mode {
    my $node = shift;
    $$node[2] = "ABSOLUTE";
}

sub norm_mode_x {
    my $node = shift;
    $$node[2] = "ABSOLUTE-X";
}

sub norm_mode_y {
    my $node = shift;
    $$node[2] = "ABSOLUTE-Y";
}

# Assembler

my %assemble_dispatch = (
                         "BYTE" => \&assemble_byte,
                         "WORD" => \&assemble_word,
                         "SETPC" => \&assemble_setpc,
			 "CHECKPC" => \&assemble_checkpc,
                         "ADVANCE" => \&assemble_advance,
                         "IMMEDIATE" => \&assemble_inst_2,
                         "IMPLIED" => \&assemble_inst_1,
                         "INDIRECT" => \&assemble_inst_3,
                         "INDIRECT-X" => \&assemble_inst_2,
                         "INDIRECT-Y" => \&assemble_inst_2,
                         "ABSOLUTE-X" => \&assemble_inst_3,
                         "ABSOLUTE-Y" => \&assemble_inst_3,
                         "ABSOLUTE" => \&assemble_inst_3,
                         "ZERO-PAGE-X" => \&assemble_inst_2,
                         "ZERO-PAGE-Y" => \&assemble_inst_2,
                         "ZERO-PAGE" => \&assemble_inst_2,
                         "RELATIVE" => \&assemble_inst_rel,
                         "LABEL" => \&no_op
                         );

my %addrmodes = (
                  "IMMEDIATE" => "imm",
                  "IMPLIED" => "imp",
                  "INDIRECT" => "ind",
                  "INDIRECT-X" => "indx",
                  "INDIRECT-Y" => "indy",
                  "ABSOLUTE-X" => "absx",
                  "ABSOLUTE-Y" => "absy",
                  "ABSOLUTE" => "abs",
                  "ZERO-PAGE-X" => "zpx",
                  "ZERO-PAGE-Y" => "zpy",
                  "ZERO-PAGE" => "zp",
                  "RELATIVE" => "rel"
                  );

sub assemble {
    if ($verbose) { print "Producing binary\n"; }
    $codecount = $datacount = $fillercount = 0;
    walk(\%assemble_dispatch);
}

sub assemble_byte {
    my @data;
    my $node = shift;
    (undef, undef, undef, @data) = @$node;
    for (@data) {
        my $arg = eval_arg($_);
        if (($arg < 0) || ($arg > 0xff)) {
            my $argstr = arg_as_string($arg);
            asmerror "Constant $argstr out of range";
        } else {
            push @code, $arg;
        }
    }
        
    $pc += @data;
    $datacount += @data;
}

sub assemble_word {
    my @data;
    my $node = shift;
    (undef, undef, undef, @data) = @$node;
    for (@data) {
        my $arg = eval_arg($_);
        if (($arg < 0) || ($arg > 0xffff)) {
            my $argstr = arg_as_string($arg);
            asmerror "Constant $argstr out of range";
        } else {
            push @code, ($arg % 256), int($arg / 256);
        }
    }
        
    $pc += (2 * @data);
    $datacount += (2 * @data);
}

sub assemble_setpc {
    my $node = shift;
    my (undef, undef, undef, $target) = @$node;
    $pc = eval_arg($target);
}

sub assemble_checkpc {
    my $node = shift;
    my (undef, undef, undef, $arg) = @$node;
    my $target = eval_arg($arg);

    if ($pc > $target) {
	my $error = sprintf "Program counter assertion failed: \$%04x > \$%04x", $pc, $target;
        asmerror $error;
    }
}

sub assemble_advance {
    my $node = shift;
    my (undef, undef, undef, $arg) = @$node;
    my $target = eval_arg($arg);

    if ($target < $pc) {
        asmerror "Attempted to .advance backwards, from $pc to $target.";
    } else {
        push @code, (0) x ($target-$pc);
        $fillercount += $target-$pc;
    }
    $pc = $target;
}

sub assemble_inst_1 {
    my $node = shift;
    my (undef, undef, $mode, $opcode) = @$node;

    my $modecode = $addrmodes{$mode};

    if(has_mode($opcode, $modecode)) {
        push @code, get_opcode($opcode, $modecode);
    } else {
        asmerror ("$opcode does not have addressing mode $mode");
    }
    $pc++;
    $codecount++;
}

sub assemble_inst_2 {
    my $node = shift;
    my (undef, undef, $mode, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    my $modecode = $addrmodes{$mode};

    if(has_mode($opcode, $modecode)) {
        push @code, get_opcode($opcode, $modecode);
        if (($target < 0) || ($target > 0xff)) {
            asmerror("Argument out of range (0-\$FF)");
        }
        push @code, $target;
    } else {
        asmerror ("$opcode does not have addressing mode $mode");
    }
    $pc += 2;
    $codecount+=2;
}

sub assemble_inst_3 {
    my $node = shift;
    my (undef, undef, $mode, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    my $modecode = $addrmodes{$mode};

    if(has_mode($opcode, $modecode)) {
        push @code, get_opcode($opcode, $modecode);
        if (($target < 0) || ($target > 0xffff)) {
            asmerror("Argument out of range (0-\$FFFF)");
        }
        push @code, $target % 256, int($target / 256);
    } else {
        asmerror ("$opcode does not have addressing mode $mode");
    }
    $pc += 3;
    $codecount+=3;
}

sub assemble_inst_rel {
    my $node = shift;
    my (undef, undef, $mode, $opcode, $arg) = @$node;
    my $target = eval_arg($arg);
    my $modecode = $addrmodes{$mode};

    if(has_mode($opcode, $modecode)) {
        push @code, get_opcode($opcode, $modecode);
        if (($target < 0) || ($target > 0xffff)) {
            asmerror("Argument out of range (0-\$FFFF)");
        } else {
            my $reltarget = $target - ($pc + 2);
            if ($reltarget < -128 or $reltarget > 127) {
                asmerror "Branch out of range";
            }
            push @code, ($reltarget < 0) ? 256 + $reltarget : $reltarget;
        }
    } else {
        asmerror ("$opcode does not have addressing mode $mode");
    }
    $pc += 2;
    $codecount+=2;
}

my ($infile, $outfile);


sub parse_args {
    my $count = 0;
    $verbose = $trace = $printbin = 0;
    for (@ARGV) {
        if ($_ eq "-v") {
            $verbose = 1;
        } elsif ($_ eq "-t") {
            $trace = $verbose = 1;
        } elsif ($_ eq "-b") {
            $printbin = 1;
	} elsif ($_ eq "-6510") {
	    %opcodes = (%opcodes, %opcodes_6510);
	    $instrs .= $instrs_6510;
        } elsif ($_ eq "-l") {
            $listing_flag = 1;
        } elsif ($_ =~ /^-/) {
            usage();
        } elsif ($count == 0) {
            $infile = $_;
            $count++;
        } elsif ($count == 1) {
            $outfile = $_;
            $count++;
        } else {
            usage();
        }
    }
    if ($count != 2) { usage(); }
}

sub usage() {
    print "\nUsage:\n    $0 [options] basefile outfile\n";
    print "\n        basefile: Top-level source file";
    print "\n        outfile: Binary output file\n\n";
    print "\n    Options:\n";
    print "\n        -v:    Verbose mode: give statistics and announce passes";
    print "\n        -t:    Trace mode: list important, specific steps";
    print "\n        -b:    Print binary as hex dump to screen before writing";
    print "\n        -6510: Allow undocumented opcodes for the 6510 chip";
    print "\n        -l:    Print a listing file";
    print "\n\n";
    exit;
}

sub write_file() {
    if ($verbose) { 
        my $codesize = @code;
        print "Writing $codesize bytes: $codecount code, $datacount data, $fillercount filler.\n";
    }
    open OUTPUT, ">$outfile.nes" or die "Failed to create $outfile.nes";
    binmode OUTPUT;
    print OUTPUT pack "c*", @code;
}

sub write_listing_file() {
    if($listing_flag){
    open OUTPUT, ">$outfile.lis" or die "Failed to create $outfile.lis";
    binmode OUTPUT;
    print OUTPUT @listings;
    }
}

sub print_binary() {
    if ($printbin) {
        my $count = 0;
        foreach (@code) {
            printf "%02x", $_;
            $count = ($count+1) % 16;
            if ($count == 8) { print '-'; }
            elsif ($count == 0) { print "\n"; }
            else { print ' '; }
        }
        print "\n";
    }
}

# Main routine.

my @passes = (\&find_easy_addr_modes, \&verify_IR, \&instruction_select, 
              \&assemble, \&print_binary, \&write_file, \&write_listing_file);

parse_args();

parse($infile);

for (@passes) {
    if (num_errors == 0) {
        &$_();
    }
}

report_errors;


