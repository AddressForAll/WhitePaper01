-- check completeness by `grep -i function prepare2-baseConv.sql | grep -v -i comment> check`

DO $tests$
begin
  RAISE NOTICE '1. Testing baseh-conversor function, vbit_to_baseh()...';

  ASSERT natcod.vbit_to_baseh(b'000000000000',4) = '000000',                       '1.1a. vbit_to_baseh(), varbit 0s to b4h';
  ASSERT natcod.vbit_to_baseh(b'0',4) = 'G',                                       '1.1b. vbit_to_baseh(), varbit 0 to b4h';
  ASSERT natcod.vbit_to_baseh(b'101010101100111100000001001',4) = '2222303300010Q','1.1c. vbit_to_baseh(), varbit x to b4h';

  ASSERT natcod.vbit_to_baseh(b'000000000000',8) = '0000',                     '1.2a. vbit_to_baseh(), varbit 0s to b8h';
  ASSERT natcod.vbit_to_baseh(b'0',8) = 'G',                                   '1.2b. vbit_to_baseh(), varbit 0 to b8h';
  ASSERT natcod.vbit_to_baseh(b'101010101100111100000001001',8) = '525474011', '1.2c. vbit_to_baseh(), varbit x to b8h';

  ASSERT natcod.vbit_to_baseh(b'101010101100111100000001',16) = 'aacf01',      '1.3. vbit_to_baseh(), varbit to b16h';
  ASSERT natcod.vbit_to_baseh(b'000000000000',16) = '000',                     '1.3a. vbit_to_baseh(), varbit 0s to b16h';
  ASSERT natcod.vbit_to_baseh(b'0',16) = 'G',                                  '1.3b. vbit_to_baseh(), varbit 0 to b16h';
  ASSERT natcod.vbit_to_baseh(b'101010101100111100000001001',16) = 'aacf01K',  '1.3c. vbit_to_baseh(), varbit to b16h';

  RAISE NOTICE '2. Testing classic base conversor function, vbit_to_strstd() ...';

  ASSERT natcod.vbit_to_strstd(b'10101010110011110000','4js') = '2222303300',  '2.1. vbit_to_strstd(), varbit to base 4js';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110000','16js') = 'aacf0',      '2.2. vbit_to_strstd(), varbit to base 16js';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110001','32js') = 'lb7h',       '2.3. vbit_to_strstd(), varbit to base 32js';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110001','32hex') = 'lb7h',      '2.3b. vbit_to_strstd(), varbit to base 32hex';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110001','32ghs') = 'pc7j',      '2.4a. vbit_to_strstd(), varbit to base 32ghs';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110001','32nvu') = 'PC7K',      '2.4b. vbit_to_strstd(), varbit to base 32nvu';
  ASSERT natcod.vbit_to_strstd(b'10101010110011110001','32rfc') = 'VLHR',      '2.4c. vbit_to_strstd(), varbit to base 32rfc';

  RAISE NOTICE '3. Testing wrap function, vbit_to_str() ...';

  ASSERT natcod.vbit_to_str(b'10101010110011110000','4js') = '2222303300',     '3.1. vbit_to_str(), varbit to base 4js';
  ASSERT natcod.vbit_to_str(b'10101010110011110000','16js') = 'aacf0',         '3.2. vbit_to_str(), varbit to base 16js';
  ASSERT natcod.vbit_to_str(b'10101010110011110001','32js') = 'lb7h',          '3.3a. vbit_to_str(), varbit to base 32js';
  ASSERT natcod.vbit_to_str(b'10101010110011110001','32hex') = 'lb7h',         '3.3b. vbit_to_str(), varbit to base 32hex';
  ASSERT natcod.vbit_to_str(b'10101010110011110001','32ghs') = 'pc7j',         '3.3c. vbit_to_str(), varbit to base 32ghs';
  ASSERT natcod.vbit_to_str(b'10101010110011110001','32nvu') = 'PC7K',         '3.3d. vbit_to_str(), varbit to base 32nvu';
  ASSERT natcod.vbit_to_str(b'10101010110011110001','32rfc') = 'VLHR',         '3.3f. vbit_to_str(), varbit to base 32rfc';
  --ASSERT natcod.vbit_to_str(b'10101010110011110001','64rfc') = '?',         '3.4a. vbit_to_str(), varbit to base 64rfc';

  ASSERT natcod.vbit_to_str(b'000000000000','4h') = '000000',                   '3.5. vbit_to_baseh(), varbit 0s to b4h';
  ASSERT natcod.vbit_to_str(b'000000000000','8h') = '0000',                     '3.6. vbit_to_baseh(), varbit 0s to b8h';
  ASSERT natcod.vbit_to_str(b'101010101100111100000001','16h') = 'aacf01',      '3.7. vbit_to_baseh(), varbit to b16h';

  RAISE NOTICE '4. Testing baseh_to_vbit(), array wraps and parents_to_children_baseh() ...';

  ASSERT natcod.baseh_to_vbit('f3K',16) = '11110011001',                        '4.1a. baseh_to_vbit(), base16h';
  ASSERT natcod.baseh_to_vbit('f3',16)  = '11110011',                           '4.1b. baseh_to_vbit(), hex';
  ASSERT natcod.baseh_to_vbit('32',8) = '011010',                               '4.1c. baseh_to_vbit(), base8h';
  ASSERT natcod.baseh_to_vbit('32',4)  = '1110',                                '4.1d. baseh_to_vbit(), base4h';

  ASSERT natcod.baseh_to_vbit('{f,ff,at,0n,00}'::text[], 16)
          = '{1111,11111111,1010101,0000010,00000000}',                         '4.2a. baseh_to_vbit(array), unordered';
  ASSERT natcod.baseh_to_vbit('{f,ff,at,0n,00}'::text[], 16, true)
          = '{00000000,0000010,1010101,1111,11111111}',                         '4.2b. baseh_to_vbit(array), ordered';

  ASSERT natcod.parents_to_children_baseh(0.5, '{f,0,aq}', 16,true)
          = '{0G,0Q,aQ,fG,fQ}',                                                 '4.3a. parents_to_children_baseh(0.5)';
  ASSERT natcod.parents_to_children_baseh(1.5, '{f,0,aq}', 16,true)
          = '{0J,0K,0N,0P,0S,0T,0Z,0Y,aS,aT,aZ,aY,fJ,fK,fN,fP,fS,fT,fZ,fY}',    '4.3b. parents_to_children_baseh(1.5)';

  ASSERT natcod.parents_to_children_baseh(0.5, '{f,0,aq}', 16,true,false)
          = '{0G,0Q,aR,aV,fG,fQ}',                                              '4.3c. parents_to_children_baseh(0.5) without majority';
  ASSERT natcod.parents_to_children_baseh(1.0, '{f,0,aq}', 16,false,false)
          = '{0,0G,0H,0M,0Q,0R,0V,aQ,aR,aS,aT,aV,aZ,aY,f,fG,fH,fM,fQ,fR,fV}',   '4.3d. parents_to_children_baseh(1.0) recursive';

end;
$tests$ LANGUAGE plpgsql;
