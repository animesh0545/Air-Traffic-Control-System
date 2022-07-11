SET autocommit = ON;

-- Creating schema air-traffic-control-system if it does not exist already
DROP SCHEMA IF EXISTS air_traffic_control_system;
CREATE SCHEMA air_traffic_control_system;
USE air_traffic_control_system;

-- Create table: Schedule
CREATE TABLE Schedule
(flightNo VARCHAR(7) NOT NULL,
origin VARCHAR(3) NOT NULL,
destination VARCHAR(3) NOT NULL,
takeoffTime DATETIME NOT NULL,
landingTime DATETIME DEFAULT NULL,
planeID BIGINT(5) REFERENCES Plane,
PRIMARY KEY(flightNo));

-- Create table: Plane
CREATE TABLE Plane
(planeID INT(5) NOT NULL,
companyID INT(4) REFERENCES Company,
planeType VARCHAR(20) NOT NULL,
PRIMARY KEY(planeID));

-- Create table: Company
CREATE TABLE Company
(companyID INT(4) NOT NULL,
companyName VARCHAR(20) NOT NULL,
companyAddress VARCHAR(200) NOT NULL,
companyNo VARCHAR(10) NOT NULL,
PRIMARY KEY(companyID));

-- Creating view for viewing schedule details
CREATE VIEW schedule_details AS
SELECT * FROM Schedule;

-- Creating view for viewing flight details
CREATE VIEW flight_details AS
SELECT flightNo, a.planeID, companyID, origin, destination, takeoffTime, landingTime, planeType  FROM Schedule a
INNER JOIN Plane b
ON a.planeID = b.planeID;

-- Creating view for viewing complete details of  the flight and the plane used for that flight
CREATE VIEW complete_flight_with_plane_details AS
SELECT flightNo, a.planeID, a.companyID, origin, destination, takeoffTime, landingTime, planeType, companyName, companyAddress, companyNo FROM flight_details a
INNER JOIN Company b
ON a.companyID = b.companyID;

-- Creating a procedure which will check the following constraints on the inserted/updated record:-
-- 1. The origin or the destination of the inserted/updated flight should be 'DEL'.
-- 2. The inserted/updated record should follow some constraints on the attribute values based on 
--    the specifications and assumptions of our Air Traffic Control System model. Like when the flight
--    is coming to the Delhi airport then it should have the takeOffTime greater than the landingTime and
--    when it is leaving the Delhi airport for some other destination, it should have the landingTime as NULL.
-- 3. The inserted/updated record is clashing with any existing record or not (by clashing, 
--    we mean the absolute difference between the landingTime or takeoffTime of the inserted/updated flight
--    and any other flight record already present in the table is less that 5 minutes).
-- If any of the above specifications is not satistfied then an appropriate error message is displayed and the
-- the insertion/updation is reverted back else the record is inserted/updated in the Schedule table permanently.
DELIMITER %%
CREATE PROCEDURE
`constraints_check`(IN flightNo VARCHAR(7), IN origin VARCHAR(3), IN destination VARCHAR(3), IN takeoffTime DATETIME, IN landingTime DATETIME, IN operation VARCHAR(6))
 COMMENT 'constraints check on the inserted/updated record'
BEGIN
	DECLARE takeoffTimeClashingFlightCount INT;
	DECLARE landingTimeClashingFlightCount INT;
    
    IF (destination = 'DEL') THEN
		IF (landingTime IS NULL) THEN
			SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Flight coming to Delhi airport must not have landingTime as NULL');
			SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = @MESSAGE_TEXT;
		ELSEIF (takeoffTime <= landingTime) THEN
			SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Flight coming to Delhi airport must have takeoffTime greater than landingTime');
			SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = @MESSAGE_TEXT;
        END IF;
    
    ELSEIF (origin = "DEL") THEN
		IF (landingTime IS NOT NULL) THEN
			SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Flight going from Delhi airport to some other destination must have landingTime as NULL');
			SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = @MESSAGE_TEXT;
		END IF;
	ELSE
		SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Flight should have either origin or destination as DEL');
		SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = @MESSAGE_TEXT;
	END IF;
    
	SELECT COUNT(*)
		INTO takeoffTimeClashingFlightCount
	FROM
		Schedule s
	WHERE
		s.flightNo != flightNo AND (ABS(TIMEDIFF(s.takeoffTime, takeOffTime)) < 000500 OR IFNULL(ABS(TIMEDIFF(s.landingTime, takeOffTime)), 000500) < 000500);
    
	SELECT count(*)
		INTO landingTimeClashingFlightCount
	FROM
		Schedule s
	WHERE
		s.flightNo != flightNo AND (IFNULL(ABS(TIMEDIFF(s.landingTime, landingTime)), 000500) < 000500 OR IFNULL(ABS(TIMEDIFF(s.takeoffTime, landingTime)), 000500) < 000500);
    
    IF (takeoffTimeClashingFlightCount > 0 && landingTimeClashingFlightCount > 0) THEN
		SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Clash b/w this flight\'s takeoffTime/landingTime and some other flight\'s takeoffTime/landingTime');
		SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = @MESSAGE_TEXT;
	ELSEIF (takeoffTimeClashingFlightCount > 0) THEN
		SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Clash b/w this flight\'s takeoffTime and some other flight\'s takeoffTime/landingTime');
		SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = @MESSAGE_TEXT;
    ELSEIF (landingTimeClashingFlightCount > 0) THEN
		SET @MESSAGE_TEXT = CONCAT(operation, ' Unsucessful. Clash b/w this flight\'s landingTime and some other flight\'s takeoffTime/landingTime');
		SIGNAL SQLSTATE '45007' SET MESSAGE_TEXT = @MESSAGE_TEXT;
    END IF;
END%%

-- Creating procedure to delete record from the Schedule table with the given flightNo(primary key)
-- If such a record does not exist then display an error message that the flight record with given flightNo does not exist
DELIMITER **
CREATE PROCEDURE `delete_record_with_key`(IN fNo VARCHAR(7))
BEGIN
	IF (EXISTS(SELECT * FROM Schedule WHERE flightNo = fNo)) THEN
		DELETE FROM Schedule WHERE flightNo = fNo;
	ELSE
		SIGNAL SQLSTATE '45008' SET MESSAGE_TEXT = 'Deletion Unsucessful. Flight record with given flightNo does not exist';
	END IF;
END**
DELIMITER ;

-- Creating trigger to insert a record in the Schedule table if the specified conditions on the inserted record are satisfied
DELIMITER $$
CREATE TRIGGER `trig_insert` AFTER INSERT
ON Schedule
FOR EACH ROW
BEGIN
	CALL constraints_check(NEW.flightNo, NEW.origin, NEW.destination, NEW.takeoffTime, NEW.landingTime, 'Insert');
END; $$
DELIMITER ;

-- Creating trigger to update a record in the Schedule table if the specified conditions on the updated record are satisfied
DELIMITER //
CREATE TRIGGER `trig_update` AFTER UPDATE
ON Schedule
FOR EACH ROW
BEGIN
	CALL constraints_check(NEW.flightNo, NEW.origin, NEW.destination, NEW.takeoffTime, NEW.landingTime, 'Update');
END; //
DELIMITER ;

-- Insert values in table: Schedule
INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUES 
('6E 1759', 'PNQ', 'DEL', '2022-04-15 12:20:00', '2022-04-15 09:15:00', 12334),
('AI 2171', 'BOM', 'DEL', '2022-04-15 14:32:00', '2022-04-15 09:20:00', 43342),
('AI 9801', 'DEL', 'IXM', '2022-04-15 10:47:00', NULL, 43342),
('UK 5282', 'DEL', 'CCU', '2022-04-15 10:59:00', NULL, 24146),
('UK 8768', 'COK', 'DEL', '2022-04-15 15:20:00', '2022-04-15 09:05:00', 24146),
('G8 1103', 'DEL', 'IDR', '2022-04-15 19:23:00', NULL, 32345),
('G8 9453', 'DEL', 'HYD', '2022-04-15 20:59:00', NULL, 32345),
('6E 2051', 'LKO', 'DEL', '2022-04-15 21:49:00', '2022-04-15 12:30:00', 10974),
('UK 7881', 'DEL', 'COK', '2022-04-15 17:27:00', NULL, 10974),
('AI 1248', 'IXA', 'DEL', '2022-04-15 13:00:00', '2022-04-15 8:12:00', 12334);

-- Insert values in table: Plane
INSERT INTO Plane(planeID, companyID, planeType) VALUES
(12334, 4431, "Passenger Aircraft"),
(43342, 4431, "Cargo Aircraft"),
(24146, 4432, "Passenger Aircraft"),
(32345, 4442, "Passenger Aircraft"),
(10974, 4451, "Cargo Aircraft");

-- Insert values in table: Company
INSERT INTO Company(companyID, companyName, companyAddress, companyNo) VALUES
(4431, "Airbus", "4 & 4A, Whitefield Main Rd, Dyavasandra Industrial Area, Mahadevapura, Bengaluru, Karnataka 560048", "9437853946"),
(4432, "Airbus", "4 & 4A, Whitefield Main Rd, Dyavasandra Industrial Area, Mahadevapura, Bengaluru, Karnataka 560048", "9437853926"),
(4442, "Boeing", "Lake View Building, Bagmane Tech Park Rd, Krishnappa Garden, C V Raman Nagar, Bengaluru, Karnataka 560093", "9535345146"),
(4451, "Dassault Aircraft", "A-280, Bhishma Pitamah Marg, Block A, Defence Colony, New Delhi, Delhi 110049", "9465370183");

-- Queries: 
-- -- DML operations like select, update, and delete to test the functionality of the system

-- -- Error Code: 1644. Insert Unsucessful. Flight coming to Delhi airport must not have landingTime as NULL
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('AI 1273', 'JRH', 'DEL', '2022-04-15 21:45:00', NULL, 12857);

-- -- Error Code: 1644. Insert Unsucessful. Flight coming to Delhi airport must have takeoffTime greater than landingTime
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('AI 1273', 'JRH', 'DEL', '2022-04-15 14:35:00', '2022-04-15 21:45:00', 12857);

-- -- Error Code: 1644. Insert Unsucessful. Flight going from Delhi airport to some other destination must have landingTime as NULL
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('AI 1273', 'DEL', 'JRH', '2022-04-15 21:25:00', '2022-04-15 14:35:00', 12857);

-- -- Error Code: 1644. Insert Unsucessful. Flight should have either origin or destination as DEL
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('6E 2194', 'IXM', 'LKO', '2022-04-15 21:25:00', '2022-04-15 14:35:00', 12857);

-- -- Error Code: 1644. Insert Unsucessful. Clash b/w this flight's takeoffTime/landingTime and some other flight's takeoffTime/landingTime
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('UK 1131', 'JRH', 'DEL', '2022-04-15 21:45:00', '2022-04-15 08:16:00', 12857);

-- -- Error Code: 1644. Insert Unsucessful. Clash b/w this flight's takeoffTime and some other flight's takeoffTime/landingTime
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('AI 1273', 'JRH', 'DEL', '2022-04-15 21:45:00', '2022-04-15 16:35:00', 12857);

-- -- Error Code: 1644. Insert Unsucessful. Clash b/w this flight's landingTime and some other flight's takeoffTime/landingTime
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('6E 8714', 'JRH', 'DEL', '2022-04-15 19:37:00', '2022-04-15 08:16:00', 12857);

-- -- Successful Insertion
-- INSERT INTO Schedule(flightNo, origin, destination, takeoffTime, landingTime, planeID) VALUE
-- ('6E 8714', 'JRH', 'DEL', '2022-04-15 19:37:00', '2022-04-15 08:26:00', 12857);

-- -- Error Code: 1644. Update Unsucessful. Flight going from Delhi airport to some other destination must have landingTime as NULL
-- UPDATE Schedule SET destination = 'VNS', landingTime = '2022-04-15 08:16:00' WHERE flightNo = 'AI 9801';

-- -- Error Code: 1644. Update Unsucessful. Clash b/w this flight's landingTime and some other flight's takeoffTime/landingTime
-- UPDATE Schedule SET origin = 'IXM', destination = 'DEL', landingTime = '2022-04-15 08:16:00' WHERE flightNo = 'AI 9801';

-- -- Successful Updation
-- UPDATE Schedule SET origin = 'IXM', destination = 'DEL', landingTime = '2022-04-15 08:56:00' WHERE flightNo = 'AI 9801';

-- -- Error Code: 1644. Deletion Unsucessful. Flight record with given flightNo does not exist
-- CALL delete_record_with_key('G8 9999');

-- -- Successful Deletion of a record with the given primary key value
-- CALL delete_record_with_key('G8 1103');

-- -- Selecting records from the view schedule_details
-- SELECT * FROM schedule_details;

-- -- Selecting records from the view flight_details
-- SELECT * FROM flight_details;

-- -- Selecting records from the view complete_flight_with_plane_details
-- SELECT * FROM complete_flight_with_plane_details;

-- -- Dropping tables
-- DROP TABLE Schedule, Plane, Company;

-- -- Dropping database
-- DROP DATABASE air_traffic_control_system;
