
SET NAMES utf8mb4;
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS air_traffic_control_system;
CREATE SCHEMA air_traffic_control_system;
USE air_traffic_control_system;

create table Schedule
(flightNo varchar(10) not null,
origin varchar(3) not null,
destination varchar(3) not null,
takeoffTime datetime not null,
landingTime datetime not null,
planeID bigint(10) references Plane,
primary key(flightNo));

-- Insert values in table: Flight
insert into Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) values 
('6E 1759', 'PNQ', 'LKO', '2022-04-15 09:15:00', '2022-04-15 12:20:00', 12334),
('AI 0171', 'BOM', 'LKO', '2022-04-15 09:20:00', '2022-04-15 14:32:00', 43342),
('AI 9801', 'LKO', 'IXM', '2022-04-15 10:47:00', '2022-04-15 16:40:00', 31342),
('UK 0282', 'LKO', 'CCU', '2022-04-15 10:59:00', '2022-04-15 14:20:00', 24146),
('UK 8768', 'COK', 'LKO', '2022-04-15 09:05:00', '2022-04-15 15:20:00', 86745),
('G8 1103', 'LKO', 'IDR', '2022-04-15 19:23:00', '2022-04-15 20:33:00', 32345),
('G8 9453', 'LKO', 'HYD', '2022-04-15 20:59:00', '2022-04-15 22:26:00', 43130);

create table test(a1 int);

delimiter $$
create trigger trig before insert
on Schedule
for each row
begin
	DECLARE q int;
	select count(*)
    into q
	from
	Schedule
	where
	abs(timediff(takeoffTime, new.takeOffTime)) < 000500;
    insert into test value (q);
	if (q > 0) then
		SIGNAL SQLSTATE '50001' SET MESSAGE_TEXT = 'Insert Unsucessful';
    end if;
end; $$
delimiter ;

-- create table Flight
-- (flightID int(4) not null,
-- planeID bigint(10) references Plane,
-- flightNo varchar(10) references Schedule,
-- realTakeoffTime datetime,
-- estimatedLandingTime datetime,
-- -- noOfSeats int, 
-- primary key(flightID));

-- Insert values in table: Flight
-- insert into Flight values ();

-- create table FlightLanding
-- (flightID int(4) references Flight,
-- status varchar(10),
-- clearance varchar(10),
-- primary key(flightID));

create table Plane
(planeID bigint(10) not null,
companyID int(4) references Company,
planeType varchar(20),
primary key(planeID));

create table Company
(companyID int(4) not null,
companyName varchar(20),
companyAddress varchar(50),
companyNo varchar(10),
primary key(companyID));

