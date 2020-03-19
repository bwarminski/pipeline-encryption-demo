create table sales_files_loaded
(
    filedate date,
    filename varchar(256) NOT NULL,
    primary key (filename)
) diststyle all sortkey (filedate);
