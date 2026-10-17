/*************************************************
 Program : 05_charts.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : All eight poster charts (Task C), drawn at the
           exact size they are printed on the A2 poster,
           so the text on them stays readable
 Input   : rs.wales_collisions, rs.wales_analysis,
           rs.councils, rs.council_speed (from 04_tests)
 Output  : fig1 to fig8 PNG files (300 dpi) in Charts,
           numbered as on the poster
 Colours : blue = ordinary groups, red = highest risk,
           navy = share of collisions (Figure 1 line)
*************************************************/
%let path = /home/u64610698/stats19_project;
libname rs "&path";

/* Create the Charts folder if it does not exist */
options dlcreatedir;
libname charts "&path/Charts";
libname charts clear;

/* Remove old chart files so only this run's charts remain */
data work.old_files;
  length fname $200;
  rc  = filename("dir", "&path/Charts");
  did = dopen("dir");
  if did > 0 then do;
    do i = 1 to dnum(did);
      fname = dread(did, i);
      if lowcase(scan(fname, -1, ".")) = "png" then output;
    end;
    rc = dclose(did);
  end;
  keep fname;
run;

data _null_;
  set work.old_files;
  rc = filename("f", cats("&path/Charts/", fname));
  rc = fdelete("f");
run;

/* Save charts as PNG files in the Charts folder.
   Titles are written as text in the Results (ods text),
   so the saved PNGs stay title-free for the poster */
ods listing gpath="&path/Charts" image_dpi=300;

/* Each chart is drawn at the exact size it is printed on the
   A2 poster (300 dpi), so labels stay readable when printed */
ods graphics on / reset imagefmt=png noborder;
title;
footnote;

/* Colour maps */
data work.attrmap;
  length id $9 value $6 fillcolor linecolor markercolor $8;
  id = "highlight";
  value = "Focus";  fillcolor = "cxD7301F"; linecolor = "cxD7301F"; markercolor = "cxD7301F"; output;
  value = "Other";  fillcolor = "cx2C7FB8"; linecolor = "cx2C7FB8"; markercolor = "cx2C7FB8"; output;
  id = "severity";
  value = "KSI";    fillcolor = "cxD7301F"; linecolor = "cx404040"; markercolor = "cxD7301F"; output;
  value = "Slight"; fillcolor = "cx2C7FB8"; linecolor = "cx404040"; markercolor = "cx2C7FB8"; output;
run;

proc format;
  value dayf 1="Sun" 2="Mon" 3="Tue" 4="Wed" 5="Thu" 6="Fri" 7="Sat";
  value monf 1="J" 2="F" 3="M" 4="A" 5="M" 6="J"
             7="J" 8="A" 9="S" 10="O" 11="N" 12="D";
run;

/* Overall KSI rates for the reference lines */
proc sql noprint;
  select mean(collision_ksi_pct) format=4.1 into :ksi_all trimmed
  from rs.wales_collisions;
  select mean(ksi_pct) format=4.1 into :ksi_cas trimmed
  from rs.wales_analysis;
quit;

/*------------------------------------------------
 Figure 1: time of day. Bars = KSI rate (severity),
 line = share of all collisions (how busy).
 Both are percentages, so they share one axis.
------------------------------------------------*/
data work.fig1;
  set rs.wales_collisions;
  where not missing(hour);
  length period $24;
  if hour <= 5 then do;       order = 1; period = "Night|12am to 6am";    end;
  else if hour <= 9 then do;  order = 2; period = "Morning|6am to 10am";  end;
  else if hour <= 14 then do; order = 3; period = "Midday|10am to 3pm";   end;
  else if hour <= 18 then do; order = 4; period = "Afternoon|3pm to 7pm"; end;
  else do;                    order = 5; period = "Evening|7pm to 12am";  end;
run;

proc means data=work.fig1 nway noprint;
  class order period;
  var collision_ksi_pct;
  output out=work.fig1 n=n mean=ksi_rate;
run;

proc sql noprint;
  select max(ksi_rate) format=best32. into :max_hour trimmed from work.fig1;
  select sum(n) into :n_all trimmed from work.fig1;
quit;

data work.fig1;
  set work.fig1;
  length highlight $6;
  highlight = ifc(round(ksi_rate, 0.001) = round(&max_hour, 0.001), "Focus", "Other");
  share = n / &n_all * 100;   /* share of all collisions (%) */
run;

proc sort data=work.fig1;
  by order;
run;

ods graphics / imagename="fig1_ksi_rate_by_time_of_day" width=4.95in height=1.65in;
ods text="Figure 1: Time of day: KSI rate (bars) and share of collisions (line)";
ods text="Highest KSI rate in red";
proc sgplot data=work.fig1 dattrmap=work.attrmap noautolegend;
  vbarparm category=period response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack barwidth=0.7;
  series x=period y=share / markers lineattrs=(color=cx12355B thickness=2.5)
         markerattrs=(symbol=circlefilled size=7 color=cx12355B);
  legenditem type=fill name="bar" / fillattrs=(color=cx2C7FB8)
             label="Killed or seriously injured (%)";
  legenditem type=markerline name="line" / lineattrs=(color=cx12355B thickness=2.5)
             markerattrs=(symbol=circlefilled color=cx12355B)
             label="Share of all collisions (%)";
  keylegend "bar" "line" / location=inside position=topright across=1
            valueattrs=(size=9pt) noborder;
  xaxis display=(nolabel) discreteorder=data valueattrs=(size=10pt)
        fitpolicy=split splitchar="|";
  yaxis label="Percent (%)" labelattrs=(size=11pt) valueattrs=(size=11pt)
        values=(0 to 45 by 15) grid offsetmin=0 offsetmax=0.15;
run;

/*------------------------------------------------
 Figure 2: KSI rate by day, Monday first,
 highest day in red
------------------------------------------------*/
proc means data=rs.wales_collisions nway noprint;
  where not missing(day_of_week);
  class day_of_week;
  var collision_ksi_pct;
  output out=work.fig2 mean=ksi_rate;
run;

proc sql noprint;
  select max(ksi_rate) format=best32. into :max_day trimmed from work.fig2;
quit;

data work.fig2;
  set work.fig2;
  length highlight $6;
  order = mod(day_of_week + 5, 7);   /* Mon = 0, Sun = 6 */
  highlight = ifc(round(ksi_rate, 0.001) = round(&max_day, 0.001), "Focus", "Other");
run;

proc sort data=work.fig2;
  by order;
run;

ods graphics / imagename="fig2_ksi_rate_by_day" width=4.95in height=1.65in;
ods text="Figure 2: KSI rate by day of week";
ods text="Highest day in red; dashed line: all collisions";
proc sgplot data=work.fig2 dattrmap=work.attrmap noautolegend;
  refline &ksi_all / axis=y lineattrs=(pattern=dash color=cx404040);
  vbarparm category=day_of_week response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack barwidth=0.7;
  format day_of_week dayf.;
  xaxis display=(nolabel) discreteorder=data valueattrs=(size=11pt);
  yaxis label="KSI rate (%)" labelattrs=(size=11pt) valueattrs=(size=11pt)
        values=(0 to 45 by 15) grid offsetmin=0;
run;

/*------------------------------------------------
 Figure 3: KSI rate by month, grey line = overall
------------------------------------------------*/
proc means data=rs.wales_collisions nway noprint;
  where not missing(month);
  class month;
  var collision_ksi_pct;
  output out=work.fig3 mean=ksi_rate;
run;

ods graphics / imagename="fig3_ksi_rate_by_month" width=4.95in height=1.65in;
ods text="Figure 3: KSI rate by month";
ods text="Grey line: KSI rate for all collisions";
proc sgplot data=work.fig3 noautolegend;
  refline &ksi_all / axis=y lineattrs=(color=cx9AA5B1 thickness=2);
  series x=month y=ksi_rate / lineattrs=(color=cx2C7FB8 thickness=3);
  format month monf.;
  xaxis display=(nolabel) values=(1 to 12 by 1) valueattrs=(size=11pt);
  yaxis label="KSI rate (%)" labelattrs=(size=11pt) valueattrs=(size=11pt)
        values=(20 to 45 by 10) grid;
run;

/*------------------------------------------------
 Figure 4: KSI rate by speed band, 60 mph in red
------------------------------------------------*/
proc means data=rs.wales_collisions nway noprint;
  where not missing(speed_band);
  class speed_band;
  var collision_ksi_pct;
  output out=work.fig4 mean=ksi_rate;
run;

data work.fig4;
  set work.fig4;
  length highlight $6;
  highlight = ifc(speed_band = "60 mph", "Focus", "Other");
  label_y = ksi_rate - 3.5;
run;

ods graphics / imagename="fig4_ksi_rate_by_speed_limit" width=4.25in height=2.73in;
ods text="Figure 4: KSI rate by speed limit";
ods text="60 mph (highest) in red; dashed line: all collisions";
proc sgplot data=work.fig4 dattrmap=work.attrmap noautolegend;
  refline &ksi_all / axis=y lineattrs=(pattern=dash color=cx404040)
                     label="All (&ksi_all%)" labelattrs=(size=10pt);
  vbarparm category=speed_band response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack;
  text x=speed_band y=label_y text=ksi_rate /
       textattrs=(color=white size=11pt weight=bold);
  format ksi_rate 4.1;
  xaxis display=(nolabel) valueattrs=(size=11pt) fitpolicy=split;
  yaxis label="Collisions KSI (%)" labelattrs=(size=11pt) valueattrs=(size=11pt)
        grid offsetmin=0;
run;

/*------------------------------------------------
 Figure 5: KSI rate by road user, motorcyclists in red
 (Other left out: it mixes many vehicle types)
------------------------------------------------*/
proc means data=rs.wales_analysis nway noprint;
  where road_user ne "Other" and not missing(road_user);
  class road_user;
  var ksi_pct;
  output out=work.fig5 mean=ksi_rate;
run;

proc sort data=work.fig5;
  by descending ksi_rate;
run;

data work.fig5;
  set work.fig5;
  length highlight $6;
  highlight = ifc(road_user = "Motorcyclist", "Focus", "Other");
  label_x = ksi_rate - 1;
run;

ods graphics / imagename="fig5_ksi_rate_by_road_user" width=4.25in height=2.73in;
ods text="Figure 5: KSI rate by road user";
ods text="Motorcyclists (highest) in red; dashed line: all casualties";
proc sgplot data=work.fig5 dattrmap=work.attrmap noautolegend;
  refline &ksi_cas / axis=x lineattrs=(pattern=dash color=cx404040);
  hbarparm category=road_user response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack;
  text x=label_x y=road_user text=ksi_rate / position=left
       textattrs=(color=white size=11pt weight=bold);
  format ksi_rate 4.1;
  xaxis label="Casualties KSI (%)" labelattrs=(size=11pt) valueattrs=(size=11pt)
        grid min=0 offsetmin=0;
  yaxis display=(nolabel) discreteorder=data valueattrs=(size=11pt);
run;

/*------------------------------------------------
 Figure 6 (Test 1): fast road share vs adjusted KSI
 rate, 22 councils, fitted line with 95% band
------------------------------------------------*/
ods exclude all;
ods output PearsonCorr=work.r_adj;
proc corr data=rs.councils pearson;
  var fast_pct adj_ksi_pct;
run;
ods exclude none;

data _null_;
  set work.r_adj;
  if Variable = "fast_pct";
  call symputx("r_adj", put(adj_ksi_pct, 4.2));
  call symputx("p_adj", put(Padj_ksi_pct, 5.3));
run;

/* Name only the four councils that tell the story */
data work.fig6;
  set rs.councils;
  length show_name $30;
  if council in ("Powys" "Gwynedd" "Cardiff" "Swansea") then show_name = council;
run;

ods graphics / imagename="fig6_test1_councils" width=4.6in height=2.35in;
ods text="Figure 6 (Test 1): Fast road share vs adjusted KSI rate, 22 councils";
ods text="Pearson correlation with fitted line and 95% band";
proc sgplot data=work.fig6 noautolegend;
  reg x=fast_pct y=adj_ksi_pct / clm clmattrs=(clmfillattrs=(color=cxFCBBA1))
      lineattrs=(color=cxD7301F thickness=3)
      markerattrs=(symbol=circlefilled size=8 color=cx2C7FB8)
      datalabel=show_name datalabelattrs=(size=10pt);
  inset "r = &r_adj, p = &p_adj" / position=topleft textattrs=(size=11pt);
  xaxis label="Collisions on fast roads (%)"
        labelattrs=(size=11pt) valueattrs=(size=11pt) grid;
  yaxis label="Adjusted KSI rate (%)"
        labelattrs=(size=11pt) valueattrs=(size=11pt) grid;
run;

/*------------------------------------------------
 Figure 7 (Test 2): average KSI rate on slower and
 fast roads across the 22 councils, fast in red
------------------------------------------------*/
proc means data=rs.council_speed noprint;
  var ksi_slow ksi_fast;
  output out=work.means mean=m_slow m_fast;
run;

data work.fig7;
  set work.means;
  length road $12 highlight $6;
  call symputx("gap", put(m_fast - m_slow, 4.1));
  road = "Slower roads"; ksi = m_slow; highlight = "Other"; label_y = ksi - 4; output;
  road = "Fast roads";   ksi = m_fast; highlight = "Focus"; label_y = ksi - 4; output;
  keep road ksi highlight label_y;
run;

ods graphics / imagename="fig7_test2_fast_vs_slower" width=4.6in height=2.35in;
ods text="Figure 7 (Test 2): Average KSI rate on slower and fast roads, 22 councils";
ods text="Paired t test; fast roads in red";
proc sgplot data=work.fig7 dattrmap=work.attrmap noautolegend;
  vbarparm category=road response=ksi / group=highlight attrid=highlight
           groupdisplay=stack barwidth=0.55;
  text x=road y=label_y text=ksi / textattrs=(color=white size=12pt weight=bold);
  format ksi 4.1;
  inset "Fast roads: &gap points higher" / position=topleft textattrs=(size=11pt weight=bold);
  xaxis display=(nolabel) discreteorder=data valueattrs=(size=11pt);
  yaxis label="KSI rate (%)" labelattrs=(size=11pt)
        valueattrs=(size=11pt) min=0 max=50 grid offsetmin=0;
run;

/*------------------------------------------------
 Figure 8 (Test 3): age by severity, KSI in red
------------------------------------------------*/
ods graphics / imagename="fig8_test3_age_by_severity" width=4.6in height=2.35in;
ods text="Figure 8 (Test 3): Age of KSI and slight casualties";
ods text="Mann-Whitney U test; diamond: mean";
proc sgplot data=rs.wales_analysis dattrmap=work.attrmap noautolegend;
  where not missing(age);
  vbox age / category=severity_group group=severity_group attrid=severity
             medianattrs=(color=black thickness=2)
             meanattrs=(color=black symbol=diamondfilled);
  xaxis display=(nolabel) valueattrs=(size=11pt);
  yaxis label="Age (years)" labelattrs=(size=11pt) valueattrs=(size=11pt) grid;
run;

ods listing close;
title;

/* Check: the Charts folder should hold exactly eight PNGs */
data work.chart_files;
  length file $200;
  rc  = filename("dir", "&path/Charts");
  did = dopen("dir");
  do i = 1 to dnum(did);
    file = dread(did, i);
    output;
  end;
  rc = dclose(did);
  keep file;
run;

title "Check: files in the Charts folder (expect 8)";
proc print data=work.chart_files noobs;
run;
title;