--------------------------------------------------------------------------------------
-- LICENSE: CC-BY-NC-SA.  https://creativecommons.org/licenses/by-nc-sa/4.0/deed.pt-br
-- (C) BY Peter Krauss
--------------------------------------------------------------------------------------

-- Dependes on prepare0.sql
-- -- --
-- Function name mnemonics parts:
--  vbit = varbit;
--  hbig = hierarchical bigint, using right_copy and a cache-length at lefy.
--  hint = hierarchical integer, using right_copy and a cache-length at lefy.
--  hsml = hierarchical smallint, using right_copy and a cache-length at lefy.
--

---- Natural Coce in BigInts: the cache-length strategy with left_copy of the value and right_copy of the length.

CREATE FUNCTION natcod.vBit_to_hBig( b varbit, blen int DEFAULT NULL) RETURNS bigint AS $f$
-- penging bug on blen, it not reduce b length, only expands.
  -- max of 57 bits (64-1-6). Left_copy of value by x::bit(64) and right_copy of the bitstring_lenght.
  SELECT overlay( (b'0' || b)::bit(64) PLACING COALESCE(blen,length(b))::bit(6) FROM 59 )::bigint
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hbig
  IS 'Fast conversion and efficient hierarchical representation, from Varbit to Bigint.'
;
CREATE FUNCTION natcod.vBit_to_hInt( b varbit, blen int DEFAULT NULL) RETURNS int AS $f$
  -- max of 26 bits (32-1-5). Left_copy of value by x::bit(32) and right_copy of the bitstring_lenght.
  SELECT overlay( (b'0' || b)::bit(32) PLACING COALESCE(blen,length(b))::bit(5) FROM 28 )::int;
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hint
  IS 'Fast conversion and efficient hierarchical representation, from Varbit to Integer.'
;
CREATE FUNCTION natcod.vBit_to_hSml( b varbit, blen int DEFAULT NULL) RETURNS smallint AS $f$
  -- max of 11 bits (16-1-4). Half_Left_copy of value by x::bit(16)m padding zeros on other left 16 bits.
  -- NÃO precisaria do zero a esqueda do sinal ... mas pode ajudar na equivalência com inteiro... Testar com e sem.
  SELECT overlay( (b'0' || b)::bit(16) PLACING COALESCE(blen,length(b))::bit(4) FROM 13)::int;
  --- testar denovo com b::bit(16)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hsml
  IS 'Fast conversion and efficient hierarchical representation, from Varbit to Smallint.'
;

CREATE FUNCTION natcod.hdist( a bigint, b bigint DEFAULT 0) RETURNS bigint AS $f$
  SELECT (abs(arot-brot)<<6) + abs(alen-blen)
  FROM (select a>>6, a&31::bigint, b>>6, b&31::bigint) t(arot,alen, brot,blen)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hdist(bigint,bigint)
  IS 'Hierarchical distance, between two hBigs.'
;
CREATE FUNCTION natcod.hdist( a int, b int DEFAULT 0) RETURNS int AS $f$
  SELECT abs(arot-brot)<<6+abs(alen-blen)
  FROM (select a>>6, a&31, b>>6, b&31) t(arot,alen, brot,blen)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hdist(int,int)
  IS 'Hierarchical distance, between two hInts.'
;

CREATE FUNCTION natcod.hdist_log(
  a bigint,
  b bigint DEFAULT 0
  -- bits_cache int default 6
) RETURNS real AS $f$
  -- normalizado por bits_ref, log(9223372036854775807::bigint>>bits_cache)=17.158709752846928;
  SELECT CASE WHEN a=b THEN 0 ELSE round(100.0*log(abs(a-b))/18.968::float,5)::real END
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hdist(bigint,bigint)
  IS 'Normalized Log of hierarchical distance, between two hBigs.'
;

CREATE FUNCTION natcod.hBig_to_length( x bigint) RETURNS int AS $f$
  SELECT (x&63::bigint)::int
$f$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION natcod.hBig_to_vBit( x bigint) RETURNS varbit AS $f$
  SELECT substring( x::bit(64) from 2 for (x&63)::int );
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hbig_to_vbit
  IS 'Fast conversion, from efficient hierarchical Bigint representation to Varbit.'
;
CREATE FUNCTION natcod.hInt_to_vBit( x int) RETURNS varbit AS $f$
  SELECT substring( x::bit(32) from 2 for x&31 );
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hint_to_vbit
  IS 'Fast conversion, from efficient hierarchical Int representation to Varbit.'
;
CREATE FUNCTION natcod.hSml_to_vBit( x smallint) RETURNS varbit AS $f$
  SELECT substring( x::int::bit(32) from 18 for x&15 ); -- max(x&15)=16; max(x)=32767
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.hsml_to_vbit
  IS 'Fast conversion, from efficient hierarchical Smallint representation to Varbit.'
;

------
-- MISC convertions:

CREATE FUNCTION natcod.vbit_to_hbig(p text) RETURNS bigint AS $wrap$
  SELECT natcod.vbit_to_hbig(p::varbit)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hbig(text)
  IS 'A wrap for vbit_to_hbig(varbit).'
;
CREATE FUNCTION natcod.vbit_to_hbig(
    x varbit,
    n int,
    p int -- n::bit(8..32) || x
) RETURNS bigint as $f$  -- hb_encode
  SELECT natcod.vbit_to_hbig(
    CASE p
      WHEN 8  THEN n::bit(8)::varbit
      WHEN 9  THEN n::bit(9)::varbit
      WHEN 10 THEN n::bit(10)::varbit
      ELSE n::bit(32)::varbit
    END || x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_hbig(varbit,int,int)
  IS 'Converts n::bit(p) || varbit into a Bigint representing hidden-bit (hb).'
;

CREATE FUNCTION natcod.hiddenBig_to_hBig(x bigint) RETURNS bigint AS $f$
   SELECT natcod.vbit_to_hbig( natcod.hiddenBig_to_vBit(x) );
$f$ LANGUAGE SQL IMMUTABLE;


--------------------
-- DROP FUNCTION natcod.generate_vbit_series_didactic;
CREATE FUNCTION natcod.generate_vbit_series_didactic(bit_len int)
RETURNS TABLE (
  s varbit, len int, rval int, lval int, lval_rot int,
  "lval_rot+len" int,
  rval_bin varbit, lval_bin varbit, len_bin varbit, "bin(lval_rot+len)" varbit
) AS $f$
  SELECT s,len,rval,lval,
         lval<<llen, -- lval_rot,
         len + (lval<<llen), -- lval_rot+len. use (natcod.bitlength(bit_len)+1) for empty string = 0
         substring(rval::bit(32),b32len), -- as rval_bin,
         substring(lval::bit(32),b32len), -- as lval_bin,
         len_bin,
         substring( (length(s) + (lval<<llen))::bit(32), 33-bit_len-llen)
  FROM (
    SELECT *, natcod.bitlength(bit_len) as llen,
        32-bit_len+1 as b32len,
        substring(length(s)::bit(32),33-natcod.bitlength(bit_len)) as len_bin
    FROM (
      SELECT s, length(s) as len,
         varbit_to_int(s) as rval, -- conferir se mesmo que natcod.vbit_to_intval()
         (b'0'||s)::bit(32)::int>>(32-bit_len-1) as lval
      FROM natcod.generate_vbit_series(bit_len) t1(s)
    ) t2
  ) t3
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.generate_vbit_series_didactic(int)
IS 'Obtain a sequency and didactic explain of Natural Codes of bit_len, and right-copy value, left-copy-value, etc.'
;
