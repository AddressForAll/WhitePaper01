-- check completeness by `grep -i function prepare1-binCodes.sql | grep -v -i comment > check`

DO $tests$
begin
  RAISE NOTICE '1. Testing conversions of PubLib, some with encode/decode consistency checking ...';

  ASSERT hex_to_varbit('aACf01') = b'101010101100111100000001',        '1.1. hex_to_varbit(), fast and case insentitive';
  ASSERT hex_to_varbit('00') = b'00000000',                            '1.2. hex_to_varbit(), zeros';
  ASSERT varbit_to_int(b'1111') = 15,                                  '1.3. varbit_to_int()';
  ASSERT varbit_to_int(b'') = 0,                                       '1.3a. varbit_to_int(), empty value';
  ASSERT varbit_to_int(b'000') = 0,                                    '1.3b. varbit_to_int(), zeros';
  ASSERT varbit_to_int(b'10001')::bit(5)::varbit = b'10001',           '1.4. varbit_to_int() encode/decode';
  ASSERT varbit_to_bigint(b'1111') = 15,                               '1.5. varbit_to_bigint()';
  ASSERT varbit_to_bigint(34359738369::bit(64)::varbit) = 34359738369, '1.6. varbit_to_bigint() encode/decode';
  ASSERT varbit_to_bigint(4611686018427387904::bit(64)::varbit) = 4611686018427387904, '1.6b. varbit_to_bigint() encode/decode, big value';

  RAISE NOTICE '2. Testing conversions of vbit_to and its inverse ...';
  ASSERT natcod.vBit_to_hiddenBig(b'')=1,                                   '2.7a. vBit_to_hiddenBig(), empty';
  ASSERT natcod.vBit_to_hiddenBig(b'0')=2,                                  '2.7b. vBit_to_hiddenBig(), zero';
  ASSERT natcod.vBit_to_hiddenBig(b'1111')=31,                              '2.7c. vBit_to_hiddenBig(), ones';

  ASSERT natcod.vbit_to_hbig(b'')=0,                                        '2.7d. vbit_to_hbig(), empty';
  ASSERT natcod.vbit_to_hbig(b'0')=1,                                       '2.7e. vbit_to_hbig(), zero';
  ASSERT natcod.vbit_to_hbig(b'0',5)=natcod.vbit_to_hbig(b'00000'),         '2.7e2. vbit_to_hbig(), zero to length5';

  ASSERT natcod.vbit_to_hbig(b'00')=2,                                      '2.7f. vbit_to_hbig(), zeros';
  ASSERT natcod.vbit_to_hbig(b'1')=4611686018427387905,                     '2.7g. vbit_to_hbig(), one';
  ASSERT natcod.vbit_to_hbig(b'1111')=8646911284551352324,                  '2.7h. vbit_to_hbig(), ones';

  ASSERT natcod.hbig_to_vbit(natcod.vbit_to_hbig(b'1111'))=b'1111',    '2.8. vbit_to_hbig(vbit) encode/decode';
  ASSERT natcod.hbig_to_vbit(natcod.vbit_to_hbig('1111'))=b'1111',    '2.8. vbit_to_hbig(string) encode/decode';

  RAISE NOTICE '3. Testing bit-helper-functions ...';
  ASSERT natcod.strbit_to_vbit('001010101')=b'001010101',              '3.1a. strbit_to_vbit(str), test';
  ASSERT natcod.strbit_to_vbit('001010101',3)=b'001',                  '3.1b. strbit_to_vbit(str,len), test';

  ASSERT natcod.bitlength(5)=3,                                         '3.2a. bitlength(int)';
  ASSERT natcod.bitlength(5::bigint)=3,                                 '3.2b. bitlength(bigint)';
  ASSERT natcod.bitlength(4611686018427387905)=63,                      '3.2c. bitlength(big1)';
  ASSERT natcod.bitlength(8646911284551352324)=63,                      '3.2d. bitlength(big2)';
end;
$tests$ LANGUAGE plpgsql;

/* LIXO
SELECT  natcod.prefix_to_max(p varbit, len int default 57) RETURNS varbit as $f$
-- Old functions
SELECT  natcod.hiddenBig_to_vBit(x bigint, p int) RETURNS varbit AS $f$  -- hb_decode
SELECT  natcod.hiddenBig_to_vBit(x bigint) RETURNS varbit AS $f$  -- hb_decode

SELECT  natcod.hBig_to_hiddenBig(x bigint) RETURNS bigint AS $f$
SELECT  natcod.vBit_to_hBig( b varbit, blen int DEFAULT NULL) RETURNS bigint AS $f$
SELECT  natcod.vBit_to_hInt( b varbit, blen int DEFAULT NULL) RETURNS int AS $f$
SELECT  natcod.vBit_to_hSml( b varbit, blen int DEFAULT NULL) RETURNS smallint AS $f$
SELECT  natcod.hdist( a bigint, b bigint DEFAULT 0) RETURNS bigint AS $f$
SELECT  natcod.hdist( a int, b int DEFAULT 0) RETURNS int AS $f$
SELECT  natcod.hdist_log(
SELECT  natcod.hBig_to_length( x bigint) RETURNS int AS $f$
SELECT  natcod.hBig_to_vBit( x bigint) RETURNS varbit AS $f$
SELECT  natcod.hInt_to_vBit( x int) RETURNS varbit AS $f$
SELECT  natcod.hSml_to_vBit( x smallint) RETURNS varbit AS $f$
SELECT  natcod.vbit_to_hbig(p text) RETURNS bigint AS $wrap$
SELECT  natcod.vbit_to_hbig(
SELECT  natcod.hiddenBig_to_hBig(x bigint) RETURNS bigint AS $f$
SELECT  natcod.generatep_hb_series(bit_len int) RETURNS setof bigint as $f$
SELECT  natcod.generate_hb_series(bit_len int) RETURNS setof bigint as $f$
SELECT  natcod.generate_vbit_series(bit_len int) RETURNS setof varbit as $f$
SELECT  natcod.generate_vbit_series_didactic(bit_len int)
*/
