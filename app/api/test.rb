obj=Article.includes(:categories)
select * from Article INNER JOIN CATEGORIES ON where article.category.id=category.category.id and name=="science"
Article
has_many :Category,
Test
belongs_to article
belongs_to category
Category
has_many : Article, :through => test

comment_id comment
uuid artcle_id  article
