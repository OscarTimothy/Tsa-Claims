libname cs '&path/case_study';


/* Create SAS tables */
proc sql;
	create table cs.claimsraw as
	select *
	from claimsraw;
quit;


proc sql;
	create table cs.enplanement2017 as
	select *
	from enplanement2017;
quit;

proc sql;
	create table cs.boarding2013_2016 as
	select *
	from boarding2013_2016;
quit;

/* Access and prepare the data */

proc sql inobs=10;
title 'snapshot of data';
	select *
	from cs.claimsraw;
title 'snapshot of data';
	select *
	from cs.enplanement2017;
title 'snapshot of data';	
	select *
	from cs.boarding2013_2016;
quit;


proc sql;
title 'Column Attributes';
	select memname 'Table name',name 'Column name',type,length
	from dictionary.columns
	where libname='CS';
quit;

proc sql;
title'Claim Site Column';
	select distinct claim_site
	from cs.claimsraw;
	
title 'Disposition column';
	select distinct disposition
	from cs.claimsraw;
	
title 'Claim type';
	select distinct claim_type
	from cs.claimsraw;
quit;


proc sql;
title 'Incident Date';
	select distinct year(incident_date)
	from cs.claimsraw;

title 'Date Received';
	select distinct year(date_received)
	from cs.claimsraw;	
quit;

proc sql;
title 'Wrong occurance report';
	select 'Wrong Occurance', count(*) 
	from cs.claimsraw
	where incident_date > Date_received;
quit;

proc sql number;
	select Claim_Number, Date_Received, Incident_Date
	from cs.claimsraw
	where incident_date > Date_received;
quit;

proc sql noprint;

	create table cs.Claims_NoDup as
		select distinct *
		from cs.claimsraw;
quit;

proc sql noprint;
	create table Claims_Cleaned as
		select Claim_Number 'Claim Number', 
			   Incident_Date 'Incident Date', 
			   Airport_Name 'Airport Name',
			   case
					when incident_date > date_received then
						intnx("year", Date_Received, 1, "sameday")
			   		else Date_Received
			   end as Date_Received label=" Date Received" format=date9.,
					coalesce(Airport_Code, "Unknown") "Airport Code" as Airport_Code,
				case
					 when Claim_Type is null then "Unknown"
					 else scan(Claim_Type,1,"/")
					 end as Claim_Type label="Claim Type",
				case
					when Disposition is null then "Unknown"
					when Disposition="Closed: Canceled " then "Closed:Canceled"
					when Disposition= "losed: Contractor Claim" then "Closed:Contractor Claim"
					else Disposition
					end as Disposition,
				 Close_Amount 'Close Amount' format=dollar7.2, 
				 upcase(State) as State, 
				 propcase(StateName) as StateName 'State Name',
				 propcase(County) as County,
				 propcase(City) as City, Claim_Site 'Claim Site'
		from cs.Claims_NoDup
		where year(incident_date) between 2013 and 2017
		order by Airport_code, Incident_Date;
quit;


proc sql;
/* Create View TotalClaims */
create view TotalClaims as
	select  Airport_Code, Airport_Name, City, State, Year(Incident_Date) as year, count(*) as TotalClaims 
	from Claims_Cleaned
	group by Airport_Code, Airport_Name, City, State, Year
	order by Airport_code, year;
quit;


proc sql;
/* Create View TotalEnplanements */
create view TotalEnplanements as
	select LocID, Enplanement, input(Year, 4.) as Year
	from cs.enplanement2017 
	outer union corr
	select LocID, Boarding as Enplanement, Year
	 from cs.Boarding2013_2016
	order by Year, LocID; 

quit;

proc sql;
create table ClaimsByAirport as
	select c.Airport_Code, c.Airport_Name, c.city, c.state, e.year, c.totalclaims, e.Enplanement, TotalClaims/Enplanement as PctClaims format=percent10.4
	from Totalclaims as c inner join TotalEnplanements as e on c.Airport_Code=e.LocID and c.year = e.year  
	order by Airport_Code,Year;
quit;


proc sql;
	title 'How many total enplanements occurred?';
	select sum(Enplanement) as TotalEnplanements format=comma20.
	from totalenplanements;
	
	title 'How many total claims were filed?';
	select sum(totalclaims)
	from totalclaims;
quit;


proc sql;
	title 'What was the average Interval?';
	select avg(Date_Received-Incident_date) as Interval format 4.1
	from claims_cleaned;
run;


proc sql;
	select count(*)
	from claims_cleaned
	where Airport_Code = "Unknown";
run;

proc sql;
/* 	count the different claim types */
	select count(*), claim_type
	from claims_cleaned
	group by claim_type;
quit;

proc sql;
/* Where disposition includes close */
	select count(*)
	from claims_cleaned
	where disposition like '%Closed%'
	group by disposition;
quit;


proc sql;
select Airport_Code, Airport_Name, Year, Enplanement, PctClaims
 from cs.claimsByAirport
 where enplanement > 10000000
 order by PctClaims desc;
quit; 

