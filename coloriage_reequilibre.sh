from_color=$1
to_color=$2
nb_change=$3

psql $DB -c "
with u as (
        select p1.$ID as u_id from $TABLE p1
        join voisins v on (v.a=p1.$ID)
        join $TABLE p2 on (p2.$ID=v.b) where p1.couleur='$from_color'
        group by 1
        having string_agg(distinct(p2.couleur),'') not like '%$to_color%'
        order by random() limit $nb_change) update $TABLE set couleur='$to_color' from u where $ID=u_id and couleur='$from_color';
"
