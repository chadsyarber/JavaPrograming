--Assignment 8 Triggers
--Set-up step 5.A.
ALTER TABLE TY_DETAILRENTAL ADD DETAIL_DAYSLATE NUMBER(3,0);

--Set-up Step 5.B.
ALTER TABLE TY_VIDEO
  ADD VID_STATUS VARCHAR(4) DEFAULT 'IN' NOT NULL
    CHECK (VID_STATUS IN ('IN', 'OUT', 'LOST'));

--Set-up Step 5.C.
UPDATE TY_VIDEO
  SET VID_STATUS = 'OUT'
  WHERE VID_NUM IN
    (SELECT VID_NUM FROM TY_DETAILRENTAL
      WHERE DETAIL_RETURNDATE IS NULL);

--Add Trigger 5.D
CREATE OR REPLACE TRIGGER TRG_LATE_RETURN 
BEFORE UPDATE OF DETAIL_RETURNDATE, DETAIL_DUEDATE ON TY_DETAILRENTAL 
FOR EACH ROW  
DECLARE
  new_detail_return TY_DETAILRENTAL.DETAIL_RETURNDATE%TYPE;
  new_detail_duedate TY_DETAILRENTAL.DETAIL_DUEDATE%TYPE;   
BEGIN
  new_detail_return := :NEW.DETAIL_RETURNDATE;
  new_detail_duedate := :NEW.DETAIL_DUEDATE;
  --Determinations
  IF new_detail_return IS NULL THEN
    :NEW.DETAIL_DAYSLATE := NULL;
  ELSIF (new_detail_return > new_detail_duedate) THEN
    :NEW.DETAIL_DAYSLATE := (new_detail_return - new_detail_duedate);
  ELSIF (new_detail_return = new_detail_duedate +1)
    AND (TO_CHAR(new_detail_return, 'HH24:MI:SS') >= '12:00:00') THEN
    :NEW.DETAIL_DAYSLATE := 1;
  ELSE
    :NEW.DETAIL_DAYSLATE :=0;  
  END IF; 
END;

--ADD Trigger 5.E.
CREATE OR REPLACE TRIGGER TRG_MEM_BALANCE 
AFTER UPDATE OF DETAIL_DUEDATE, DETAIL_RETURNDATE ON TY_DETAILRENTAL
FOR EACH ROW 
DECLARE
  new_calc_late_fee  TY_MEMBERSHIP.MEM_BALANCE%TYPE;
  old_calc_late_fee TY_MEMBERSHIP.MEM_BALANCE%TYPE;
  late_fee_value TY_MEMBERSHIP.MEM_BALANCE%TYPE;
  new_mem_num TY_MEMBERSHIP.MEM_NUM%TYPE;  
BEGIN  
  new_calc_late_fee := :NEW.DETAIL_DAILYLATEFEE * :NEW.DETAIL_DAYSLATE;
  old_calc_late_fee := :OLD.DETAIL_DAILYLATEFEE * :OLD.DETAIL_DAYSLATE;
  --CHECK For NULL values
  IF(new_calc_late_fee IS NULL) THEN
    new_calc_late_fee := 0;
  END IF;
  
  IF(old_calc_late_fee IS NULL) THEN
    old_calc_late_fee := 0;
  END IF;
  --Check for the calculated fee
  IF(new_calc_late_fee >= old_calc_late_fee) THEN
    late_fee_value := new_calc_late_fee - old_calc_late_fee;
  ELSE
    late_fee_value := old_calc_late_fee - new_calc_late_fee;
  END IF;  
  --Find the Member number that activated the event
  IF(late_fee_value <> 0) THEN
    SELECT MEM_NUM INTO new_mem_num
      FROM TY_RENTAL
        WHERE RENT_NUM = :NEW.RENT_NUM;
    --After finding the member number set his new balance to include the late_fee
    UPDATE TY_MEMBERSHIP SET 
      TY_MEMBERSHIP.MEM_BALANCE = TY_MEMBERSHIP.MEM_BALANCE + late_fee_value
      WHERE TY_MEMBERSHIP.MEM_NUM = new_mem_num;
  END IF;  
END;

--ADD Trigger 5.F.
CREATE OR REPLACE TRIGGER TRG_LATEFEE_UPDATE 
BEFORE UPDATE OF PRICE_RENTFEE ON TY_PRICE 
FOR EACH ROW 
DECLARE
  cur_rent_fee  TY_PRICE.PRICE_DAILYLATEFEE%TYPE;
  calc_rent_fee  TY_PRICE.PRICE_RENTFEE%TYPE;
BEGIN
  cur_rent_fee := :OLD.PRICE_DAILYLATEFEE; --Before Update occurs
  calc_rent_fee := :NEW.PRICE_RENTFEE * .1; --10% of the change

  --Determine the greater value, if calc then set the dailylatefee
  --Else do nothing
  IF(calc_rent_fee > cur_rent_fee) THEN
    :NEW.PRICE_DAILYLATEFEE := calc_rent_fee;
  END IF;
END;

/*
* I was able to follow this assignment MUCH better than the last one.
* Triggers and PL/SQL in general is much more my style. THIS makes sense and
* can easily be tested. Unlike pure SQL which is a pass fail situation, PL/SQL 
* allows me to work slowly through a problem, solving each step one at time to 
* eventually get to the solution. 
* */
