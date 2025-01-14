WITH excluded AS (
       -- isbns from these records are not included in the holdings data
       -- (but *can* still be included if present on other records)
       select bil.bib_record_id as bib_id
       from sierra_view.item_record i
       inner join sierra_view.bib_record_item_record_link bil on bil.item_record_id = i.id
       where i.location_code = 'uadai'

       UNION

       select b.id as bib_id
       from sierra_view.bib_record b
       inner join sierra_view.varfield v on v.record_id = b.id and v.marc_tag = '773'
       where (v.field_content like '%|tOverDrive digital library (online collection). Ebooks%'
          or v.field_content like '%|tOverDrive digital library (online collection). Audio books%'
          or v.field_content like '%|tProQuest Ebook Central (online collection). NCLIVE subscription ebooks%')
    )
select b.id, v.field_content
from sierra_view.bib_record b
inner join sierra_view.record_metadata rm on rm.id = b.id
inner join sierra_view.varfield v on v.record_id = b.id and v.marc_tag = '020'
where b.bcode3 != 'n'
      and (
            rm.creation_date_gmt < (localtimestamp - interval '30 days')
              or
            (rm.creation_date_gmt < (localtimestamp - interval '7 days')
              and (
                  exists (select * from sierra_view.bib_record_item_record_link bil where bil.bib_record_id = b.id)
                  or
                  exists (select * from sierra_view.bib_record_holding_record_link bhl where bhl.bib_record_id = b.id)
                  )
             )
          )
      and NOT EXISTS (select *
                      from excluded
                      where excluded.bib_id = v.record_id)
-- sorted input is needed by script to discard |z isbns appropriately
order by b.id
