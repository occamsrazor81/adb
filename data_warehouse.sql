/* Činjenica koju skladište opisuje jest narudžba. Činjenična je tablica cNarudzba.
Jedan redak činjenične tablice predstavlja zapis o narudžbi pojedinog proizvoda od strane pojedinog kupca
na određeni dan (datum).
Osnovne su dimenzije stoga dProizvod, dKupac, dDatum, a dodajemo i dimenziju dDostavljač (činjeničnu
tablic obogaćujemo atributom sifDostavljac).
Mjere kojima mjerimo proces su jedinična cijena, količina prodanih proizvoda, popust te prihod.
Slika zvjezdastog modela skladišta može se vidjeti u fileu zvjezdasti_model.pdf
*/

--Kreiramo tablicu dDatum s atributima prikazanim na slici zvjezdastog modela:
/* Atribut pocTjedna je tipa BOOLEAN te je za određeni redak u tablici jednak TRUE ako redak predstavlja
zapis o datumu čiji je odgovarajući dan u tjednu ponedjeljak. Jednak je FALSE inače.
Analogno je vrijednost atributa krajTjedna jednaka TRUE ako odgovarajući redak u tablici predstavlja
zapis o datumu čiji odgovarajući dan u tjednu odgovara kraju radnog tjedna, odnosno čiji je
odgovarajući dan petak.
Također, vrijednost atributa pocMjeseca jednaka je TRUE ako odgovarajući redak u tablici predstavlja
zapis o datumu koji odgovara prvom danu u nekome mjesecu.
Analogno je vrijednost atributa krajMjeseca jednaka TRUE ako odgovarajući redak u tablici predstavlja
zapis o datumu koji odgovara zadnjem danu u nekome mjesecu.
*/
CREATE TABLE dDatum(
    sifDatum SERIAL PRIMARY KEY NOT NULL,
    datum DATE,
    dan SMALLINT,
    mjesec SMALLINT,
    godina SMALLINT,
    danUTjednu SMALLINT,
    nazDanUTjednu VARCHAR(10),
    pocTjedna BOOLEAN,
    krajTjedna BOOLEAN,
    pocMjeseca BOOLEAN,
    krajMjeseca BOOLEAN);

--Kreiramo tablicu dProizvod s atributima prikazanim na slici zvjezdastog modela:
CREATE TABLE dProizvod(
    sifProizvod SERIAL PRIMARY KEY,
    sifProizvodDB SMALLINT NOT NULL,
    nazivProizvod VARCHAR(40),
    sifDobavljac SMALLINT,
    nazivTvrtka VARCHAR(40),
    imeKontakt VARCHAR(30),
    titulaKontakt VARCHAR(30),
    grad VARCHAR(15),
    regija VARCHAR(15),
    pbr VARCHAR(10),
    drzava VARCHAR(15),
    telefon VARCHAR(24),
    fax VARCHAR(24),
    webStranica text,
    sifKategorija SMALLINT,
    nazivKategorija VARCHAR(15),
    opis text,
    slika bytea,
    jedKvantiteta VARCHAR(20),
    jedCijena REAL
    );

--Kreiramo tablicu dKupac s atributima prikazanim na slici zvjezdastog modela:
CREATE TABLE dKupac(
    sifKupac SERIAL PRIMARY KEY,
    sifKupacDB bpchar NOT NULL,
    nazivTvrtka VARCHAR(40),
    imeKontakt VARCHAR(30),
    titulaKontakt VARCHAR(30),
    grad VARCHAR(15),
    regija VARCHAR(15),
    pbr VARCHAR(10),
    drzava VARCHAR(15),
    telefon VARCHAR(24),
    fax VARCHAR(24));

--Kreiramo tablicu dDostavljac s atributima prikazanim na slici zvjezdastog modela:
CREATE TABLE dDostavljac(
    sifDostavljac SERIAL PRIMARY KEY,
    sifDostavljacDB SMALLINT NOT NULL,
    nazivTvrtka VARCHAR(40),
    telefon VARCHAR(24));

--Prvo punimo vremensku dimenziju (tablicu dDatum):
INSERT INTO dDatum (datum)
SELECT generate_series(min(order_date), max(order_date), interval '1 day')
FROM orders;
UPDATE dDatum SET dan=EXTRACT(DAY FROM datum),
                  mjesec=EXTRACT(MONTH FROM datum),
                  godina=EXTRACT(YEAR FROM datum),
                  danUTjednu=EXTRACT(DOW FROM datum),
                  nazDanUTjednu=to_char(datum, 'day');
UPDATE dDatum SET pocTjedna=CASE WHEN danUTjednu=1 THEN TRUE ELSE FALSE END,
                  krajTjedna=CASE WHEN danUTjednu=5 THEN TRUE ELSE FALSE END,
                  pocMjeseca=CASE WHEN dan=1 THEN TRUE ELSE FALSE END,
                  krajMjeseca=CASE WHEN dan=EXTRACT(DAY FROM (date_trunc('month', datum) + interval '1 month' - interval '1 day')::date) THEN TRUE ELSE FALSE END;

--Nadalje, punimo ostale dimenzije (tablice dProizvod, dKupac te dDostavljac, respektivno):
INSERT INTO dProizvod (sifProizvodDB, nazivProizvod, sifDobavljac, nazivTvrtka, imeKontakt, titulaKontakt,
                       grad, regija, pbr, drzava, telefon, fax, webStranica, sifKategorija, nazivKategorija,
                       opis, slika, jedKvantiteta, jedCijena)
SELECT product_id, product_name, products.supplier_id, company_name, contact_name, contact_title,
       city, region, postal_code, country, phone, fax, homepage, products.category_id, category_name,
       description, picture, quantity_per_unit, unit_price
FROM products
    FULL OUTER JOIN suppliers ON products.supplier_id=suppliers.supplier_id
    FULL OUTER JOIN categories ON products.category_id=categories.category_id;

INSERT INTO dKupac (sifKupacDB, nazivTvrtka, imeKontakt, titulaKontakt, grad, regija, pbr, drzava, telefon, fax)
SELECT customer_id, company_name, contact_name, contact_title, city, region, postal_code,
       country, phone, fax
FROM customers;

INSERT INTO dDostavljac (sifDostavljacDB, nazivTvrtka, telefon)
SELECT shipper_id, company_name, phone
FROM shippers;

--Kreiramo činjeničnu tablicu cNarudzba s atributima prikazanim na slici zvjezdastog modela:
CREATE TABLE cNarudzba (
    sifProizvod INT NOT NULL REFERENCES dProizvod,
    sifKupac INT NOT NULL REFERENCES dKupac,
    sifDatum INT NOT NULL REFERENCES dDatum,
    sifDostavljac INT NOT NULL REFERENCES dDostavljac,
    jedCijena REAL,
    kolicina SMALLINT,
    popust REAL,
    prihod REAL);

--Nadalje, punimo činjeničnu tablicu cNarudzba:
INSERT INTO cNarudzba
SELECT dProizvod.sifProizvod, dKupac.sifKupac, dDatum.sifDatum, dDostavljac.sifDostavljac,
       order_details.unit_price, order_details.quantity, order_details.discount,
       order_details.unit_price * order_details.quantity
FROM order_details
    JOIN orders ON order_details.order_id=orders.order_id
    JOIN dProizvod ON order_details.product_id=dProizvod.sifProizvodDB
    JOIN dKupac ON orders.customer_id=dKupac.sifKupacDB
    JOIN dDatum ON orders.order_date=dDatum.datum
    JOIN dDostavljac ON orders.ship_via=dDostavljac.sifDostavljacDB;

--U nastavku izvršavamo nekoliko upita nad tablicama skladišta podataka.
--Sljedećim upitom dobivamo usporedbu ukupnih prihoda po kategorijama proizvoda u 1997. godini:
SELECT opis AS kategorija, SUM(prihod) AS ukupniPrihod
FROM cNarudzba, dProizvod, dDatum
WHERE cNarudzba.sifProizvod=dProizvod.sifProizvod
  AND cNarudzba.sifDatum=dDatum.sifDatum
  AND dDatum.godina=1997
GROUP BY 1;

/* Narednim upitom dobivamo top listu država iz kojih su dobavljani proizvodi u 1998. godini.
Točnije, upitom dobivamo listu čije su stavke retci s državom dobavljača te ukupnom količinom proizvoda
koji su naručeni u 1998. godini, a dobavljeni su iz odgovarajuće države kao atributima.
Ta je lista silazno sortirana po upravo spomenutoj količini proizvoda:
*/
SELECT dProizvod.drzava, SUM(kolicina) AS kolicinaProizvoda
FROM cNarudzba, dProizvod, dDatum
WHERE cNarudzba.sifProizvod=dProizvod.sifProizvod
  AND cNarudzba.sifDatum=dDatum.sifDatum
  AND dDatum.godina=1998
GROUP BY 1 ORDER BY kolicinaProizvoda DESC;

/* Upitom koji slijedi dobivamo top listu država po prihodu koji naručitelji iz njih generiraju početkom tjedna.
Odnosno, radi se o listi čije su stavke retci s državom naručitelja te ukupnim prihodom generiranim na datume
koji odgovaraju početku nekog tjedna, tj. čiji je odgovarajući dan u tjednu ponedjeljak kao atributima.
Po upravo spomenutom ukupnom prihodu lista je silazno sortirana.
Iz tako dobivene liste lako se vidi iz kojih država naručitelji generiraju najveći prihod početkom tjedna;
dovoljno je pogledati njen početak.
*/
SELECT dKupac.drzava, SUM(prihod) AS ukupniPrihod
FROM cNarudzba, dKupac, dDatum
WHERE cNarudzba.sifKupac=dKupac.sifKupac
  AND cNarudzba.sifDatum=dDatum.sifDatum
  AND dDatum.pocTjedna=TRUE
GROUP BY 1 ORDER BY ukupniPrihod DESC;

/* Malom modifikacijom prethodnog upita možemo dobiti i, primjerice, 5 država iz kojih naručitelji generiraju
najveći prihod početkom tjedna. Također, možemo dobiti i onu državu iz koje je takav prihod najveći.
Takve rezultate (respektivno) dobivamo sljedećim dvama upitima:
*/
SELECT dKupac.drzava, SUM(prihod) AS ukupniPrihod
FROM cNarudzba, dKupac, dDatum
WHERE cNarudzba.sifKupac=dKupac.sifKupac
  AND cNarudzba.sifDatum=dDatum.sifDatum
  AND dDatum.pocTjedna=TRUE
GROUP BY 1 ORDER BY ukupniPrihod DESC LIMIT 5;

SELECT dKupac.drzava, SUM(prihod) AS ukupniPrihod
FROM cNarudzba, dKupac, dDatum
WHERE cNarudzba.sifKupac=dKupac.sifKupac
  AND cNarudzba.sifDatum=dDatum.sifDatum
  AND dDatum.pocTjedna=TRUE
GROUP BY 1 ORDER BY ukupniPrihod DESC LIMIT 1;

/* Sljedećim upitom dobivamo top listu dana u tjednu po prosječnim popustima.
Iz te liste možemo vidjeti kojim su danima popusti najveći pogledom na njen početak.
*/
SELECT dDatum.nazDanUTjednu as dan, AVG(popust) AS prosjecniPopust
FROM cNarudzba, dDatum
WHERE cNarudzba.sifDatum=dDatum.sifDatum
GROUP BY 1 ORDER BY prosjecniPopust DESC;

/* Analogno kao i s upitima prije neposredno napisanog, malom modifikacijom prethodnog upita možemo dobiti i,
primjerice, samo jedan dan na koji je prosječan popust najveći:
*/
SELECT dDatum.nazDanUTjednu as dan, AVG(popust) AS prosjecniPopust
FROM cNarudzba, dDatum
WHERE cNarudzba.sifDatum=dDatum.sifDatum
GROUP BY 1 ORDER BY prosjecniPopust DESC LIMIT 1;

/* Sljedećim upitom dobivamo odgovor na pitanje je li prihod krajem mjeseca veći nego početkom mjeseca;
izvršavanjem upita dobivamo jedan redak s dva atributa: jedan atribut odgovara iznosu prosječnog prihoda
početkom mjeseca, odnosno prosjeku prihoda koji su ostvareni na prvi dan nekog mjeseca u nekoj godini,
a drugi odgovara iznosu prosječnog prihoda krajem mjeseca, odnosno prosjeku prihoda koji su ostvareni na
zadnji dan nekog mjeseca u nekoj godini. Pritom ako na neki datum između najranijeg i najkasnijeg
datuma narudžbe nije napravljena niti jedna narudžba, uzimamo da je prihod za taj dan jednak 0.
Kako bismo saznali je li prihod krajem mjeseca veći nego početkom mjeseca, jednostavno je potrebno usporediti
upravo opisane dvije vrijednosti.
*/
SELECT DISTINCT (SELECT AVG(narPrihod)
    FROM (SELECT sifDatum AS narSifDatum, CASE WHEN prihod IS NULL THEN 0 ELSE prihod END AS narPrihod FROM cNarudzba) AS prihodiDatumi, dDatum
    WHERE narSifDatum=dDatum.sifDatum
      AND dDatum.pocMjeseca=TRUE) AS prihodPocetkomMjeseca,
    (SELECT AVG(narPrihod)
     FROM (SELECT sifDatum AS narSifDatum, CASE WHEN prihod IS NULL THEN 0 ELSE prihod END AS narPrihod FROM cNarudzba) AS prihodiDatumi, dDatum
     WHERE narSifDatum=dDatum.sifDatum
         AND dDatum.krajMjeseca=TRUE) AS prihodKrajemMjeseca
FROM cNarudzba;
