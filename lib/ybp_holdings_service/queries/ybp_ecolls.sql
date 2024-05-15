SELECT phe.index_entry as isbn, v.field_content as coll
FROM sierra_view.varfield v
INNER JOIN sierra_view.phrase_entry phe on phe.record_id = v.record_id
  and phe.index_tag = 'i' and phe.phrase_rule_operation = 'K'
WHERE v.marc_tag = '773'
    --changes to statement below need to also be reflected on ebook_bnums.sql
    and (v.field_content ilike '%title-by-title%'
        or v.field_content ilike '%via YBP%'
        or v.field_content like '%|tSpringer%'
        or v.field_content ilike '%|tProQuest Ebook Central (online collection). DDA%'
        or v.field_content like '%|tProQuest Ebook Central DDA (online collection).%'
        or v.field_content like '%|tEBL eBook Library DDA%'
        or v.field_content like '%|tCambridge histories online (online collection). 2014%'
        or v.field_content like '%|tCambridge histories online (online collection). 2015%'
        or v.field_content like '%|tDuke University Press ebooks (online collection). 2014%'
        or v.field_content like '%|tDuke University Press ebooks (online collection). 2015%')
