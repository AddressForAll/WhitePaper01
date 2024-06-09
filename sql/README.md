
## To install in PostgreSQL v9+

```bash
# # # # # # # #
# To install Article "Natural Codes as foundation in hierarchical labeling"
psql test < prepare0-binCodes.sql # free license, Apache
psql test < prepare1-binCodes.sql # license CC-BY-NC-SA
# some asserts and use examples:
psql test < prepare1a-asserts.sql
psql test < prepare1b-demo.sql | diff - ../data/prepare1b-demo.txt

# # # # # # # #
# To add Article "Extended hexadecimal for variable-length bit strings on hierarchical labeling"
psql test < prepare2-baseConv.sql
# some asserts and use examples:
psql test < prepare2a-asserts.sql
psql test < prepare2b-demo.sql | diff - ../data/prepare2b-demo.txt


# # # # # # # #
# alternative: sudo -u postgres psql test
```

Run in the order prepare0, prepare1, prepare1a, prepare1b, prepare2, etc.

For full documentation see https://wiki.addressForAll.org/...

## prepare0-binCodes

Lib basic with Apache lincese. Define all Natcod functions.

## prepare1-binCodes

Lib basic with CC-BY-NC-SA license. Define all Natcod functions.

## ...
