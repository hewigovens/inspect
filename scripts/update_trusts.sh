#!/bin/sh

SOURCE_URL="https://mozillacaprogram.secure.force.com/CA/IncludedCACertificateReportCSVFormat"
DB_NAME="mozilla_trust"
DB_PATH="$DB_NAME.db"
TMP_CSV_PATH="$DB_NAME.csv"
TABLE_NAME="ca_roots"
SHA1_COLUMN="SHA-1 Fingerprint"

function download_csv() {
	if [[ ! -s "$TMP_CSV_PATH" ]]; then
		curl "$SOURCE_URL" -o "$TMP_CSV_PATH"
	else
		echo "csv is existed. skip downloading..."
	fi
}

function import_to_db() {
	/usr/bin/sqlite3 -batch $DB_PATH <<EOF
.mode csv
.import "$TMP_CSV_PATH" "$TABLE_NAME"
update "$TABLE_NAME" set "$SHA1_COLUMN" = lower(replace("$SHA1_COLUMN", ":", ""));
create index "sha1" on "$TABLE_NAME" ("$SHA1_COLUMN");
.quit
EOF
}

function main() {
	download_csv
}

main
