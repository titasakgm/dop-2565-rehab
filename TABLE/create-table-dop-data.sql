DROP TABLE IF EXISTS dop_data;
CREATE TABLE public.dop_data (
    fyear  char(4) NOT NULL,
    off_id  character(3) NOT NULL,
    off_name  varchar NOT NULL,
    ccaa character(4) NOT NULL,
    amphoe character varying,
    changwat character varying,
    batch  integer,
    type character(1) NOT NULL,
    count integer,
    lat double precision,
    lon double precision,
    geom public.geometry,
    PRIMARY KEY (fyear,off_id,batch),
    CONSTRAINT enforce_dims_geom CHECK ((public.st_ndims(geom) = 2)),
    CONSTRAINT enforce_geotype_geom CHECK (((public.geometrytype(geom) = 'POINT'::text) OR (geom IS NULL))),
    CONSTRAINT enforce_srid_geom CHECK ((public.st_srid(geom) = 4326))
);
