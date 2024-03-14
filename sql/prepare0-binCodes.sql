--------------------------------------------------------------------------------------
-- LICENSE: APACHE 2.0.  https://www.apache.org/licenses/LICENSE-2.0
--------------------------------------------------------------------------------------

DROP SCHEMA IF EXISTS natcod CASCADE;
CREATE SCHEMA natcod;

-- -- --
-- Function name mnemonics parts:
--  h as "hierarchical" Natural Codes:
--   hbig = hierarchical bigint, using right_copy and a cache-length at lefy.
--   hint = hierarchical integer, using right_copy and a cache-length at lefy.
--   hsml = hierarchical smallint, using right_copy and a cache-length at lefy.
--  kbig = hierarchical bigint, using left_copy and a bit-1 mark at right. (need it?)
--  vbit = varbit;
--  str = text with base n representation of vbit;
--  strbit = text of "0"s and "1"s, obtained by vbit::text.
--

----------------
-- BEIGIN Publib: see http://git.addressforall.org/pg_pubLib
-- Public LIB (adding or updating commom functions for general use)

CREATE or replace FUNCTION ROUND(float,int) RETURNS NUMERIC AS $wrap$
   SELECT ROUND($1::numeric,$2)
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,int)
  IS 'Cast for ROUND(float,x). Useful for SUM, AVG, etc. See also https://stackoverflow.com/a/20934099/287948.'
;

CREATE or replace FUNCTION hex_to_varbit(h text) RETURNS varbit as $f$
 SELECT ('X' || $1)::varbit
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION hex_to_varbit(text)
  IS 'Fast and case-insensitive hexadecimal conversion to varbit.'
;

CREATE or replace FUNCTION varbit_to_int( b varbit, blen int DEFAULT NULL) RETURNS int AS $f$
  -- slower  SELECT (  (b'0'::bit(32) || b) << COALESCE(blen,length(b))   )::bit(32)::int
  -- !loss information about varbit zeros and empty varbit
  -- max of 31 bits , right copy
  SELECT overlay( b'0'::bit(32) PLACING b FROM 33-COALESCE(blen,length(b)) )::int
  -- or faster??  b::bit(32)>>(32-length(b))
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION varbit_to_int
  IS 'Fast and lossy convertion, from varbit to integer. Loss of empty and leading zeros.'
;
-- select b'010101'::bit(32) left_copy, varbit_to_int(b'010101')::bit(32) right_copy;

CREATE or replace FUNCTION varbit_to_bigint( b varbit, blen int DEFAULT NULL) RETURNS bigint AS $f$
  -- !loss information about varbit zeros and empty varbit
  SELECT overlay( b'0'::bit(64) PLACING b FROM 65-COALESCE(blen,length(b)) )::bigint
  -- litle bit less faster, SELECT ( (b'0'::bit(64) || b) << bit_length(b) )::bit(64)::bigint
  -- max of 63 bits , right copy
  -- or faster??  b::bit(64)>>(64-length(b))
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION varbit_to_bigint
  IS 'Fast and lossy convertion, from varbit to bigint. Loss of empty and leading zeros.'
;
-- END Publib
----------------


-- GENERAL CONVERT:
-- !important. select b'010101'::bit(64) left_copy, varbit_to_bigint(b'010101')::bit(64) right_copy;

CREATE FUNCTION natcod.strbit_to_vbit(b text, p_len int DEFAULT null) RETURNS varbit AS $f$
   SELECT CASE WHEN p_len>0 THEN  lpad(b, p_len, '0')::varbit ELSE  b::varbit  END
$f$  LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION natcod.bitlength(x bigint) RETURNS int as $f$
  SELECT 65-position(B'1' in x::bit(64))
  --   SELECT CASE WHEN p_x<1 THEN 0 ELSE 1+floor(ln(p_x)/ln(2)) END
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.bitlength(bigint)
  IS 'The bit-length of the value (non-optimized).'
;
CREATE FUNCTION natcod.bitlength(x int) RETURNS int as $f$
  SELECT 33-position(B'1' in x::bit(32))
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.bitlength(int)
  IS 'The bit-length of the value (non-optimized).'
;

CREATE FUNCTION natcod.prefix_to_max(p varbit, len int default 57) RETURNS varbit as $f$
  SELECT substring(p||b'1111111111111111111111111111111111111111111111111111111111111111' from 1 for len)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.prefix_to_max(varbit,int)
  IS 'fill ones to length (unlimited), to obtain the range of a prefix, from itself.'
;

-----------------------------
-- Old functions
CREATE FUNCTION natcod.hiddenBig_to_vBit(x bigint, p int) RETURNS varbit AS $f$  -- hb_decode
  SELECT substring( x_bin from 1+p+position(B'1' in x_bin) )
  FROM (select x::bit(64)) t(x_bin) -- WHERE $1>7 AND $1<4611686018427387904
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hiddenbig_to_vbit(bigint,int)
  IS 'Converts hidden-bit Natural Code BigInt into VarBit. Disregards most significant p bits'
;
CREATE FUNCTION natcod.hiddenBig_to_vBit(x bigint) RETURNS varbit AS $f$  -- hb_decode
  SELECT natcod.hiddenbig_to_vbit(x,0)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hiddenbig_to_vbit(bigint)
  IS 'Wrap function. Converts hidden-bit Natural Code BigInt into VarBit. Disregards most significant p bits'
;
CREATE FUNCTION natcod.vBit_to_hiddenBig(x varbit) RETURNS bigint AS $f$  -- hb_encode
  SELECT overlay( b'0'::bit(64) PLACING (b'1' || x) FROM 64-length(x) )::bigint
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hiddenbig(varbit)
  IS 'Converts VarBit into a hidden-bit Natural Code BigInt.'
;
CREATE FUNCTION natcod.hBig_to_hiddenBig(x bigint) RETURNS bigint AS $f$
   SELECT (x>>(63-len)) | (1::bigint<<len) -- (2^len)::bigint
   FROM (select (x&63::bigint)::int) t(len)
   -- não pode incluir um bit antes pois seria o bit do negativo.
   -- = SELECT natcod.vbit_to_hiddenbig( natcod.hBig_to_vBit(x) );
$f$ LANGUAGE SQL IMMUTABLE;


---- MORE convertions

---- Natural Coce in BigInts: the cache-length strategy with left_copy of the value and right_copy of the length.

------
-- MISC convertions:

---------------
--- CONERT kbig:
-- ... But we need kbig? Only S2 Geometry.
CREATE FUNCTION natcod.kbig_kposition(x bigint) RETURNS smallint as $f$
  SELECT  (  ln(x & (-x))/ln(2)  )::smallint
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.kbig_kposition(bigint)
  IS 'Get the position of the rightmost bit 1, that is the k-mark of kbig.'
;

CREATE FUNCTION natcod.vbit_to_kbig(x varbit) RETURNS bigint as $f$  -- hb_encode left_copy
  SELECT (b'0' || x || b'1')::bit(64)::bigint
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_kbig(varbit)
  IS 'Perform a left-copy of varbit into a bigint, representing hidden-bit Natural Code with a K-Mark at right.'
;
CREATE or replace FUNCTION natcod.kbig_to_vbit(x bigint) RETURNS varbit as $f$
  -- = natcod.kbiglen_to_vbit( x , natcod.kbig_kposition(x) )
  SELECT substring(x::bit(64) from 2 for 62-natcod.kbig_kposition(x))
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.kbig_to_vbit(bigint)
  IS 'Converts left_copy hiherarchical Bigint (kbig), representing hidden-bit Natural Code, into varbit.'
;


---------------
-- -- GENERATE SERIES:

CREATE FUNCTION natcod.generatep_hb_series(bit_len int) RETURNS setof bigint as $f$
  SELECT i::bigint | maxval as x
  FROM (SELECT (2^bit_len)::bigint) t(maxval),
       LATERAL generate_series(0,maxval-1) s(i)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.generatep_hb_series
  IS 'Obtain a sequency of hidden-bit Natural Codes P set (fixed length), from zero to 2^bit_len-1.'
;

CREATE FUNCTION natcod.generate_hb_series(bit_len int) RETURNS setof bigint as $f$
-- See optimized at https://stackoverflow.com/q/75503880/287948
DECLARE
  s text;
BEGIN
  s := 'SELECT * FROM natcod.generatep_hb_series(1)';
  FOR i IN 2..bit_len LOOP
    s := s || ' UNION ALL  SELECT * FROM natcod.generatep_hb_series('|| i::text ||')';
  END LOOP;
  RETURN QUERY EXECUTE s;
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;

CREATE FUNCTION natcod.generate_vbit_series(bit_len int) RETURNS setof varbit as $f$
  SELECT natcod.hiddenbig_to_vbit(hb)
  FROM natcod.generate_hb_series(CASE WHEN bit_len>62 THEN 62 WHEN bit_len<=0 THEN 1 ELSE bit_len END) t(hb) ORDER BY 1
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.generate_vbit_series(int)
  IS 'Obtain a sequency of all Natural Codes of bit_len, with 63>bit_len>0.'
;
