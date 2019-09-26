select v.record_id
from sierra_view.varfield v
INNER JOIN sierra_view.bib_record b ON v.record_id = b.record_id
  AND b.bcode3 NOT IN ('d', 'n', 'c')
where v.varfield_type_code = 'w'
  AND v.marc_tag = '773'
  AND v.field_content ~ '\(online collection\)|Undergraduate library Kindle ebook collection'
  --changes to statement below need to also be reflected on ybp_ecolls_isbns
  AND NOT (v.field_content ilike '%title-by-title%'
        or v.field_content ilike '%via YBP%'
        or v.field_content like '%|tSpringer%'
        or v.field_content ilike '%|tProQuest Ebook Central (online collection). DDA%'
        or v.field_content like '%|tProQuest Ebook Central DDA (online collection).%'
        or v.field_content like '%|tEBL eBook Library DDA%'
        or v.field_content like '%|tCambridge histories online (online collection). 2014%'
        or v.field_content like '%|tCambridge histories online (online collection). 2015%'
        or v.field_content like '%|tDuke University Press ebooks (online collection). 2014%'
        or v.field_content like '%|tDuke University Press ebooks (online collection). 2015%')