#!/usr/bin/env perl
##################################################
#
# analyze_with_CS2013.pl
#
# Created: Thu Dec  8 11:17:00 2016
# Time-stamp: <2016-12-26 09:53:37 sekiya>
#
# - 引数として与えられたテキストファイルについて，
#   CS2013 の Knowledge Area の割合を出力する
#
# 0. Perl スクリプトを実行可能な Unix 環境を用意する
# 1. Latent Dirichlet allocation (http://www.cs.princeton.edu/~blei/lda-c/) の
#   ツール lda-c をコンパイルする
# 2. lda-c をコンパイルしたディレクトリ内に，本スクリプトも含めて以下のファイルを
#    置く
#    analyze_with_CS2013.pl, word.csv, ka.csv, settings.conf, final.beta, final.other
# 3. 上記ディレクトリ内で以下のコマンドを実行すること
#   ./analyze_with_CS2013.pl テキストファイル1  [テキストファイル2  テキストファイル3 ...]
# 4. 実行結果として result.csv が得られる
#
##################################################

use strict;
use FileHandle;
use Data::Dumper;

use constant{
    # CS2013 に関するファイル
    WORD_CSV_FILE  => 'word.csv',
    KA_CSV_FILE    => 'ka.csv',
    
    # 本スクリプト及び lda-c で生成するファイル
    DOC_TERM_FILE  => 'doc_term.dat',
    INF_GAMMA_FILE => 'inf-gamma.dat',
    
    # 出力
    RESULT_FILE    => 'result.csv',
};

use constant{
    LDA            => './lda inf settings.conf final ' . DOC_TERM_FILE . ' inf',
};

my $DEBUG = 0;

##################################################
# 単語変換規則
##################################################
# 単数形 -> 複数形の標準的な規則
# - パターン/変換方法
my @PLURAL_RULES = (
    '(s)tatus$/$1tatuses',
    '^(ox)$/$1en',
    '([m|l])ouse$/$1ice',
    '(matr|vert|ind)ix|ex$/$1ices',
    '(x|ch|ss|sh)$/$1es',
    '(r|t|c|g|d)y$/$1ies',
    '(hive)$/$1s',
    '(?:([^f])fe|([lr])f)$/$1$2ves',
    '(.*)sis$/$1ses',
    '([ti])um$/$1a',
    '(buffal|tomat)o$/$1oes',
    '(bu)s$/$1ses',
    '(alias)/$1es',
    '(octop|vir)us$/$1i',
    '(.*)s$/$1s',
    '(.*)/$1s"'
    );

# 複数形 -> 単数形の標準的な規則
# - パターン/変換方法
my @SINGULAR_RULES = (
    '(s)tatuses$/$1tatus',
    '^(ox)en$$1',
    '([m|l])ice$/$1ouse',
    '(matr)ices$/$1ix',
    '(vert|ind)ices$/$1ex',
    '(cris|ax|test)es$/$1is', 
    '(x|ch|ss|sh)es$/$1',
    '(r|t|c|g|d)ies$/$1y',
    '(movie)s$/$1',
    '(hive)s$/$1',
    'uizzes$/uiz',    # quizzes -> quiz
    'ives$/ive',      # connectives -> connective
    # '([^f])ves$/$1fe',
    # '([lr])ves$/$1f',
    '(analy|ba|diagno|parenthe|synop|the)ses$/$1sis',
    '([ti])a$/$1um',
    '(buffal|tomat)oes$/$1o',
    '(bu)ses$/$1s',
    '(alias)es/$1',
    '(octop|vir)i$/$1us',
    '(.*)sis$/$1sis', # analysis を変化させない
    '(.*)ss$/$1ss', # access を変化させない
    '(.*)us$/$1us', # corpus など を変化させない
    '(.*)s$/$1',
    '(.*)/$1'
    );

# 単複同形
my @UNINFLECTED = (
    'deer', 'fish', 'measles', 'ois', 'pox', 'rice', 'sheep', 'Amoyese', 'bison', 'bream', 'buffalo', 'cantus', 'carp', 'cod', 'coitus', 'corps', 'diabetes', 'elk', 'equipment', 'flounder', 'gallows', 'Genevese', 'Gilbertese', 'graffiti', 'headquarters', 'herpes', 'information', 'innings', 'Lucchese', 'mackerel', 'mews', 'moose', 'mumps', 'news', 'nexus', 'Niasese', 'Pekingese', 'Portuguese', 'proceedings', 'rabies', 'salmon', 'scissors', 'series', 'shears', 'siemens', 'species', 'testes', 'trousers', 'trout', 'tuna', 'whiting', 'wildebeest', 'Yengeese', 'Bayes'
    );

# 単数->複数 不規則変化
my @PLURAL_IRREGULAR = (
    'atlas$/atlases',  'child$/children',
    'corpus$/corpuses', 'ganglion$/ganglions',
    'genus$/genera', 'graffito$/graffiti',
    'leaf$/leaves', 'man$/men', 
    'money$/monies', 'mythos$/mythoi', 
    'numen$/numina', 'opus$/opuses',
    'penis$/penises', 
    # 'person$/people',
    'sex$/sexes', 'soliloquy$/soliloquies',
    'testis$/testes', 'woman$/women', 
    'move$/moves', 
    #
    'surf$/surves', 'turf$/turves',
    );

# 複数->単数 不規則変化
my @SINGULAR_IRREGULAR = (
    'atlases$/atlas', 'children$/child',
    'corpuses$/corpus', 'ganglions$/ganglion',
    'genera$/genus', 'graffiti$/graffito',
    'leaves$/leaf', 'men$/man', 
    'monies$/money', 'mythoi$/mythos',
    'numina$/numen', 'opuses$/opus',
    'penises$/penises', 
    # 'people$/person',
    'sexes$/sex', 'soliloquies$/soliloquy',
    'testes$/testis', 'women$/woman',
    'moves$/move',
    #
    'surves$/surf', 'turves$/turf',
    );

##################################################
# 単語の変換
##################################################
sub singular{
    my ($word) = @_;

    my $org_word = $word;
    my $lc_word = lc($word);

    # 2文字以上で全て大文字の単語は特に処理しない
    if($word =~ /^[A-Z]{2,}$/){
	return $word;
    }

    # 2文字以上で最後に s が付いた場合は，大文字部分を取り出して単数形に
    if($word =~ /^([A-Z]{2,})s$/){
	return $1;
    }

    # SaaS や iOS のように最後の s が大文字...
    if($word =~ /S$/){
	return $word;
    }

    # 単複同形か
    foreach my $uninflected (@UNINFLECTED){
	if($lc_word eq lc($uninflected)){
	    return $word;
	}
    }

    # 不規則変化か
    foreach my $rule (@SINGULAR_IRREGULAR){
	my $matched;
	eval "\$matched = (\$word =~ s/$rule/i)";
	if($matched){
	    print STDERR "$org_word -> $word\n" if($DEBUG);
	    return $word;
	}
    }

    # 規則変化か
    foreach my $rule (@SINGULAR_RULES){
	my $matched;
	eval "\$matched = (\$word =~ s/$rule/i)";
	if($matched){
	    print STDERR "$org_word -> $word\n" if($DEBUG);
	    return $word;
	}
    }

    print STDERR "Cannot singular \"$word\".\n" if($DEBUG);

    return $word;
}

sub convert_word{
    my ($word) = @_;

    # 文頭などで最初の一文字のみ大文字の場合は，全て小文字に変換
    $word = lc($word) if($word =~ /^[A-Z][a-z\d\-]+$/);

    # 所有格
    $word =~ s/\'s$//g;
		
    # 最後がハイフン
    $word =~ s/\-$//g;

    # 単数形に変換
    my $s_word = singular($word);

    # - ピリオドとカンマを削除
    $s_word =~ s/[\.,]//;

    return $s_word;
}

#############################################################
# 単語情報の読込み
#############################################################
sub read_word_csv_file{
    my $fh = FileHandle->new(WORD_CSV_FILE, O_RDONLY);
    die "Cannot open word csv file. Stop." if(!defined($fh));
    $fh->getline(); # ヘッダを除外

    # word => id
    my %word_hash = ();
    while(my $line = $fh->getline()){
	chomp($line);
	next if($line !~ /^(\d+),\"([^\"]+)\"/);
	my ($id, $word) = ($1, $2);
	$word_hash{$word} = $id;
    }
    $fh->close();

    return \%word_hash;
}

#############################################################
# テキストファイルの処理
#############################################################
sub gen_doc_term_dat_from_text{
    my ($text, $word_hash_ref) = @_;

    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    # カンマやピリオドなど
    $text =~ s/[^\w\d\-\+\.,]/ /g;

    # - ピリオドとカンマはそのまま残しておく
    $text =~ s/([\.,])/$1 /g;
    
    # [id] = counter
    my @word_counter  = ();
    
    foreach my $word (split(/\s+/, $text)){
	my $s_word = convert_word($word);
	next if(!exists($word_hash_ref->{$s_word}));
	my $word_id = $word_hash_ref->{$s_word};
	$word_counter[$word_id] = 0 if(!exists($word_counter[$word_id]));
	$word_counter[$word_id]++;
    }

    my $total_counter = 0;
    my $doc_term_text = '';
    for(my $word_id = 1; $word_id < scalar(@word_counter); $word_id++){
	next if(!exists($word_counter[$word_id]));
	$doc_term_text .= sprintf(" %d:%d", $word_id-1, $word_counter[$word_id]);
	$total_counter++;
    }
    return $total_counter . $doc_term_text;
}

#############################################################
# CS2013 Knowlege Area (KA) を読込み
#############################################################
sub read_ka_csv_file{
    my $fh = FileHandle->new(KA_CSV_FILE, O_RDONLY);
    die "Cannot open KA csv file. Stop." if(!defined($fh));
    $fh->getline(); # ヘッダを除外

    # index => {index => , id => , name => }
    my @ka_col = ();
    while(my $line = $fh->getline()){
	chomp($line);
	next if($line !~ /^(\d+),([A-Z]+),\"([^\"]+)\"/);
	my %ka = (index => $1, id => $2, name => $3);
	$ka_col[$ka{index}-1] = \%ka;
    }
    $fh->close();
    
    return \@ka_col;
}

#############################################################
# inf-gamma を読込み
#############################################################
sub read_inf_gamma_dat_from_text{
    my ($text) = @_;

    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    my @vector = split(/\s+/, $text);
    my $sum = 0;
    map {$sum += $_} @vector;
    my @normalized = map {$_ / $sum} @vector;
    
    return \@normalized;
}

#############################################################
# factor space
#############################################################
sub calc_factor{
    my ($normalized_vector_ref, $cluster_ref) = @_;

    my $size_of_cluster = scalar(@{$cluster_ref});

    my @factor = ();
    for(my $i = 0; $i < $size_of_cluster; $i++){
	push(@factor, 0);
    }
    for(my $i = 0; $i < $size_of_cluster; $i++){
	map{$factor[$i] += $normalized_vector_ref->[$_ - 1]} @{$cluster_ref->[$i]};
    }

    # normlize
    my $sum = 0;
    map{$sum += $_} @factor;

    my @normalized_factor = map{$_ / $sum} @factor;
    return \@normalized_factor;
}

##################################################
# メイン
##################################################

my $word_hash_ref = read_word_csv_file();
# print(STDERR Data::Dumper->Dump([$word_hash_ref]));
      
# LDA の入力データとなる DOC_TERM_FILE を生成する
my $doc_term_fh = FileHandle->new(DOC_TERM_FILE, O_CREAT|O_WRONLY);
die "Cannot open DOC_TERM_FILE. Stop." if(!defined($doc_term_fh));
printf(STDERR "Generate %s.\n", DOC_TERM_FILE);

foreach my $file (@ARGV){
    die "Not file ($file). Stop." if(!-f $file);
    my $fh = FileHandle->new($file, O_RDONLY);
    die "Cannot open $file. Stop." if(!defined($file));
    my $content = '';
    while(my $line = $fh->getline()){
	$content .= $line;
    }
    $fh->close();
    my $data = gen_doc_term_dat_from_text($content, $word_hash_ref);
    $doc_term_fh->printf("%s\n", $data);
}
$doc_term_fh->close();

# LDA (lda-c) を実行
printf(STDERR "\nExecute \"%s\"\n", LDA);
system(LDA);

# 出力
my $ka_col_ref = read_ka_csv_file();

my $result_fh = FileHandle->new(RESULT_FILE, O_CREAT|O_WRONLY);
die "Cannot open RESULT_FILE. Stop." if(!defined($result_fh));
printf(STDERR "\nGenerate %s.\n", RESULT_FILE);

my @cluster3 = (
    # HUMAN:          [HCI, SP, SE]
    [6, 18, 16], 
    # THEORY:         [AL, DS, CN, GV, IS]
    [1, 4, 3, 5, 9],
    # IMPLEMENTATION: [AR, SF, OS, PD, IAS, NC, IM, PBD, PL, SDF]
    [2, 17, 11, 13, 7, 10, 8, 12, 14, 15]
    );

my @cluster4 = (
    # HUMAN:          [HCI, SP, SE]
    [6, 18, 16], 
    # THEORY:         [AL, DS, CN, GV, IS]
    [1, 4, 3, 5, 9],
    # SOFTWARE IMPLEMENTATION: [PBD, PL, SDF]
    [12, 14, 15],
    # HARDWARE IMPLEMENTATION: [AR, SF, OS, PD, IAS, NC, IM]
    [2, 17, 11, 13, 7, 10, 8]
    );

$result_fh->printf("%s,C1,C2,C3,C3a,C3b\n", join(",", map{$_->{id}} @{$ka_col_ref}));

my $gamma_fh = FileHandle->new(INF_GAMMA_FILE, O_RDONLY);
die "Cannot open INF_GAMMA_FILE. Stop." if(!defined($gamma_fh));

while(my $line = $gamma_fh->getline()){
    my $ka_vector_ref = read_inf_gamma_dat_from_text($line);    
    $result_fh->printf("%s", join(",", map{sprintf("%.4f", $_)} @{$ka_vector_ref}));
    my $factor3_ref = calc_factor($ka_vector_ref, \@cluster3);
    $result_fh->printf(",%s", join(",", map{sprintf("%.4f", $_)} @{$factor3_ref}));
    my $factor4_ref = calc_factor($ka_vector_ref, \@cluster4);
    $result_fh->printf(",%.4f,%.4f\n", $factor4_ref->[2], $factor4_ref->[3]);
}

$gamma_fh->close();
$result_fh->close();

