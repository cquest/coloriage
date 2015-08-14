echo "`date +%H:%M:%S` recherche voisinnages $1"
psql $DB -c "
truncate voisins;
insert into voisins (select p1.$ID, p2.$ID from $TABLE p1 join $TABLE p2 on (st_touches(p1.$GEOM, p2.$GEOM) and st_geometrytype(st_intersection(p1.$GEOM, p2.$GEOM))!='ST_Point') where p1.couleur='0' and p1.$ID like '$1%');" 1>/dev/null;
NB=`psql $DB -tc "select count(*) from $TABLE where $ID like '$1%' and couleur='0';"`;
echo "`date +%H:%M:%S` $NB communes $1"
for i in `seq 1 $NB`;do
	psql $DB -c "with u as (select t1.$ID as u_id, substring(regexp_replace('123456789','['||string_agg(distinct(t3.couleur),'')||']*',''),1,1) as u_couleur from $TABLE t1 join voisins v on (v.a=t1.$ID) join $TABLE t3 on (t3.$ID=v.b and t3.couleur>'0') where t1.couleur='0' group by 1 order by count(t3.*) desc, min(t3.quand) limit 1) update $TABLE set (couleur,quand)=(u_couleur,now()) from u where $ID=u_id;" 1>/dev/null
done

