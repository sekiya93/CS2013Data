# CS2013Data


## OBJECTIVE

This is a package of scripts and data for analysing a text based on the Body of Knowledge (BOK) of CS2013 [CS2013]. Outputs consist of the rates in 18 Knowledge Area (KA)s of CS2013 followed by the rates in three clusters as shown below.

* HUMAN(C1):                    [HCI, SP, SE]
* THEORY(C2):                   [AL, DS, CN, GV, IS]
* IMPLEMENTATION(C3):           [AR, SF, OS, PD, IAS, NC, IM, PBD, PL, SDF]
* SOFTWARE IMPLEMENTATION(C3a): [PBD, PL, SDF]
* HARDWARE IMPLEMENTATION(C3b): [AR, SF, OS, PD, IAS, NC, IM]

## FILE

* analyze_with_CS2013.pl  
The script to analyse a text. This uses lda-c [LDA] internally.
* final.beta, final.other  
The model obtained by analyzing CS2013. This was extracted by ssLDA [ssLDA] and is used by the lda-c.
* settings.conf  
The parameters used by (ss)LDA.
* ka.csv  
The name of 18 KAs in CS2013 BOK.
* word.csv  
3304 words in CS2013 BOK.
* CS140_result.csv  
CS140 [CSCI140] is a introductory course on algorithm design and analysis techniques. This course is a course exemplar of CS2013 Final Report [CS2013] at p.234.  
This file is obtained by running analyze_with_CS2013.pl with the text extracted from CS140 Web Site (2016-12-13).

## PROCEDURE

1. Set up the Perl environment.
2. Install lda-c from http://www.cs.princeton.edu/~blei/lda-c/.
3. Place the following files in the lda-c directory.  
`analyze_with_CS2013.pl, word.csv, ka.csv, settings.conf, final.beta, final.other`
4. Run the following command in the directory.  
`./analyze_with_CS2013.pl textfilename1  [textfilename2  textfilename3 ...]`
5. Results are in result.csv.  

## SAMPLE

1. Get HTML file from CS140 Web site.  
`curl http://www.cs.pomona.edu/~tzuyi/Classes/CC2013/Algorithms/index.html > CS140.txt`
2. Run analyze_with_CS2013.pl  
`./analyze_with_CS2013.pl CS140.txt`
3. Confirm that the course is related to "Algorithms and Complexity (AL)".  
`cat result.csv`

## REFERENCES

[CS2013] The Joint Task Force on Computing Curricula Association for Computing Machinery (ACM) IEEE Computer Society, Computer Science Curricula 2013 Curriculum Guidelines for Undergraduate Degree Programs in Computer Science (2013).

[CSCI140] Tzu-Yi Chen, CSCI 140: Algorithms, Pomona College Claremont, CA 91711, USA, http://www.cs.pomona.edu/~tzuyi/Classes/CC2013/Algorithms/index.html (accessed 2016-12-09).

[LDA] David M. Blei, LDA-C, http://www.cs.princeton.edu/~blei/lda-c/ (accessed 2016-12-09).

[ssLDA] T. Sekiya, Y. Matsuda, and K. Yamaguchi. Curriculum Analysis of CS Departments Based on CS2013 by Simplified, Supervised LDA. LAK’15, Proceedings of the Fifth International Conference on Learning Analytics And Knowledge, pp. 330-339, NY, USA, 2015.


## LICENSE

This software (CS2013Data) is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

CS2013Data is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.

Takayuki Sekiya
sekiya[at]ecc.u-tokyo.ac.jp

(C) Copyright 2016, Takayuki Sekiya (sekiya[at]ecc.u-tokyo.ac.jp)
