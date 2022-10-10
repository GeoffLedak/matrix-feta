#!/bin/bash

printf "CREATE USER \"matrix\" WITH PASSWORD '$1';\nCREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0 OWNER \"matrix\";\n\q\n" | psql
