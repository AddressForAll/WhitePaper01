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
