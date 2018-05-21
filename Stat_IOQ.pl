#===============================================================================
#Stat_IOQ.pl
# 
# Ver.1.0.0 Created by Neil 2018/03/31
#===============================================================================

$|=1;
$ScriptName='Stat_IOQ.pl';

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

#定義退修中心代碼與MPC
%rpCode;
$rpCode{'DCG01'}='PP';
$rpCode{'DCG02'}='W&R';
$rpCode{'DCL01'}='CP';
$rpCode{'DPT01'}='FPI';
$rpCode{'DPT02'}='FPI';
$rpCode{'DRT01'}='XRAY';
$rpCode{'DRT02'}='XRAY';
$rpCode{'DWD01'}='W&R';

($y1,$m1,$d1,$h1,$n1,$s1)=&GetDateTime;

$SelStation=$in{'SelStation'};
$SelDTF=$in{'dateFrom'};
$SelDTT=$in{'dateTo'};

		
$Mod=$in{'mod'};

if($Mod eq '2'){
	&SetTarget;
}elsif($Mod eq '21'){
	&RegTarget;
}
&List;


&CloseDB;
exit;


#-------------------------------------------------
#  Get Date by parameter
#-------------------------------------------------
sub GetCalDate{
	if(@_){
		$time=time+60*60*24*$_[0];
	}else{
		$time=time
	}
	
	$yyp=(localtime($time))[5]+1900;
	$mmp=(localtime($time))[4]+1;
	$ddp=(localtime($time))[3];
	$mmp=substr('0'.$mmp,-2);
	$ddp=substr('0'.$ddp,-2);
	
	return ($yyp,$mmp,$ddp);
}

sub List{
	&HtmlHead("IOQ of Station");
	$RetURL[0] = "index.pl,Index";
	&RetURL;
	
print <<"HEAD";
	<link rel='stylesheet' type='text/css' href='$DocRootURL/default.css' />
	<link rel='stylesheet' type='text/css' href='$DocRootURL/js/Calendar/CalendarM.css' />
	
	<script src='$DocRootURL/js/Calendar/CalendarM.js'></script>
	<script src='$DocRootURL/Ajax/jquery-1.7.2.min.js' type='text/javascript'></script>
	<script src='$DocRootURL/js/tableHeadFixer.js' type='text/javascript'></script>
	
	<style type='text/css'>
		.gridFix {
			//width:400px;
			//height:620px;
		}
		
	</style>
	
	<script language='javascript'>
		var usPT='$DocRootURL/js/calendar';
		//var tyFB=-1;
		//var usFF='1';		
		var BG='';
		function ov(t){
			BG=t.style.background;
			//t.style.cursor='pointer';
			t.style.background='#CCC';
		}
		
		function ot(t){
			t.style.background=BG;
		}
		function queryFun(){
			document.getElementById('mod').value = '0';
			form1.submit();
		}
		function showData(){
			var d_f=document.getElementById('dateFrom').value;
			var d_t=document.getElementById('dateTo').value;
			
			if(d_f != '' && d_t != '' && d_f > d_t){
				alert('Period Error!');
				return;
			}
			document.getElementById('mod').value = '1';
			form1.submit();
		}
		
		function setTarget(){
			document.getElementById('mod').value = '2';
			form1.submit();
		}
		
</script>

HEAD


	print "<center>\n";
	print "<form action='$ScriptName' method=POST name='form1'>\n";
	
	#--------------------------------------------------------
	#
	#--------------------------------------------------------
	
	&Condition;

	if($Mod eq '1'){
		&Grid;
	}
	
	print "<input type='hidden' name='mod' id='mod' value='' />";
	print "</form>\n";
	
	print "</body></html>\n";
	
	&CloseDB;
	exit;
}

sub Condition{
	
	if($SelDTF eq '' && $SelDTT eq ''){
		
		my($y2,$m2,$d2)=&GetCalDate(-1);#yesterday
		
		if($d1 eq '01'){#取上個月
			$SelDTF=$y1.'/'.$m2.'/'.'01';
			$SelDTT=$y2.'/'.$m2.'/'.$d2;
		}else{
			$SelDTF=$y1.'/'.$m1.'/'.'01';
			$SelDTT=$y1.'/'.$m1.'/'.$d2;#昨天
		}
	}
	
	my @aryStation;
	$sql="SELECT mpccode FROM mpc_code_2
			where report='1' 
			order by type,mpccode";
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(($v1)= $sth->fetchrow()){
		push(@aryStation,$v1)
	}
	
	print "<br>";
	print "<table class='TS'>\n";
	
	#Station
	print "<td class='csTc'>MPC\n";
	print "<select name='SelStation' id='SelStation' class='esI' onChange='queryFun();'>\n";
	
	foreach my $v1(@aryStation){
		if ($v1 eq $in{"SelStation"}){
			print "<option value='$v1' selected='selected' >$v1\n";
		}else{
			print "<option value='$v1' >$v1\n";
		}
	}
	print "</select>\n";
	print "</td>\n";
	print "<td class='csTc'>Date</td>\n";
	print "<td class='csDc'>\n";
	print "<input type='input' name='dateFrom' id='dateFrom' size='10' maxlength='10' value='$SelDTF'  onClick='ShowCalA(this);' >\n";
	print "～";
	print "<input type='input' name='dateTo' id='dateTo' size='10' maxlength='10' value='$SelDTT'  onClick='ShowCalA(this);' >\n";
	print "</td>\n";
	print "<td class='csTc'><input type='button' id='btn01' name='btn01' value='Query' onclick='showData()'/></td>\n";
	if($SysAdmin || $FunctionAdmin eq $uid || $AccessType eq 'W'){
		print "<td class='csTc'><input type='button' id='btn02' name='btn02' value='SetTarget' onclick='setTarget()' /></td>\n";
	}
	print "</tr>\n";
	print "</table>\n";
	
	print "<div id='Cal'></div>";
	
}

sub GetData{
	
	#1.利用挑選的MPC取出對應的OPCODE+RPCODE
	#2.利用OPCODE取出IN/OUT
	#3.
	
	my $wh1='';
	my $wh2='';
	my $wh3='';
	my $wh4='';
	my $wh5='';
	my $selOPCODE='';
	my %haYmd;
	my %haProcess;
	my %haIN;
	my %haOUT;
	my %haWIP;
	my %haColumn;
	my $strColumn;
	
	#select condition-----------------------------------
	
	if($SelDTF){
		$SelDTF=~s|(....)(.)(..)(.)(..)|$1$3$5|;
		my $dateFrom=$SelDTF."000000";
		$wh1 = " and startdt >= '$dateFrom'";
		$wh2 = " and finishDT >= '$dateFrom'";
		$wh3 = " and date >= '$SelDTF'";
		$wh4 = " and startdatetime>='$dateFrom'";
		$wh5 = " and endDatetime>='$dateFrom'";
	}
	if($SelDTT){
		$SelDTT=~s|(....)(.)(..)(.)(..)|$1$3$5|;
		my $dateTO=$SelDTT."235959";
		$wh1 = $wh1." and startdt <= '$dateTO'";
		$wh2 = $wh2." and finishDT <= '$dateTO'";
		$wh3 = $wh3." and date <= '$SelDTT'";
		$wh4 = $wh4." and startdatetime<='$dateTO'";
		$wh5 = $wh5." and endDatetime<='$dateTO'";
	}
	#----------------------------------------------------
	
	if($SelStation){
		$sql="SELECT b.opcode FROM mpc_code_2 a 
					inner join mpc_opcode_2 b on a.mpccode=b.mpccode 
				where a.mpccode='$SelStation' 
				order by opcode
				";
		$sth =$dbh->prepare($sql) or return undef;
		$sth->execute();
		while(my($v1)= $sth->fetchrow()){
			unless($selOPCODE){
				$selOPCODE="'".$v1."'";
			}else{
				$selOPCODE=$selOPCODE.",'".$v1."'";
			}
		}
		$sth->finish();
		
		#add rpcode
		foreach my $k(keys %rpCode){
			my $mpc=$rpCode{$k};
			if($SelStation eq $mpc){
				unless($selOPCODE){
					$selOPCODE="'".$k."'";
				}else{
					$selOPCODE=$selOPCODE.",'".$k."'";
				}
			}
		}
	}
	
	unless($selOPCODE){
		$selOPCODE="''";
	}
	
	#Get WIP, IN and Out qty
	$sql="SELECT 'IN',substr(startDT,1,8),processcode,sum(startqty) FROM p_routerstate a
				 left join s_router b on a.routerno=b.routerno
			where length(a.routerno)=13 and opcode in($selOPCODE) $wh1 
			group by substr(startdt,1,8),processcode
		  union all
		  SELECT 'OUT',substr(finishdt,1,8),processcode,sum(if(finishqty,finishqty,startqty)) FROM p_routerstate a
		  		 left join s_router b on a.routerno=b.routerno
		  	where length(a.routerno)=13 and opcode in($selOPCODE) $wh2 
			group by substr(finishdt,1,8),processcode
		  union all
		  SELECT 'IN',substr(startdatetime,1,8),b.processcode,count(productionsn) FROM p_rprouter_tran a
		  		 left join s_router b on a.routerno=b.routerno 
		  	where length(a.routerno)=13 and a.rpcode in($selOPCODE) $wh4
		  	group by substr(startdatetime,1,8),processcode
		  union all
		  SELECT 'OUT',substr(enddatetime,1,8),b.processcode,count(productionsn) FROM p_rprouter_tran a
		  		 left join s_router b on a.routerno=b.routerno 
		  	where length(a.routerno)=13 and a.rpcode in($selOPCODE) $wh5
		  	group by substr(endDatetime,1,8),processcode		
		  union all
		  SELECT 'WIP',date,processCode,sum(wipqty) FROM task_opcodeWip 
		  	where opcode in($selOPCODE) $wh3 
		  	group by date,processCode
			";
	
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(my($t,$ymd,$process,$qty)= $sth->fetchrow()){
		if($t eq 'IN'){
			$haIN{"$ymd<>$process"}=$haIN{"$ymd<>$process"}+$qty;
			$haProcess{$process}=1;
		}elsif($t eq 'OUT'){
			$haOUT{"$ymd<>$process"}=$haOUT{"$ymd<>$process"}+$qty;
			$haProcess{$process}=1;
		}else{
			if($process eq 'ICMA' || $process eq 'ICMN' || $process eq 'IMAC' || $process eq 'IMNC' || $process eq 'RIC'){
				$haWIP{"$ymd<>IC"}=$haWIP{"$ymd<>IC"}+$qty;
			}else{
				$haWIP{"$ymd<>SC"}=$haWIP{"$ymd<>SC"}+$qty;
			}
		}
		$haYmd{$ymd}=1; 
	}
	$sth->finish();
	
	#Get Target
	$sql="SELECT target FROM m_ioq_target where mpccode='$SelStation'";
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	my($target)= $sth->fetchrow();
	$sth->finish();
	
	
	return (\%haYmd,\%haProcess,\%haIN,\%haOUT,\%haWIP,$target,$selOPCODE);
}

sub Grid{
	
	my($pa1,$pa2,$pa3,$pa4,$pa5,$target,$pa7)=&GetData;
	my %haYmd=%{$pa1};
	my %haProcess=%{$pa2};
	my %haIN=%{$pa3};
	my %haOUT=%{$pa4};
	my %haWIP=%{$pa5};
	
	my %haINQty;
	my %haOUTQty;
	
	my $size=keys %haProcess;
	$size++;#for subtotal
	print "<br>";
	print "<div id='chart'></div>";
	print "<br>";
	print "<div class='gridFix'>";
    print "<table id='fixT' cellpadding='0' cellspacing='0'  >\n";
    print "<thead>\n";
    print "<tr>\n";
    print "<th class='csTc' ></th>\n";
    print "<th class='csTc' colspan='$size' title='工單刷開始'>IN</th>\n";
    print "<th class='csTc' colspan='$size' title='工單刷結束'>OUT</th>\n";
    print "<th class='csTc' colspan='2' title='上站刷結束與本站未結束' >WIP</th>\n";
    print "<th class='csTc' rowspan='2'>Target</th>\n";
    print "</tr>\n";
    print "<tr>\n";
    print "<th class='csTc' >Date</th>\n";
    #IN
    foreach my $p(sort keys %haProcess){
		print "<th class='csTc' >$p</th>\n";
	}
	print "<th class='csTc' >subTotal</th>\n";
	#OUT
	foreach my $p(sort keys %haProcess){
		print "<th class='csTc' >$p</th>\n";
	}
	print "<th class='csTc' >subTotal</th>\n";
	print "<th class='csTc' >IC</th>\n";
	print "<th class='csTc' >SC</th>\n";
    print "</tr>\n";
	print "</thead>";
    
    print "<tbody>\n";
	foreach my $dt(sort keys %haYmd){
		my $ttqty=0;
		print "<tr onMouseOver='ov(this);' onMouseOut='ot(this);'>\n";
		print "<td class='csTc'>$dt</td>\n";
		foreach my $p(sort keys %haProcess){#IN
			my $qty=$haIN{"$dt<>$p"};
			$ttqty=$ttqty+$qty;
			print "<td class='csDr' title='$p'>$qty</td>\n";
		}
		$haINQty{$dt}=$ttqty;#for chart
		print "<td class='csDr'>$ttqty</td>\n";#subTotal
		$ttqty=0;
		foreach my $p(sort keys %haProcess){#OUT
			my $qty=$haOUT{"$dt<>$p"};
			$ttqty=$ttqty+$qty;
			print "<td class='csDr' title='$p'>$qty</td>\n";
		}
		$haOUTQty{$dt}=$ttqty;#for chart
		my $wipIC=$haWIP{"$dt<>IC"};
		my $wipSC=$haWIP{"$dt<>SC"};
		print "<td class='csDr'>$ttqty</td>\n";#subTotal
		print "<td class='csDr' title='IC'>$wipIC</td>\n";#WIP
		print "<td class='csDr' title='SC'>$wipSC</td>\n";#WIP
		print "<td class='csDr' title='Target'>$target</td>\n";#Target
		print "</tr>\n";
	}
	
	print "</tbody></table>";
	print "<p>OPCODE:$pa7</p>";
	print "</div>";
	
	#組成Chart需求的資料格式----------------------------------------
	my @aryAll;#組合成ARRAY
	my @ary;
	my @ary1;
	my @ary2;
	my @ary3;
	my @ary4;
	my $strTitle='';#'0301','0302' 
	my $strData='';#['IN',80,220],['OUT',100,300]
	#X軸
	foreach my $dt(sort keys %haYmd){#date
		$dt=substr($dt,4,4);
		push(@ary,"'$dt'");
	}
	$strTitle=join(',',@ary);#陣列加入,
	undef @ary;
	#產生圖的資料
	push(@ary,"'IN'");
	push(@ary1,"'OUT'");
	push(@ary2,"'WIP_IC'");
	push(@ary3,"'WIP_SC'");
	push(@ary4,"'Target'");
	unless($target){
		$target='null';
	}
	foreach my $dt(sort keys %haYmd){
		my $qty=$haINQty{$dt};
		push(@ary,$qty);
		#OUT
		$qty=$haOUTQty{$dt};
		push(@ary1,$qty);
		#WIP
		$qty=$haWIP{"$dt<>IC"};
		unless($qty){
			$qty='null';
		}
		push(@ary2,$qty);
		$qty=$haWIP{"$dt<>SC"};
		unless($qty){
			$qty='null';
		}
		push(@ary3,$qty);
		push(@ary4,$target);
	}
	$strData=join(',',@ary);
	push(@aryAll,$strData);
	$strData=join(',',@ary1);
	push(@aryAll,$strData);
	$strData=join(',',@ary2);
	push(@aryAll,$strData);
	$strData=join(',',@ary3);
	push(@aryAll,$strData);
	$strData=join(',',@ary4);
	push(@aryAll,$strData);
	
	$strData='';
	foreach my $v(@aryAll){
		unless($strData){
			$strData="[".$v."]";
		}else{
			$strData=$strData.",[".$v."]";
		}
	}
	
	#print "$strData<br>";
	&GenChart($strTitle,$strData);
	
}


sub GenChart{
	
	my $xTitle=$_[0];# X 軸說明 ex: xTitle='0301','0302' 
	my $str=$_[1];#產生圖的資料 ex:[IN,30,8],[OUT,21,22],[WIP,48,17],[TARGET,8,36]
	my $chartTitle='';#圖表的說明
	
	$chartTitle=$SelStation."_IOQ";
	
	print <<"HEAD";
	
<link href='$DocRootURL/css/C3/c3.min.css' rel='stylesheet'>

<script src='$DocRootURL/js/Chart/d3.v3.min.js'  charset='utf-8' type='text/javascript'></script>
<script src='$DocRootURL/js/Chart/c3.min.js' type='text/javascript'></script>
	
<script language='javascript'>	


HEAD
	#--後台傳給前端-----------------------------------------------------------------------------------------------
	#srcData=[['PT003',80,220],['PT001',100,300]] ;
	#srcTitle=['0301','0302'];
	print " var srcTitle=[".$xTitle."];";# X 軸
	print " var srcData=[".$str."];";
	print " var txtTitle='".$chartTitle."';";#圖表的說明
	#-------------------------------------------------------------------------------------------------
	
	print <<"HEAD";
		var chart = c3.generate({
			    bindto: '#chart',
			    size: {
			        height: 320,
			        width: 1000
			    },
			    data: {
			      columns: srcData,
			      type: 'bar',
			      types:{
			      	WIP_IC:'area',
			      	WIP_SC:'area',
			      	Target:'line'
			      },
			      groups: [
			        ['WIP_IC','WIP_SC']
			      ]
			    },
			    legend: {
			        position: 'right'
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
				    categories:srcTitle,
            		height: 60
				  },
				  y:{
				  	label: 'QTY'
				  }
			    }
			});
			

</script>

HEAD
	
}

sub SetTarget{
	&HtmlHead("IOQ of Station : Set Target");
	
	print <<"HEAD";
	<link rel='stylesheet' type='text/css' href='$DocRootURL/default.css' />
	<link rel='stylesheet' type='text/css' href='$DocRootURL/js/Calendar/CalendarM.css' />
	
	<script src='$DocRootURL/js/Calendar/CalendarM.js'></script>
	<script src='$DocRootURL/Ajax/jquery-1.7.2.min.js' type='text/javascript'></script>
	
	<script language='javascript'>
	
		function BackTOList(){
			document.getElementById('mod').value = '1';
			form2.submit();
		}
	
		function reg(mpc){
			var n='t_'+mpc;
			var val=document.getElementById(n).value;
			document.getElementById('msg').innerHTML='';
			
			if(isNaN(val)){
				alert('Please input Number!');
				return;
			}
			var dat='mod=21&MPC='+mpc+'&Target='+val;
			\$.ajax({
			   url : "$ScriptRootURL/$ScriptName",
			   type : "post",
			   data : (dat),
			   success : function(result){
				  var resp=result.split('<>');
				  if(resp[1]=='Y'){
					document.getElementById(n).style.background='#E0FFE0';
					document.getElementById('msg').innerHTML='Update OK.';
				  }else{
					document.getElementById('msg').innerHTML='';
					alert('Error!!');
				  }
			   }
			});
		}		
	</script>

HEAD

	my @aryMPC;
	$sql="SELECT a.mpccode,b.target FROM mpc_code_2 a
			left join m_ioq_target b on a.mpccode=b.mpccode
			where report='1' 
			order by a.type,a.mpccode";
	$sth =$dbh->prepare($sql) or return undef;
	$sth->execute();
	while(($v1,$v2)= $sth->fetchrow()){
		push(@aryMPC,"$v1<>$v2")
	}
	
	print "<center>\n";
	print "<form action='$ScriptName' method=POST name='form2'>\n";
	print "<br>";
	print "<div><input type='button' id='btn01' value='Back' onclick='BackTOList()'/></div>";
	print "<br>";
	print "<div id='msg' style='color:blue;'></div>";
	print "<table class='TS'>\n";
	print "<tr>\n";
	print "<td class='csTc'>NO</td>\n";
	print "<td class='csTc'>MPC</td>\n";
	print "<td class='csTc'>Target</td>\n";
	print "</tr>\n";
	my $i=0;
	foreach my $v(sort @aryMPC){
		my($mpc,$target)=split(/<>/,$v);
		$i++;
		print "<tr>\n";
		print "<td class='csDc'>$i</td>\n";
		print "<td class='csD'>$mpc</td>\n";
		print "<td class='csDc'><input type='text' id='t_$mpc' name='t_$mpc' size='6' maxlength='6' value='$target' onchange=\"reg('$mpc')\"/></td>\n";
		print "</tr>\n";
	}
	
	print "<input type='hidden' name='mod' id='mod' value='' />";
	print "<input type='hidden' name='SelStation' id='SelStation' value='$SelStation' />";
	print "<input type='hidden' name='dateFrom' id='dateFrom' value='$SelDTF' />";
	print "<input type='hidden' name='dateTo' id='dateTo' value='$SelDTT' />";
	print "</form>\n";
	
	print "</body></html>\n";
	
	&CloseDB;
	exit;
}


sub RegTarget{ #AJ
	print "content-type:text/html\n\n";
	
	my $M='';
	my $mpc  = $in{'MPC'};
	my $val  = $in{'Target'};
	
	my($y,$m,$d,$h,$n,$s)=&GetDateTime;
	
	$sql="Replace into m_ioq_target (mpccode,target,modifyUser,modifyDate) 
			value('$mpc', '$val','$uid','$y$m$d$h$n$s')  
		  ";
	my $ok=$dbh->do($sql);
	if($ok){
		$M='Y';
	}
	
	print "RS<>$M<>$val<>$sql";
	&CloseDB;
	exit;
}

sub Test{
	
}
