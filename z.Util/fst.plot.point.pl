#! perl

use warnings;
use strict;
use List::Util qw(sum);

my $f = shift or die "need fst file\n";
my $cut = shift or die "need snp cut num\n";
my $chr = shift or die "need chr file\n";
my $color = shift or die "need color file\n";
my $out = shift or die "need out put name\n";
my $windth = shift;
my $height = shift;
my %color_hash = &get_color($color);
my %chr_hash = &get_chr($chr);
my @chr_name;my @chr_coord;

my @a = sort {$a cmp $b} keys %color_hash;
my @b;
for my $e(@a){
    push @b, "\"$color_hash{$e}\"";
}
my $c1 = -1;
my $c2 = 0;
my $coord = 200;
my $s_coord = $coord;

open IN,'<',$f;
open O,'>',$out;
my $last = "NA";
while(<IN>){
    chomp;
    my @l = (split/\t/,$_);
    next unless (exists $chr_hash{$l[0]} || $chr eq "NA");
    $l[4] = 0 if $l[4] < 0;
    unless($l[3] > $cut){
        $l[4] = 0;
    }
    my $a = join"\t",@l;
    if ($last ne $l[0]){
        $last = $l[0];
        if($c1 == ((scalar @a) - 1)){
            $c1 = -1;
        }
        push @chr_name,$l[0];
        push @chr_coord,$c2;
        $c2 = 0;
        $c1 += 1;
        print O $a."\t".$a[$c1]."\t".$coord."\n";
    }else{
        print O $a."\t".$a[$c1]."\t".$coord."\n";
    }
    $coord += 1;
    $c2 += 1;
}
push @chr_coord, $c2;
shift @chr_coord;
close O;
@chr_coord = &cal_coord(\@chr_coord);
#map{$_ = "\"$_\""} @chr_coord;
map{$_ = "\"$_\""} @chr_name;
my $cc = join",",@chr_coord;
my $cn = join",",@chr_name;
my $b = join",",@b;
my $res = &plot_p($out);
open O,'>',"$out.stat";
print O "$res\n";
close O;
open O,'>',"$out.chr_coord.txt";
print O "$cc\n$cn\n";
close O;

sub plot_p{
    my $file = shift @_;
    open R,'>',"$file.point_plot.R";
    print R "library(tidyverse)
data <- read.table(\"$file\")
data[9] = c(\"t\")
colnames(data) <- c(\"chr\",\"start\",\"end\",\"num\",\"w_fst\",\"m_fst\",\"class\",\"s\",\"li\")
a <- ggplot(data)+
  geom_point(aes(x = s,y= w_fst,color = class),size = 0.75)+
  theme_classic()+
  scale_color_manual(
    values = c($b)
              )+
  theme(
      legend.position = \"none\"
  ) +
  labs(x = NULL)+
  scale_x_continuous(breaks = c($cc),labels = c($cn))+
  ylim(0,1)+
  ylab(\"Fst value\")+
  geom_hline(aes(yintercept = quantile(w_fst,probs = c(0.99)),linetype = li),colour=\"firebrick3\",size=0.4,alpha = 2/3)+
  scale_linetype_manual(values=c(\"dashed\"))
ggsave(\"$file.point.pdf\",a,width = $windth,height = $height)
f_mean <- mean(data\$w_fst)
f_var <- var(data\$w_fst)
line <- as.numeric(quantile(data\$w_fst,probs = c(0.99)))
print (c(f_mean,f_var,line))
datatop1 <- data[data\$w_fst > line,]
line <- as.numeric(quantile(data\$w_fst,probs = c(0.95)))
datatop5 <- data[data\$w_fst > line,]
write_tsv(\"$file.top1.fst\",x =datatop1)
write_tsv(\"$file.top5.fst\",x =datatop5)
";
    my $res = `Rscript $file.point_plot.R`;
    return $res;
}

sub cal_coord{
    my $ref = shift @_;
    my @a = @{$ref};
    my @new;
    for(my $i = 0;$i < @a;$i+=1){
        my @tmp_a = @a[0..$i];
        @tmp_a = map {$_-$s_coord} @tmp_a;
        my $sum = sum(@tmp_a);
        my $tmp_s = int($a[$i]/2);
        $tmp_s = $sum - $tmp_s + (($i+2) * $s_coord);
        push @new, $tmp_s;
    }
    return @new;
}

sub get_chr{
    my $f = shift @_;
    my %t;
    open IN,'<',$f or die "$!";
    while(<IN>){
        chomp;
        my @line = split/\s+/;
        $t{$line[0]} = 1;
    }
    close IN;
    return %t;
}

sub get_color{
    my $f = shift @_;
    my %t;
    open IN,'<',$f or die "$!";
    while(<IN>){
        chomp;
        my @line = split/\s+/;
        $t{$line[0]} = $line[1];
    }
    close IN;
    return %t;
}
