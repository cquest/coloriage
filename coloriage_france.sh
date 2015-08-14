wget http://osm13.openstreetmap.fr/~cquest/openfla/export/communes-20150101-100m-shp.zip
unzip communes-20150101-100m-shp.zip
ogr2ogr -f PostgreSQL PG:dbname=osm communes*.shp -overwrite -nlt GEOMETRY -nln test -lco COLUMN_TYPES="surf_m2=float"

# nom de la base postgres à utiliser
export DB=osm
# nom de la table contenant les géométries à colorier
export TABLE=test
# champ géométrique
export GEOM=wkb_geometry
# champ d'ID unique
export ID=insee

# ajout du champ couleur et quand puis création des index liés
psql $DB -c "
ALTER TABLE $TABLE add couleur text;
ALTER TABLE $TABLE add quand time;
CREATE INDEX $TABLE_nocolor on $TABLE ($ID) where couleur='0';
CREATE INDEX $TABLE_hascolor on $TABLE ($ID) where couleur>'0';
CREATE INDEX $TABLE_idcolor on $TABLE ($ID);
"

# communes avec attribution de couleur pour démarrer les tâches d'huile (métropole, corse, DOM et iles)
psql $DB -c "
update $TABLE set (couleur,quand)=('0',now()) where $GEOM is not null and couleur>'0' or couleur is null;
update $TABLE set (couleur,quand)=('1',now()) where $ID in ('2A041','97120','97209','97302','97411','97502','97611','67261','56241','85163','17207','17385','97112','97608');
"

# coloriage des départements un à un (progression en tâche d'huile à partir du 67)
for dep in 67 57 54 88 68 55 90 70 25 52 51 08 02 10 21 39 71 89 58 77 60 80 59 62 76 95 93 94 91 75 92 78 27 28 45 18 03 42 69 01 74 73 38 05 04 06 83 13 26 84 07 30 48 43 63 23 36 41 72 61 14 50 53 49 37 86 87 19 15 12 46 24 16 79 85 44 56 22 35 29 17 33 47 82 81 34 11 66 09 31 32 40 64 65 2A 2B 971 972 973 974 975 976; do sh coloriage.sh $dep ;done

# coloriage des communes qui n'ont pas de voisine (iles)
psql $DB -c "
truncate voisins; insert into voisins (select p1.$ID, p2.$ID from $TABLE p1 join $TABLE p2 on (st_touches(p1.$GEOM, p2.$GEOM) and st_geometrytype(st_intersection(p1.$GEOM, p2.$GEOM))!='ST_Point') where p1.couleur='0');
with u as (select t1.$ID as u_id from $TABLE t1 left join voisins v on v.a=t1.$ID where t1.couleur='0' and v.a is null) update $TABLE set couleur='1' from u where $ID=u_id;
"

# bilan des couleurs attribuées
psql $DB -c "select couleur, count(*) from $TABLE group by 1 order by 1;"

# on remet les couleurs '6' à '0' pour tenter un recoloriage local sur 3 niveaux
psql $DB -c "
update $TABLE set couleur='0' where couleur='6';
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
"
sh coloriage.sh ""

# on remet les couleurs '6' à '0' pour tenter un recoloriage local sur 5 niveaux
psql $DB -c "
update $TABLE set couleur='0' where couleur='6';
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
with u as (select v.b as u_id from $TABLE p1 join voisins v on (v.a=p1.$ID) where p1.couleur='0') update $TABLE set couleur='0' from u where $ID=u_id;
"
sh coloriage.sh ""

# bilan des couleurs attribuées
psql $DB -c "select couleur, count(*) from $TABLE group by 1 order by 1;"

# on a besoin de tout les voisinages pour ré-attribuer les couleurs
psql $DB -c "
truncate voisins;
insert into voisins (select p1.$ID, p2.$ID from $TABLE p1 join $TABLE p2 on (st_touches(p1.$GEOM, p2.$GEOM) and st_geometrytype(st_intersection(p1.$GEOM, p2.$GEOM))!='ST_Point'));
"

// ré-équilibrage final pour avoir environ 36600/5 communes de chaque couleur
sh coloriage_reequilibre.sh 1 5 2800
sh coloriage_reequilibre.sh 2 5 2400
sh coloriage_reequilibre.sh 3 5 1200
sh coloriage_reequilibre.sh 3 4 350

