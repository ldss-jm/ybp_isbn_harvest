SELECT sf.content as isbn, v.field_content as coll
FROM sierra_view.varfield v
INNER JOIN sierra_view.subfield sf on sf.record_id = v.record_id
    and sf.marc_tag = '020'
    and sf.tag = 'a'
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
