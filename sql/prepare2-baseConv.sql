-- -- --
-- Part of the NatCode library, see also prepare0-binCodes.sql and prepare1-binCodes.sql files.

CREATE SCHEMA IF NOT EXISTS natcod;

-- -- --
-- Function name mnemonics parts:
--  vbit = varbit;
--  str = text with base n representation of vbit;
--


------
------ BASE CONVERT
------

CREATE FUNCTION natcod.vbit_to_baseh(
  p_val varbit,  -- input
  p_base int DEFAULT 4 -- selecting base2h, base4h, base8h, or base16h.
) RETURNS text AS $f$
DECLARE
    vlen int;
    pos0 int;
    ret text := '';
    blk varbit;
    blk_n int;
    bits_per_digit int;
    tr int[] := '{ {1,2,0,0}, {1,3,4,0}, {1,3,5,6} }'::int[]; -- --4h(bits,pos), 8h(bits,pos)
    tr_selected JSONb;
    trtypes JSONb := '{"2":[1,1], "4":[1,2], "8":[2,3], "16":[3,4]}'::JSONb; -- TrPos,bits. Can optimize? by sparse array.
    trpos int;
    baseh "char"[] := array[ -- new 2023 standard for Baseh:
    '[0:15]={G,Q,x,x,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --1. 1 bit in 4h,8h,16h
    '[0:15]={0,1,2,3,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --2. 2 bits in 4h
    '[0:15]={H,M,R,V,x,x,x,x,x,x,x,x,x,x,x,x}'::"char"[], --3. 2 bits 8h,16h
    '[0:15]={0,1,2,3,4,5,6,7,x,x,x,x,x,x,x,x}'::"char"[], --4. 3 bits in 8h
    '[0:15]={J,K,N,P,S,T,Z,Y,x,x,x,x,x,x,x,x}'::"char"[], --5. 3 bits in 16h
    '[0:15]={0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f}'::"char"[]  --6. 4 bits in standard hex
    ]; -- jumpping I,O and L,U,W,X letters;
       -- the standard hexadecimals as https://tools.ietf.org/html/rfc4648#section-6
BEGIN
  vlen := bit_length(p_val);
  tr_selected := trtypes->(p_base::text);  -- can be array instead of JSON
  IF p_val IS NULL OR tr_selected IS NULL OR vlen=0 THEN
    RETURN NULL; -- or  p_retnull;
  END IF;
  IF p_base=2 THEN
    RETURN $1::text; --- direct bit string as string
  END IF;
  bits_per_digit := (tr_selected->>1)::int;
  blk_n := vlen/bits_per_digit;
  pos0  := (tr_selected->>0)::int;
  trpos := tr[pos0][bits_per_digit];
  FOR counter IN 1..blk_n LOOP
      blk := substring(p_val FROM 1 FOR bits_per_digit);
      ret := ret || baseh[trpos][ varbit_to_int(blk,bits_per_digit) ]::text;
      p_val := substring(p_val FROM bits_per_digit+1); -- same as p_val<<(bits_per_digit*blk_n)
  END LOOP;
  vlen := bit_length(p_val);
  IF p_val!=b'' THEN -- vlen % bits_per_digit>0
    trpos := tr[pos0][vlen];
    ret := ret || baseh[trpos][ varbit_to_int(p_val,vlen) ]::text;
  END IF;
  RETURN ret;
END
$f$ LANGUAGE plpgsql IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_baseh
  IS 'Converts bit string to text, using base2h, base4h, base8h or base16h. Uses letters "G" and "H" to sym44bolize non strandard bit strings (0 for44 bases44). Uses extended alphabet (with no letter I,O,U W or X) for base8h and base16h.'
;

CREATE FUNCTION natcod.vbit_to_baseh(
  p_vals varbit[],                 -- input
  p_base integer DEFAULT 4,        -- selecting base2h, base4h, base8h, or base16h.
  p_ordering boolean DEFAULT false -- flag true for ORDER BY varbit, false to preserve array order.
) RETURNS text[]
  language SQL IMMUTABLE
AS $wrap$
 SELECT CASE
    WHEN p_ordering THEN array_agg(natcod.vbit_to_baseh(c,p_base) ORDER BY c)
    ELSE array_agg(natcod.vbit_to_baseh(c,p_base) ORDER BY ord)
    END
 FROM unnest(p_vals) WITH ORDINALITY t(c,ord)
$wrap$;
COMMENT ON FUNCTION natcod.vbit_to_baseh(varbit[],int,boolean)
 IS 'Converts text BaseH array to bit string array, inverse of baseh_to_vbit(array) and a wrap to vbit_to_baseh(scalar).'
;

----

CREATE FUNCTION natcod.b32nvu_to_vbit( p_val text ) RETURNS varbit AS $f$
 -- see old NaturalCodes/src-sql/step01def-lib_NatCod.sql
 DECLARE
   ch  char;
   ret varbit := b'';
   alphabet text  := '0123456789BCDFGHJKLMNPQRSTUVWXYZ';
 BEGIN
   FOREACH ch IN ARRAY regexp_split_to_array(p_val,'') LOOP
      ret := ret || (strpos(alphabet,ch)-1)::bit(5)::varbit;
   END LOOP;
   RETURN ret;
 END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION natcod.b32nvu_to_vbit(text)
  IS 'Faster base32 No-Vogal except U, string to varbit. Algorithm based on strpos.'
;


CREATE FUNCTION natcod.vbit_to_strstd(
  p_val varbit,  -- input
  p_base text DEFAULT '4js' -- selecting base2js? base4js, etc. with no leading zeros.
) RETURNS text AS $f$
DECLARE
    vlen int;
    pos0 int;
    ret text := '';
    blk varbit;
    blk_n int;
    bits_per_digit int;
    trtypes JSONb := '{
      "4js":[0,1,2],"8js":[0,1,3],"16js":[0,1,4],
      "32ghs":[1,4,5],"32hex":[1,1,5],"32nvu":[1,2,5],"32rfc":[1,3,5],
      "64url":[2,8,6],"32js":[1,1,5]
    }'::JSONb; -- var,pos,bits
    base0 "char"[] := array[
      '[0:15]={0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f}'::"char"[] --1. 4, 5 , 16 js
    ];
    base1 "char"[] := array[
       '[0:31]={0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v}'::"char"[] --1=32hex
      ,'[0:31]={0,1,2,3,4,5,6,7,8,9,B,C,D,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z}'::"char"[] --2=32nvu
      ,'[0:31]={A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7}'::"char"[] --3=32rfc
      ,'[0:31]={0,1,2,3,4,5,6,7,8,9,b,c,d,e,f,g,h,j,k,m,n,p,q,r,s,t,u,v,w,x,y,z}'::"char"[] --4=32ghs
    ];
    -- "64url": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    tr_selected JSONb;
    trbase "char"[];
BEGIN
  vlen := bit_length(p_val);
  tr_selected := trtypes->(p_base::text);-- [1=var,2=pos,3=bits]
  IF p_val IS NULL OR tr_selected IS NULL OR vlen=0 THEN
    RETURN NULL; -- or  p_retnull;
  END IF;
  IF p_base='2' THEN
     -- need to strip leading zeros
    RETURN $1::text; --- direct bit string as string
  END IF;
  bits_per_digit := (tr_selected->>2)::int;
  IF vlen % bits_per_digit != 0 THEN
    RETURN NULL;  -- trigging ERROR
  END IF;
  blk_n := vlen/bits_per_digit;
  pos0 = (tr_selected->>1)::int;
  -- trbase := CASE tr_selected->>0 WHEN '0' THEN base0[pos0] ELSE base1[pos0] END; -- NULL! pgBUG?
  trbase := CASE tr_selected->>0 WHEN '0' THEN base0 ELSE base1 END;
  --RAISE NOTICE 'HELLO: %; % % -- %',pos0,blk_n,trbase,trbase[pos0][1];
  FOR counter IN 1..blk_n LOOP
      blk := substring(p_val FROM 1 FOR bits_per_digit);
      ret := ret || trbase[pos0][ varbit_to_int(blk,bits_per_digit) ]::text;
      p_val := substring(p_val FROM bits_per_digit+1);
  END LOOP;
  vlen := bit_length(p_val);
  -- IF p_val!=b'' THEN ERROR
  RETURN ret;
END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_strstd
 IS 'Converts bit string to text, using standard numeric bases (base4js, base32ghs, etc.).'
;

/**
 * Hub function to base conversion. Varbit to String.
 */
CREATE FUNCTION natcod.vbit_to_str(
  p_val varbit,  -- input
  p_base text DEFAULT '4h'
) RETURNS text AS $wrap$
  SELECT CASE WHEN x IS NULL OR p_val IS NULL THEN NULL
    WHEN x[1] IS NULL THEN  natcod.vbit_to_strstd(p_val, x[2])
    ELSE  natcod.vbit_to_baseh(p_val, x[1]::int)  END
  FROM regexp_match(lower(p_base), '^(?:base\-?\s*)?(?:(\d+)h|(\d.+))$') t(x);
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION natcod.vbit_to_str
 IS 'Converts bit string to text, wrap funtion for vbit_to_strstd() and vbit_to_baseh().'
;
--  select natcod.vbit_to_str(b'011010'), natcod.vbit_to_str(b'011010','16h'), natcod.vbit_to_str(b'000111','4js');

-------------
-- INVERSE:

CREATE or replace FUNCTION natcod.baseh_to_vbit(
  p_val text,  -- input
  p_base int DEFAULT 4 -- selecting base2h, base4h, base8h, or base16h.
) RETURNS varbit AS $f$
DECLARE
  tr_hdig jsonb := '{
    "G":[1,0],"Q":[1,1],
    "H":[2,0],"M":[2,1],"R":[2,2],"V":[2,3],
    "J":[3,0],"K":[3,1],"N":[3,2],"P":[3,3],
    "S":[3,4],"T":[3,5],"Z":[3,6],"Y":[3,7]
  }'::jsonb;
  tr_full jsonb := '{
    "0":0,"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,
    "9":9,"a":10,"b":11,"c":12,"d":13,"e":14,"f":15
  }'::jsonb;
  blk text[];
  bits varbit;
  n int;
  i char;
  ret varbit;
  BEGIN
  ret = '';
  p_val = translate(lower(p_val),'ghjkmnpqrstvzy','GHJKMNPQRSTVZY');
  blk := regexp_match(p_val,'^([0-9a-f]*)([GHJKMNP-TVZY])?$');
  IF blk[1] >'' THEN
    FOREACH i IN ARRAY regexp_split_to_array(blk[1],'') LOOP
      ret := ret || CASE p_base
        WHEN 16 THEN (tr_full->>i)::int::bit(4)::varbit
        WHEN 8 THEN (tr_full->>i)::int::bit(3)::varbit
        WHEN 4 THEN (tr_full->>i)::int::bit(2)::varbit
        END;
    END LOOP;
  END IF;
  IF blk[2] >'' THEN
    n = (tr_hdig->blk[2]->>0)::int;
    ret := ret || CASE n
      WHEN 1 THEN (tr_hdig->blk[2]->>1)::int::bit(1)::varbit
      WHEN 2 THEN (tr_hdig->blk[2]->>1)::int::bit(2)::varbit
      WHEN 3 THEN (tr_hdig->blk[2]->>1)::int::bit(3)::varbit
      END;
  END IF;
  RETURN ret;
  END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION natcod.baseh_to_vbit(text,int)
 IS 'Converts text BaseH to bit string, inverse of vbit_to_baseh().'
;

CREATE FUNCTION natcod.baseh_to_vbit(
  p_vals text[],                   -- input
  p_base integer DEFAULT 4,        -- selecting base2h, base4h, base8h, or base16h.
  p_ordering boolean DEFAULT false -- flag true for ORDER BY varbit, false to preserve array order.
) RETURNS varbit[]
  language SQL IMMUTABLE
AS $wrap$
 SELECT CASE
    WHEN p_ordering THEN array_agg(natcod.baseh_to_vbit(c,p_base) ORDER BY c)
    ELSE array_agg(natcod.baseh_to_vbit(c,p_base) ORDER BY ord)
    END
 FROM unnest(p_vals) WITH ORDINALITY t(c,ord)
$wrap$;
COMMENT ON FUNCTION natcod.baseh_to_vbit(text[],int,boolean)
 IS 'Converts text BaseH array to bit string array, inverse of vbit_to_baseh(array).'
;

-----


---

-- DROP FUNCTION IF EXISTS natcod.parents_to_children CASCADE;
CREATE or replace FUNCTION natcod.parents_to_children(
  p_level     real,      -- last lavel to return
  p_l0_list   varbit[],  -- Natcod parents. In AFAcodes the L0 list of scientific codes. Distinct ones.
  p_non_recursive boolean default true,  -- when false returns a recursive list.
  p_majority      boolean default true,  -- when false ignores abnormal p_l0_list, with non-uniform lenght.
  p_non_repeat    boolean default true   -- mode false=repeat, true=non-repet on level 0, NULL=non-repeat level x
) RETURNS varbit[] language SQL IMMUTABLE
AS $f$
 SELECT array_agg(cbits ORDER BY cbits)
 FROM (
   WITH l0_mj AS (SELECT natcod.array_median_length(p_l0_list) AS majority_len)

   SELECT DISTINCT c FROM unnest(p_l0_list) l0(c), l0_mj
   WHERE (p_level=0.0 OR NOT(p_non_recursive))
         AND  not(p_non_repeat is null and length(c) > majority_len)

  UNION ALL
   SELECT *
   FROM (
     SELECT DISTINCT CASE
       WHEN p_majority AND majority_len < length(l0.cbits) THEN CASE
         WHEN (length(t.cbits) + majority_len) <= length(l0.cbits) THEN -- gambiarra do null, simplificar:
            CASE WHEN p_non_repeat=true THEN NULL
            WHEN p_non_repeat IS NULL AND (length(t.cbits) + majority_len = length(l0.cbits)) THEN l0.cbits
            WHEN p_non_repeat IS NOT NULL AND p_non_repeat=false THEN l0.cbits END
         ELSE l0.cbits || substring( t.cbits, length(l0.cbits)-majority_len +1 )
         END
       ELSE l0.cbits||t.cbits
     END c
     FROM natcod.generate_vbit_series( (p_level*2.0)::int, p_non_recursive ) t(cbits),
          unnest(p_l0_list) l0(cbits), l0_mj
     WHERE p_level>0.0
   )t3 WHERE c IS NOT NULL
 ) t2 (cbits)
$f$;
COMMENT ON FUNCTION natcod.parents_to_children(real,varbit[],boolean,boolean,boolean)
  IS 'Generate series of cbits of a country defined by p_l0_list_b16. When p_non_recursive is false generates recursivally. When p_majority is false ignores abnormal list.'
;

-- DROP FUNCTION IF EXISTS natcod.parents_to_children_baseh(real,text[],int,boolean,boolean) CASCADE;
CREATE or replace FUNCTION natcod.parents_to_children_baseh(
  p_level     real,      -- last lavel to return
  p_l0_list   text[],  -- Natcod parents (lower case codes). In AFAcodes the L0 list of scientific codes. Distinct ones.
  p_baseh     int default 16,  -- 4,8 or 16 (default)
  p_non_recursive boolean default true,  -- when false returns a recursive list.
  p_majority      boolean default true,  -- when false ignores abnormal p_l0_list, with non-uniform lenght.
  p_non_repeat    boolean default true -- mode false=repeat, true=non-repet on level 0, NULL=non-repeat level x
) RETURNS text[] language SQL IMMUTABLE
AS $wrap$
 SELECT natcod.vbit_to_baseh(
           natcod.parents_to_children(p_level, natcod.baseh_to_vbit(p_l0_list,p_baseh), p_non_recursive, p_majority,p_non_repeat),
           p_baseh,
           true   -- ordered
       )
$wrap$;
COMMENT ON FUNCTION natcod.parents_to_children_baseh(real,text[],int,boolean,boolean,boolean)
  IS 'Generate series of parent-list defined by p_l0_list, a base16 list of codes. When p_non_recursive is false generates recursivally. When p_majority is false ignores abnormal list. Wrap for parents_to_children().'
;

CREATE or replace FUNCTION natcod.parents_to_children(
  p_intlevel int, varbit[], boolean default true, boolean default true 
) RETURNS text[] language SQL IMMUTABLE
AS $wrap$
 SELECT natcod.parents_to_children( p_intlevel/10.0, $2, $3, $4 )
$wrap$;

CREATE or replace FUNCTION natcod.parents_to_children_baseh(
  p_intlevel int, text[], int, boolean default true, boolean default true, boolean default true 
) RETURNS text[] language SQL IMMUTABLE
AS $wrap$
 SELECT natcod.parents_to_children_baseh( p_intlevel/10.0, $2, $3, $4, $5, $6 )
$wrap$;

