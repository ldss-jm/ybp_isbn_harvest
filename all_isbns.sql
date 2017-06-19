--select 'b' || rm.record_num || 'a' as bnum, sfi.tag, sfi.content
--select sfi.record_id, sfi.tag, sfi.content
--from sierra_view.subfield sfi
--inner join sierra_view.record_metadata rm on rm.id = sfi.record_id
--where sfi.marc_tag = '020'
--  and sfi.tag in ('z', 'a')
WITH excluded AS (
       select bil.bib_record_id as bib_id
       from sierra_view.item_record i
       inner join sierra_view.bib_record_item_record_link bil on bil.item_record_id = i.id
       where i.location_code = 'uadai'
    )
select sf.record_id, sf.tag, sf.content
from sierra_view.bib_record b
inner join sierra_view.record_metadata rm on rm.id = b.id
inner join sierra_view.subfield sf on sf.record_id = b.id
  and sf.marc_tag = '020' and sf.tag in ('a', 'z')
where b.bcode3 != 'n'
      and (
            rm.creation_date_gmt < (localtimestamp - interval '30 days')
              or
            (rm.creation_date_gmt < (localtimestamp - interval '7 days')
              and (
                  exists (select * from sierra_view.bib_record_item_record_link bil where bil.bib_record_id = b.id)
                  or
                  exists (select * from sierra_view.bib_record_item_record_link bil where bil.bib_record_id = b.id)
                  )
             )
          )
      and NOT EXISTS (select *
                      from excluded
                      where excluded.bib_id = sf.record_id)