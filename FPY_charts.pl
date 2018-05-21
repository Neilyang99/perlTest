#===============================================================================
#FPY_charts.pl
# 
# Ver.1.0.0 Created by Neil 2018/03/13
#===============================================================================

$|=1;
$ScriptName='FPY_charts.pl';

@Path = split(/\\/,$ENV{'PATH_TRANSLATED'});
pop @Path;
$Path = join("\\",@Path );
eval("use lib ('$Path')");

require "cgi-lib.pl";
require "set_system.pl";
require "sub_common.pl";

&CheckCookie;
use DBI;
&OpenDB;
&CheckAccessPermit;

&ReadParse;

($y1,$m1,$d1,$h1,$n1,$s1)=&GetDateTime;
$_strOPCode="'VI001','PT001','RT001','PT003'";#順序依JEFF需求
@_aryOPCode=('VI001','PT001','RT001','PT003');
@_aryType=('Inspect Date Base','Pour Date Base');

$SelPartNo=$in{'SelPart'};
$SelProcess=$in{'SelProcess'};
$SelType=$in{'SelType'};
$SelDTF=$in{'dateFrom'};
$SelDTT=$in{'dateTo'};

		
$Mod=$in{'mod'};

&List;


&CloseDB;
exit;



sub List{
	&HtmlHead("FPY Charts");
	$RetURL[0] = "index.pl,Index";
	&RetURL;
	
print <<"HEAD";
	<link rel='stylesheet' type='text/css' href='$DocRootURL/default.css' />
	<script src='$DocRootURL/Ajax/jquery-1.7.2.min.js' type='text/javascript'></script>
	<script src='$DocRootURL/js/tableHeadFixer.js' type='text/javascript'></script>
	
	<style type='text/css'>
		.gridFix {
			width:600px;
			height:420px;
		}
		
	</style>
	
	<script language='javascript'>
		
		function queryFun(){
			document.getElementById('mod').value = '0';
			form1.submit();
		}
		function showData(){
			var d_f=document.getElementById('dateFrom').value;
			var d_t=document.getElementById('dateTo').value;
			
			if(document.getElementById('SelProcess').value == ''){
				alert('Please select Process.');
				return;
			}
			if(d_f != '' && d_t != '' && d_f > d_t){
				alert('Period Error!');
				return;
			}
			document.getElementById('mod').value = '1';
			form1.submit();
		}
		
</script>

HEAD

	if($SelDTF eq '' && $SelDTT eq ''){
		$SelDTF=($y1-1).$m1;
		$SelDTT=$y1.$m1;
	}


	print "<center>\n";
	print "<form action='$ScriptName' method=POST name='form1'>\n";
	
	#--------------------------------------------------------
	#
	#--------------------------------------------------------
	print "<br>";
	print "<table class='TS'>\n";
	print "<tr>\n";
	print "<td class='csTc'>Process\n";
	print "<select id='SelProcess' name='SelProcess' class='esI' onChange='queryFun();'><option>\n";
	$sql="select ProcessCode from C_ProcessCode order by ProcessCode";
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(($v1)= $sth->fetchrow()){
		if ($v1 eq $in{"SelProcess"}){
			print "<option value='$v1' selected='selected' >$v1\n";
		}else{
			print "<option value='$v1' >$v1\n";
		}
	}
	print "</select>\n";
	print "</td>\n";
	print "<td class='csTc'>Part No.\n";
	#partno
	print "<td class='csTc'>\n";
	print "<select name='SelPart' class='esI' onChange='queryFun();'><option value=''>ALL</option>\n";
	if ($in{'SelProcess'}){
		$sql="select distinct PartNo from m_part where processcode='$SelProcess' order by partno";
		$sth =$dbh->prepare($sql) or return undef;
		$sth->execute();
		while(my($v1)= $sth->fetchrow()){
			if ($v1 eq $in{"SelPart"}){
				print "<option value='$v1' selected='selected' >$v1\n";
			}else{
				print "<option value='$v1' >$v1\n";
			}
		}
	}
	print "</select>\n";
	print "</td>\n";
	print "<td class='csTc'>Data Type\n";
	print "<td class='csTc'>\n";
	print "<select name='SelType' class='esI' onChange='queryFun();'>\n";
	my $i=0;
	foreach my $v(@_aryType){
		if($SelType eq $i){
			print "<option value='$i' selected>$v</option>";
		}else{
			print "<option value='$i'>$v</option>";
		}
		$i++;
	}
	print "</select>\n";
	print "</td>\n";
	print "<td class='csTc'>Period (Year/month)</td>\n";
	print "<td class='csDc'>\n";
	print "<input class='esI bdOrgD' name='dateFrom' id='dateFrom' maxlength='6' value='$SelDTF' style='width:50px;' >\n";
	print "　～　";
	print "<input class='esI bdOrgD' name='dateTo' id='dateTo' maxlength='6' value='$SelDTT' style='width:50px;' >\n";
	print "　format：yyyymm";
	print "</td>\n";
	print "<td class='csTc'><input type='button' id='btn01' name='btn01' value='Query' onclick='showData()'/></td>\n";
	print "</tr>\n";
	print "</table>\n";


	if($Mod eq '1'){
		&Grid;
	}
	
	print "<input type='hidden' name='mod' id='mod' value='' />";
	print "</form>\n";
	
	print "</body></html>\n";
	
	&CloseDB;
	exit;
}

sub GetData{
	
	my $wh1='';
	my $wh2='';
	
	my %haFPY;
	my %haYM;
	my $partno_inspect='';
	my $partno_def_sum='';
	my %haSampleQty;
	my %haPourQty;
	
	#select condition-----------------------------------
	if($SelPartNo){
		$partno_inspect=" and partNo='$SelPartNo'";
		$partno_def_sum=" and a.partNo='$SelPartNo'";
	}
	if($SelDTF){
		my $dtFrom=$SelDTF.'01';#建立起始日期
		$wh1= " and record_date >= '$dtFrom' ";
		$wh2= " and a.record_date >= '$dtFrom' ";
	}
	if($SelDTT){
		my $dtTo=$SelDTT.'31';#建立結束日期
		$wh1=$wh1. " and record_date <= '$dtTo' ";
		$wh2=$wh2. " and a.record_date <= '$dtTo' ";
	}
	#----------------------------------------------------
	
	if($SelType eq '1'){
		$sql="select substring(a.MeltingNo,1,4),count(1) 
				from rec_pouring a 
				inner join s_router b on a.RouterNo=b.RouterNo
				where b.processcode='$SelProcess' $partno_inspect
				group by substring(a.MeltingNo,1,4)
				";
		$sth =$dbh->prepare($sql) or return undef;
		$sth->execute();
		while(my($v1,$v2)= $sth->fetchrow()){
			$haPourQty{"20$v1"}=$v2;
		}
		$sth->finish();
	}
	
	#建立Row數量[年月],每個月份的sample數值
	unless($SelType){#檢驗日
		$sql="select opcode,sum(inspection_qty) as inspect_qty,substring(record_date,1,6) as rec_date from fpy_inspect_sum 
			where OpCode in ($_strOPCode) and processcode='$SelProcess' $wh1 $partno_inspect
			group by opcode,substring(record_date,1,6)
		  ";
	}else{#$SelType=1: 澆鑄日
		$sql="select opcode,sum(inspection_qty) as inspect_qty,substring(record_date,1,6) as rec_date from fpy_inspect_sum_pouring 
			where OpCode in ($_strOPCode) and processcode='$SelProcess' $wh1 $partno_inspect
			group by opcode,substring(record_date,1,6)
		  ";
	}
	
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(my($opCode,$sampleQty,$inspectYM)= $sth->fetchrow()){
		$haSampleQty{"$inspectYM<>$opCode"}=$sampleQty;
		$haYM{$inspectYM}=1;
		$haFPY{"$inspectYM<>$opCode"}=100;
	}
	
	#建立所有月分與FPY
	unless($SelType){#檢驗日
		$sql="select a.opcode,b.inspect_qty,100-round(sum(a.defect_qty/a.defect_qty_sum)/b.inspect_qty*100,2),substring(a.record_date,1,6) 
			from fpy_def_sum a
			inner join (select partno,opcode,sum(inspection_qty) as inspect_qty,substring(record_date,1,6) as rec_date 
							from fpy_inspect_sum 
							where processcode='$SelProcess' and opcode in ($_strOPCode) $partno_inspect $wh1
							group by opcode,substring(record_date,1,6)
						) b on  a.opcode=b.opcode and substring(a.record_date,1,6)=b.rec_date
			where a.opcode in($_strOPCode) and a.processcode='$SelProcess' $partno_def_sum $wh2 
			group by a.opcode,substring(a.record_date,1,6)";
	}else{#$SelType=1: 澆鑄日
		$sql="select a.opcode,b.inspect_qty,100-round(sum(a.defect_qty/a.defect_qty_sum)/b.inspect_qty*100,2),substring(a.record_date,1,6) 
			from fpy_def_sum_pouring a
			inner join (select partno,opcode,sum(inspection_qty) as inspect_qty,substring(record_date,1,6) as rec_date 
							from fpy_inspect_sum_pouring 
							where length(record_date)=8 and processcode='$SelProcess' and opcode in ($_strOPCode) $partno_inspect $wh1
							group by opcode,substring(record_date,1,6)
						) b on  a.opcode=b.opcode and substring(a.record_date,1,6)=b.rec_date
			where  length(a.record_date)=8 and a.opcode in($_strOPCode) and a.processcode='$SelProcess' $partno_def_sum $wh2 
			group by a.opcode,substring(a.record_date,1,6)";
	}
	#print "$sql";
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(my($opcode,$qty,$fpy,$ym)= $sth->fetchrow()){
		
		if($fpy<0){
			$fpy=0;
		}
		$haFPY{"$ym<>$opcode"}=$fpy;
	}
	$sth->finish();
	
	return (\%haYM,\%haFPY,\%haPourQty,\%haSampleQty);
}

sub Grid{
	
	my($pa1,$pa2,$pa3,$pa4)=&GetData;
	my %haYM=%{$pa1};
	my %haFPY=%{$pa2};
	my %haPour=%{$pa3};
	my %haSampleQty=%{$pa4};
	
	
	print "<br>";
	print "<div id='chart'></div>";
	print "<br>";
	print "<div class='gridFix'>";
    print "<table id='fixT' cellpadding='0' cellspacing='0'  >\n";
    print "<thead>\n";
    print "<tr>\n";
    print "<th class='csTc' rowspan='2'>YM</th>\n";
   	if($SelType eq '1'){
   		print "<th class='csTc' rowspan='2'>Total<br>PourQTY</th>\n";
   	}
    foreach my $v(@_aryOPCode){
    	print "<th class='csTc' colspan='2'>$v</th>\n";
    }
	print "</tr>\n";
	print "<tr>\n";
    foreach my $v(@_aryOPCode){
    	print "<th class='csTc'>QTY</th>\n";
    	print "<th class='csTc'>FPY</th>\n";
    }
	print "</tr>\n";
	print "</thead>";
    
    print "<tbody>\n";
    foreach my $ym(sort keys %haYM){#year/month
    	print "<tr>\n";
		print "<td class='csTc'>$ym</td>\n";
		if($SelType eq '1'){#pour date base
			my $qty=$haPour{$ym};
			print "<td class='csDr'>$qty</td>\n";
		}
		foreach my $v(@_aryOPCode){
			my $fpy=$haFPY{"$ym<>$v"};
			my $qty=$haSampleQty{"$ym<>$v"};
			print "<td class='csDr'>$qty</td>\n";
			print "<td class='csDr'>$fpy %</td>\n";
		}    
    	print "</tr>\n";
    }
    
	print "</tbody></table></div>";
	
	#<!-- Load c3.css -->
	print "<link href='$DocRootURL/css/C3/c3.min.css' rel='stylesheet'>";
	#設定LINE的寬度
	print "<style type='text/css'>";
	print " .c3-line {stroke-width: 3px;}";
	print "</style>";
		
	#javascript --------------------------------
	#<!-- Load d3.js and c3.js -->
	print "<script src='$DocRootURL/js/Chart/d3.v3.min.js'  charset='utf-8' type='text/javascript'></script>";
	print "<script src='$DocRootURL/js/Chart/c3.min.js' type='text/javascript'></script>";
	
	print "<script language='javascript'>";
	
	#組JS的資料 ex: data=[['PT003',80,220],['PT001',100,300]] ; title=['1701','1702']
	my @ary;#QTY
	my @ary2;#FPY
	my @aryAll;#組合成ARRAY
	my $str='';
	my $strTitle='';
	foreach my $ym(sort keys %haYM){#year/month
		$ym=substr($ym,2,4);
		push(@ary,"'$ym'");
	}
	$strTitle=join(',',@ary);#陣列加入,
	undef @ary;
	my $i=0;
	foreach my $v(@_aryOPCode){
		my $title=$v.'QTY';
		push(@ary,"'$title'");
		push(@ary2,"'$v'");
		foreach my $ym(sort keys %haYM){
			my $fpy=$haFPY{"$ym<>$v"};
			my $qty=$haSampleQty{"$ym<>$v"};
			unless($qty){
				$qty= 0;
			}
			unless($fpy){
				$fpy= 0;
				unless($qty){#數量為0 FPY不畫線
					$fpy= 'null';
				}
			}else{
				$fpy= sprintf("%.4f",$fpy/100);#小數4位
			}
			
			
			push(@ary,$qty);
			push(@ary2,$fpy);
		}
		$str=join(',',@ary);#'PT001QTY',30,8,21,22,17,48,17,8,36,23,33,32
		push(@aryAll,$str);
		$str=join(',',@ary2);#'PT001',0.0667,0.0000,0.0000,0.1364,0.1176,0.0625,0.0588,0.0000,0.0278,0.0000,0.0000,0.0000
		push(@aryAll,$str);
		undef @ary;
		undef @ary2;
	}
	#pour date base
	if($SelType eq '1'){
		push(@ary,"'TotalPourQTY'");
		foreach my $ym(sort keys %haYM){
			my $qty=$haPour{$ym};
			unless($qty){
				$qty= 0;
			}
			push(@ary,$qty);
		}
		$str=join(',',@ary);#'TotalPourQTY',30,8,21,22,17,48,17,8,36,23,33,32
		push(@aryAll,$str);
	}
	$str='';
	foreach my $v(@aryAll){
		unless($str){
			$str="[".$v."]";
		}else{
			$str=$str.",[".$v."]";
		}
	}
	#圖的Title
	my $jsTitle='';
	if($SelPartNo){
		$jsTitle=$SelPartNo.": FPY - ".$_aryType[$SelType];
	}else{
		$jsTitle=$SelProcess.": FPY - ".$_aryType[$SelType];
	}
	print " var srcTitle=[".$strTitle."];";# X 軸
	print " var srcData=[".$str."];";
	print " var txtTitle='".$jsTitle."';";#圖表的說明
	
print <<"HEAD";
	
		var chart = c3.generate({
			    bindto: '#chart',
			    size: {
			        height: 340,
			        width: 920
			    },
			    data: {
			      columns: srcData,
			      type: 'bar',
			      types:{
			      	PT001:'line',
			      	PT003:'line',
			      	RT001:'line',
			      	VI001:'line'
			      },
			      axes: {
			        PT001:'y2',
			      	PT003:'y2',
			      	RT001:'y2',
			      	VI001:'y2'
			      },
			      colors: {
			        VI001QTY: '#4F81BD',
			        VI001: '#4F81BD',
			        PT001QTY: '#C0504D',
			        PT001: '#C0504D',
			        RT001QTY: '#9BBB59',
			        RT001: '#9BBB59',
			        PT003QTY: '#8064A2',
			        PT003: '#8064A2',
			        TotalPourQTY: '#C6D9F1'
			      }
			    },
			    line: {
				    connectNull: true
				},
			    title: { 
			        text: txtTitle
			    },
			    axis: {
			      x:{
				    type: 'category',
				    categories:srcTitle
				  },
				  y:{
				  	label: 'QTY'
				  }, 	
			      y2: {
			      	label: 'FPY',
			      	tick:{format:d3.format('%')},
			        show: true // ADD
			      }
			    }
			});
			

</script>

HEAD

	#print "<div id='txt'>$str</div>";
}

sub Test{
	
}
