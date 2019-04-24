#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  CREATE INDEX wos_summary_names_email_addr_email_search_idx ON wos_summary_names_email_addr(lower(email_addr), id, name_id);
  CREATE INDEX wos_summary_names_lastn_search_idx ON wos_summary_names(lower(last_name), lower(LEFT(first_name, 1)), id);
  CREATE INDEX wos_titles_title_type_idx ON wos_titles(title_type);
  CREATE INDEX wos_dynamic_identifiers_identifier_type_idx ON wos_dynamic_identifiers(identifier_type);
EOF
