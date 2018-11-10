DECLARE
	l_start integer := 0;
	l_end integer := 50;
	l_counter integer := 1;
BEGIN
	LOOP
		l_start := l_start + l_start;
		l_counter := l_counter + 1;
		IF l_counter > l_end THEN
			EXIT;
		END IF;
	END LOOP;
END;