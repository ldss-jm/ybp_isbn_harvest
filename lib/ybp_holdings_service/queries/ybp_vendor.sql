select phe.index_entry--, o.vendor_record_code
from sierra_view.order_record o
inner join sierra_view.bib_record_order_record_link bl
  on bl.order_record_id = o.id
inner join sierra_view.phrase_entry phe on phe.record_id = bl.bib_record_id
  and phe.index_tag = 'i' and phe.phrase_rule_operation = 'K'
where
    o.vendor_record_code ~ '^ya[0-9][0-9]'
or  o.vendor_record_code like '9y%'
or  o.vendor_record_code like '9l%'
or  o.vendor_record_code like 'lh%'
or  o.vendor_record_code ~ '^ybp.o'
or  o.vendor_record_code ~ '^yank[mo]'
or  o.vendor_record_code = 'lindm'
--avoid including ya5om, yaleo, yaleu, yanka, yankf, yax3m, ybp, ybpdd, ybpe
--@y.* has no order records
--excl ybpul     -- ul
--excl ys1[2-7]m --stone
