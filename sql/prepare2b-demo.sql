-- Gerar exemplos de saida e demo

-- SET lc_messages TO 'en_us.UTF-8'; -- to be a standard output.
-- When no effect, use `SHOW config_file` them edit postgresql.conf

SELECT row_number() over() -1 AS count, bitstring,  -- remover o -1 no prox git commit
       natcod.vbit_to_baseh(bitstring,4) as b4h,
       natcod.vbit_to_baseh(bitstring,8) as b8h,
       natcod.vbit_to_baseh(bitstring,16) as b16h
FROM (select * from natcod.generate_vbit_series(8) UNION select ''::varbit ) t2 (bitstring)
ORDER BY bitstring -- lexicographical order
;

SELECT row_number() over() AS count, *
FROM (
  SELECT bitstring,
         natcod.vBit_to_baseh(bitstring,4) as b4h,
         natcod.vbit_to_baseh(bitstring,8) as b8h,
         natcod.vBit_to_baseh(bitstring,16) as b16h
  FROM natcod.generate_vbit_series(12) t(bitstring)
  ORDER BY natcod.vBit_to_hiddenBig(bitstring) -- level order
) t2
LIMIT 35
;

--- add base conversion tests and more series.
SELECT 'ERROR!' err_msg, *
FROM (
  SELECT row_number() over() AS count, *,
       natcod.vbit_to_hbig(bitstring) as hbig,
       natcod.vbit_to_kbig(bitstring) as kbig,
       natcod.vbit_to_baseh(bitstring,4) as b4h,
       natcod.vbit_to_baseh(bitstring,16) as b16h
  FROM natcod.generate_vbit_series(18) t(bitstring)  -- use 12 to faster
) t
WHERE natcod.hbig_to_vbit(hbig)!=bitstring
      OR natcod.kbig_to_vbit(kbig)!=bitstring
      OR natcod.baseh_to_vbit(b4h,4)!=bitstring
      OR natcod.baseh_to_vbit(b16h,16)!=bitstring
;
