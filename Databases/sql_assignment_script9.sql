/*sqlAssginment_8_Stored_Procedures
Setps 7*/

--Step 7.A
--Create Sequence
CREATE SEQUENCE rent_num_seq 
  START WITH 1100
  INCREMENT BY 1
  NOCACHE;

--Step 7.B
--Alter TY_PRICE table
ALTER TABLE TY_PRICE 
  ADD PRICE_RENTDAYS NUMBER(2,0) DEFAULT 3 NOT NULL;

--Step 7.C
--Update TY_PRICE table
UPDATE TY_PRICE SET PRICE_RENTDAYS = 5 WHERE PRICE_CODE = 1;
UPDATE TY_PRICE SET PRICE_RENTDAYS = 3 WHERE PRICE_CODE = 2;
UPDATE TY_PRICE SET PRICE_RENTDAYS = 5 WHERE PRICE_CODE = 3;
UPDATE TY_PRICE SET PRICE_RENTDAYS = 7 WHERE PRICE_CODE = 4;

--Step 7.D
--Create Stored Procedure: prc_new_rental
CREATE OR REPLACE PROCEDURE PRC_NEW_RENTAL 
(
  V_MEM_NUM IN VARCHAR2 
) AS
  is_mem_num_exist  TY_MEMBERSHIP.MEM_NUM%TYPE;
  previous_mem_balance TY_MEMBERSHIP.MEM_BALANCE%TYPE;
BEGIN
  SELECT COUNT(TY_MEMBERSHIP.MEM_NUM) INTO is_mem_num_exist
    FROM TY_MEMBERSHIP
    WHERE TY_MEMBERSHIP.MEM_NUM = V_MEM_NUM;
  
  IF is_mem_num_exist <= 0 THEN
    --If member does not exist, Skip everything else
    SYS.DBMS_OUTPUT.PUT_LINE('Member Number: ' || V_MEM_NUM || ' Does not Exist!');
  ELSE
    --remaining procedures will be here
    --GET previous balance of the member
    SELECT TY_MEMBERSHIP.MEM_BALANCE INTO previous_mem_balance 
      FROM TY_MEMBERSHIP
      WHERE TY_MEMBERSHIP.MEM_NUM = V_MEM_NUM;
    
    --Display message
    SYS.DBMS_OUTPUT.PUT_LINE('For Member Number: ' || V_MEM_NUM 
      || ' The Previous Balance is: $'|| previous_mem_balance || '.00');
    
    --Add new Rental to the table
    INSERT INTO TY_RENTAL (RENT_NUM, RENT_DATE, MEM_NUM)
      VALUES (RENT_NUM_SEQ.NEXTVAL, SYSDATE, V_MEM_NUM);
  END IF;
END PRC_NEW_RENTAL;

--Step 7.E
--Create Stored Procedure: prc_new_detail
CREATE OR REPLACE PROCEDURE PRC_NEW_DETAIL 
(
  V_VID_NUM IN VARCHAR2 
) AS
  is_vid_num_exist  TY_VIDEO.VID_NUM%TYPE;
  is_vid_available  TY_VIDEO.VID_STATUS%TYPE;
  movie_due_date  TY_DETAILRENTAL.DETAIL_DUEDATE%TYPE;
  rental_fee  TY_PRICE.PRICE_RENTFEE%TYPE;
  daily_late_fee  TY_PRICE.PRICE_DAILYLATEFEE%TYPE;
  num_rent_days TY_PRICE.PRICE_RENTDAYS%TYPE;
  video_due_date DATE;
  next_rent_num TY_DETAILRENTAL.RENT_NUM%TYPE;
BEGIN
  --verify the video number exists
  SELECT COUNT(TY_VIDEO.VID_NUM) INTO is_vid_num_exist
    FROM TY_VIDEO 
    WHERE VID_NUM = V_VID_NUM;
    
    IF is_vid_num_exist <=0 THEN
      SYS.DBMS_OUTPUT.PUT_LINE('Video Number: ' || V_VID_NUM || ' Does not exist!');
    ELSE
      --get the status of the video
      SELECT TY_VIDEO.VID_STATUS INTO is_vid_available
      FROM TY_VIDEO
      WHERE VID_NUM = V_VID_NUM;
      
      IF is_vid_available <> 'IN' THEN
        --get due date
        SELECT TY_DETAILRENTAL.DETAIL_DUEDATE INTO movie_due_date
        FROM TY_DETAILRENTAL
          WHERE VID_NUM = V_VID_NUM;
        --display message with date  
        SYS.DBMS_OUTPUT.PUT_LINE('Video Number: ' || V_VID_NUM 
          || ' has current status of: ' || is_vid_available
          || '. The movie is due on: ' || movie_due_date
          || ' please wait until then.');          
      ELSE
        --status IN
        --get rental_fee, daily_late_fee, num_rent_days in price
        --Since these values are not in TY_VIDEO we will need to join tables
        SELECT 
          TY_PRICE.PRICE_RENTFEE,
          TY_PRICE.PRICE_DAILYLATEFEE,
          TY_PRICE.PRICE_RENTDAYS
          INTO rental_fee, daily_late_fee, num_rent_days
          FROM TY_VIDEO 
            JOIN TY_MOVIE USING (MOVIE_NUM)
            JOIN TY_PRICE USING (PRICE_CODE)
            WHERE TY_VIDEO.VID_NUM = V_VID_NUM;
          
          --**Prove above query works**
          --SYS.DBMS_OUTPUT.PUT_LINE('INFO DUMP: '
          --|| rental_fee || ' ' 
          --|| daily_late_fee || ' ' 
          --|| num_rent_days);
          --testing only above
          
        --calculate due date
        video_due_date := TO_DATE(TO_CHAR(SYSDATE, 'MM/DD/YYYY') 
          || '23:59:59', 'MM/DD/YYYY HH24:MI:SS') + num_rent_days;
        --Prove video_due_date is correct
        --SYS.DBMS_OUTPUT.PUT_LINE(video_due_date);
        --testing worked!
        
        --Insert new rental into detailrental
        --get rentnum
        next_rent_num := RENT_NUM_SEQ.CURRVAL;
        --update TY_RENTAL first
        
        INSERT INTO TY_DETAILRENTAL
          (TY_DETAILRENTAL.RENT_NUM,
            TY_DETAILRENTAL.VID_NUM, 
            TY_DETAILRENTAL.DETAIL_FEE, 
            TY_DETAILRENTAL.DETAIL_DUEDATE, 
            TY_DETAILRENTAL.DETAIL_DAILYLATEFEE)
          VALUES 
            (next_rent_num, 
              V_VID_NUM, 
              rental_fee,
              video_due_date,
              daily_late_fee);
        
        --Although not stated in the assignment, the video status should be set to
        --OUT at this time.
        --The code to do that is below
        UPDATE TY_VIDEO SET VID_STATUS = 'OUT'
          WHERE VID_NUM = V_VID_NUM;       
      END IF;        
    END IF;
END PRC_NEW_DETAIL;

--Step 7.F
--Create Stored Procedure: prc_return_video
CREATE OR REPLACE PROCEDURE PRC_RETURN_VIDEO 
(
  V_VID_NUM IN VARCHAR2 
) AS 
  is_vid_exist  TY_VIDEO.VID_NUM%TYPE;
  row_detail_rental TY_DETAILRENTAL%ROWTYPE;
  verify_single_detail  NUMBER(3,0);
BEGIN
  --check for exising video
  SELECT COUNT(TY_VIDEO.VID_NUM) INTO is_vid_exist
    FROM TY_VIDEO
    WHERE VID_NUM = V_VID_NUM;
    
  IF is_vid_exist <= 0 THEN
    SYS.DBMS_OUTPUT.PUT_LINE('Video number: ' || V_VID_NUM || ' Does not exist!');
  ELSE
    SELECT COUNT(DETAIL_RETURNDATE) 
      INTO verify_single_detail 
      FROM TY_DETAILRENTAL
      WHERE VID_NUM = V_VID_NUM
        AND DETAIL_RETURNDATE = NULL;
    
    IF verify_single_detail > 1 THEN
      --too many records!!
      SYS.DBMS_OUTPUT.PUT_LINE('ERROR: MORE THAN 1 RECORD FOR VIDEO NUMBER: ' || V_VID_NUM);
    ELSIF verify_single_detail = 1 THEN
      --Only 1 video oustanding found
      UPDATE TY_DETAILRENTAL SET DETAIL_RETURNDATE = TO_DATE(TO_CHAR(SYSDATE, 'MM/DD/YYYY HH24:MI:SS'))
        WHERE VID_NUM = V_VID_NUM;        
      UPDATE TY_VIDEO SET TY_VIDEO.VID_STATUS = 'IN'
        WHERE VID_NUM = V_VID_NUM;
      SYS.DBMS_OUTPUT.PUT_LINE('THE Video: ' || V_VID_NUM || ' has been successfully returned');
    ELSE
      --0 only
      UPDATE TY_VIDEO SET TY_VIDEO.VID_STATUS = 'IN'
        WHERE VID_NUM = V_VID_NUM;
        SYS.DBMS_OUTPUT.PUT_LINE('Video: ' || V_VID_NUM || ' has been successfully returned');
    END IF;
  END IF;
END PRC_RETURN_VIDEO;

--Step 7.G
--Create Stored Procedure: prc_delete_member
CREATE OR REPLACE PROCEDURE PRC_DELETE_MEMBER 
(
  V_MEM_NUM IN VARCHAR2 
) AS
  does_member_exist TY_MEMBERSHIP.MEM_NUM%TYPE;
  total_num_rentals NUMBER(3,0);
  the_rent_num  TY_RENTAL.RENT_NUM%TYPE;
  l_counter integer := 1;
  
BEGIN
  --verify member
  SELECT COUNT(TY_MEMBERSHIP.MEM_NUM) INTO does_member_exist
    FROM TY_MEMBERSHIP
      WHERE MEM_NUM = V_MEM_NUM;
  
  IF does_member_exist <> 1 THEN
    SYS.DBMS_OUTPUT.PUT_LINE('Member does not exist!');
  ELSE
    --EXISTS
    SELECT COUNT(TY_RENTAL.MEM_NUM) INTO total_num_rentals
      FROM TY_RENTAL
        WHERE MEM_NUM = V_MEM_NUM;
    
    SYS.DBMS_OUTPUT.PUT_LINE('This member exists and has: ' || total_num_rentals
      || ' rentals!');
    IF total_num_rentals = 1 THEN
      SELECT TY_RENTAL.RENT_NUM INTO the_rent_num
        FROM TY_RENTAL
          WHERE MEM_NUM = V_MEM_NUM;
          --All Data erased, erase Membership!
      DELETE FROM TY_DETAILRENTAL WHERE RENT_NUM = the_rent_num;
      DELETE FROM TY_RENTAL WHERE TY_RENTAL.MEM_NUM = V_MEM_NUM;
      DELETE FROM TY_MEMBERSHIP WHERE TY_MEMBERSHIP.MEM_NUM = V_MEM_NUM;
    ELSIF total_num_rentals > 1 THEN      
      --Loop through all the rows, call select each time to get the new item
      LOOP
        SELECT RENT_NUM INTO the_rent_num
          FROM TY_RENTAL
          WHERE MEM_NUM = V_MEM_NUM and rownum = 1;
       SYS.DBMS_OUTPUT.PUT_LINE(the_rent_num);        
       --Delete Child value
        DELETE FROM TY_DETAILRENTAL WHERE RENT_NUM = the_rent_num;
        --Delete parent value ONLY where the rent num is. 
        DELETE FROM TY_RENTAL WHERE TY_RENTAL.MEM_NUM = V_MEM_NUM and RENT_NUM = the_rent_num;
        IF l_counter = total_num_rentals THEN--loop until all rentals are gone
          EXIT;          
        END IF;
        l_counter := l_counter +1;
        COMMIT;
      END LOOP;
    END IF;
    DELETE FROM TY_MEMBERSHIP WHERE TY_MEMBERSHIP.MEM_NUM = V_MEM_NUM;  
  END IF;
END PRC_DELETE_MEMBER;
--Test Procedure: Status
/*DECLARE
  VIDEO_NUM TY_VIDEO.VID_NUM%TYPE;
  MEM_NUM TY_MEMBERSHIP.MEM_NUM%TYPE;
BEGIN
  VIDEO_NUM := 61388;
  MEM_NUM := 104;
  --PRC_NEW_RENTAL(V_MEM_NUM => MEM_NUM);--update rental first so a new detail can be created
  --PRC_NEW_DETAIL(V_VID_NUM => VIDEO_NUM);--update detail
  --Truthfully I would right this as one procedure taking a member nuber and vid number
  --PRC_RETURN_VIDEO(V_VID_NUM => VIDEO_NUM);
  --PRC_DELETE_MEMBER(V_MEM_NUM => MEM_NUM);
  
END;*/
