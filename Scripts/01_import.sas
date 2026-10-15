/*************************************************
 Program : 01_import.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : Import STATS19 2025 collisions and casualties
 Source  : Department for Transport, Road Safety Data (data.gov.uk)
           dft-road-casualty-statistics-collision-2025.csv
           dft-road-casualty-statistics-casualty-2025.csv
           dft-road-casualty-statistics-road-safety-open-dataset-data-guide-2025.xlsx
*************************************************/

/* Library pointing to the project folder */
libname rs "~/stats19_project";

/* Import collisions (all of Great Britain).
   GUESSINGROWS=MAX scans every row so collision_index
   is read as text and types match across both files */
  
proc import datafile="~/stats19_project/collisions_2025.csv"
    out=rs.collisions_raw
    dbms=csv
    replace;
    guessingrows=max;
run;

/* Import casualties (all of Great Britain) */
proc import datafile="~/stats19_project/casualties_2025.csv"
    out=rs.casualties_raw
    dbms=csv
    replace;
    guessingrows=max;
run;

/* Check the structure of both tables.
   collision_index should be Char in both;
   date and time should be Num */
proc contents data=rs.collisions_raw varnum;
run;

proc contents data=rs.casualties_raw varnum;
run;