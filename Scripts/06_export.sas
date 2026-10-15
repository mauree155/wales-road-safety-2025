proc export data=rs.wales_analysis
    outfile="~/stats19_project/wales_analysis.csv"
    dbms=csv replace;
run;

proc export data=rs.wales_collisions
    outfile="~/stats19_project/wales_collisions.csv"
    dbms=csv replace;
run;