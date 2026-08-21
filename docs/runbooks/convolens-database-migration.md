# Runbook: Convolens PostgreSQL Database Migration

**Task Reference:** Baton Subtask 4 (`cabf4190-aefc-499c-a690-5d9b504bcaa6`)  
**Parent Migration:** `ad65f8ed-bab4-46eb-bdb4-3bea4bb2837e`  
**Governing ADRs:** [ADR 0002: Shared Data Plane Ownership](../adr/0002-shared-data-plane-ownership.md), [ADR 0004: HOV as NexaMesh Product](../adr/0004-hov-nexamesh-product-boundary.md)

---

## 1. Scope and Boundaries

- **Database:** `convolens`
- **Source Environment:**
  - Subscription: `bb4e3882-2079-4bab-8974-611bc0b8bb58` (`mystira-sub`)
  - Server: `nl-prod-shared-pg.postgres.database.azure.com` (PostgreSQL 16, South Africa North)
  - Database Name: `convolens`
  - Tenant Role: `convolens`
- **Destination Environment:**
  - Subscription: `5a95ddee-dd63-441a-8306-c8b0803dcdd4` (`neuralliquid-sub`)
  - Server: `nl-prod-data-pg.postgres.database.azure.com` (PostgreSQL 16, South Africa North)
  - Database Name: `convolens`
  - Tenant Role: `convolens`

> [!IMPORTANT]
> **Strict HOV Exclusion Policy:**
> Per ADR 0004 and task `37547ca3`, the `houseofveritas` database and all HOV assets remain completely untouched on `mystira-sub`. HOV is classified as a NexaMesh physical-estate product and will be migrated to an isolated datastore in `nex-prod-hov-rg` under `nexamesh-sub` (`8a5dc70a-bafa-4a04-a281-9b4862a70810`). Do NOT dump, export, or modify HOV data during this procedure.

---

## 2. Pre-Migration Prerequisites

1. **Target Infrastructure Verification:**
   - Terraform stack `infra/terraform/shared-data` applied in `neuralliquid-sub`.
   - Target server `nl-prod-data-pg`, resource group `nl-prod-shared-rg`, and database `convolens` exist.
   - Key Vault `nl-prod-shared-kv` provisioned with admin credentials stored at `postgres-admin-password`.

2. **Network & Firewall Access:**
   - Discover public IP with strict timeout and HTTP failure handling:
     ```bash
     OPERATOR_IP=$(curl -fsSL --max-time 10 https://api.ipify.org 2>/dev/null || curl -fsSL --max-time 10 https://ifconfig.me/ip 2>/dev/null)
     if [ -z "$OPERATOR_IP" ]; then
       echo "ERROR: Failed to discover operator public IP. Ensure outbound HTTPS connectivity." >&2
       exit 1
     fi
     export OPERATOR_IP
     ```
   - Generate a session token, derive an absolute state-file path, and atomically initialize the session:
     ```bash
     export MIGRATION_SESSION_ID="${MIGRATION_SESSION_ID:-$(date +%Y%m%d%H%M%S)_$RANDOM}"
     export MIGRATION_STATE_DIR="${MIGRATION_STATE_DIR:-$HOME/.neuralliquid/migration_sessions}"
     mkdir -p "$MIGRATION_STATE_DIR"
     export MIGRATION_STATE_FILE="${MIGRATION_STATE_FILE:-$MIGRATION_STATE_DIR/convolens_${MIGRATION_SESSION_ID}.state}"

     if [ -e "$MIGRATION_STATE_FILE" ]; then
       echo "ERROR: Migration state file $MIGRATION_STATE_FILE already exists. Choose a distinct session ID." >&2
       exit 1
     fi

     export RULE_NAME="MigrationRunner_${MIGRATION_SESSION_ID}"
     cat <<EOF > "$MIGRATION_STATE_FILE"
RULE_NAME=$RULE_NAME
MIGRATION_SESSION_ID=$MIGRATION_SESSION_ID
OPERATOR_IP=$OPERATOR_IP
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
     ```
   - Add operator/runner IP temporarily to source and target servers and register automated error trap:
     ```bash
     # Source server (mystira-sub)
     az postgres flexible-server firewall-rule create \
       --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-shared-pg \
       --rule-name "$RULE_NAME" \
       --start-ip-address "$OPERATOR_IP" \
       --end-ip-address "$OPERATOR_IP"

     # Target server (neuralliquid-sub)
     az postgres flexible-server firewall-rule create \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --resource-group nl-prod-shared-rg \
       --server-name nl-prod-data-pg \
       --rule-name "$RULE_NAME" \
       --start-ip-address "$OPERATOR_IP" \
       --end-ip-address "$OPERATOR_IP"

     # Register automated emergency cleanup trap for unexpected errors or interruptions
     emergency_firewall_cleanup() {
       local exit_code=$?
       if [ $exit_code -ne 0 ]; then
         echo "=== ERROR TRAP: Migration aborted (Exit Code: $exit_code). Tearing down temporary firewall access... ===" >&2
         az postgres flexible-server firewall-rule delete \
           --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
           --resource-group nl-prod-shared-rg \
           --server-name nl-prod-data-pg \
           --name "$RULE_NAME" \
           --yes 2>/dev/null || true
         az postgres flexible-server firewall-rule delete \
           --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
           --resource-group nl-prod-shared-rg \
           --server-name nl-prod-shared-pg \
           --name "$RULE_NAME" \
           --yes 2>/dev/null || true
         [ -n "$MIGRATION_STATE_FILE" ] && [ -f "$MIGRATION_STATE_FILE" ] && rm -f "$MIGRATION_STATE_FILE"
       fi
     }
     trap emergency_firewall_cleanup ERR INT TERM
     ```

3. **Secrets Retrieval:**
   - Retrieve source admin password:
     ```bash
     SOURCE_PG_ADMIN_PW=$(az keyvault secret show \
       --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
       --vault-name nl-prod-shared-kv \
       --name postgres-admin-password \
       --query value -o tsv)
     ```
   - Retrieve target admin password:
     ```bash
     TARGET_PG_ADMIN_PW=$(az keyvault secret show \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --vault-name nl-prod-shared-kv \
       --name postgres-admin-password \
       --query value -o tsv)
     ```
   - Retrieve Convolens role password:
     ```bash
     CONVOLENS_ROLE_PW=$(az keyvault secret show \
       --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
       --vault-name nl-prod-convolens-kv \
       --name convolens-db-password \
       --query value -o tsv)
     ```

4. **Client Tooling:**
   - PostgreSQL client utilities (`pg_dump`, `pg_restore`, `psql`) version 16.x installed.

---

## 3. Migration Procedure

### Phase 1: Source Quiescence & Baseline Validation
1. Enable maintenance mode or scale down Convolens runtime (`nl-prod-convolens-web`) to prevent live writes during export:
   ```bash
   az webapp stop \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-convolens-rg \
     --name nl-prod-convolens-web
   ```
2. Capture baseline table record counts on source database:
   ```sql
   -- Run on source database convolens
   SELECT schemaname, relname, n_live_tup
   FROM pg_stat_user_tables
   ORDER BY schemaname, relname;
   ```

### Phase 2: Database Backup / Export (`pg_dump`)
1. Run `pg_dump` targeting ONLY the `convolens` database on source server `nl-prod-shared-pg`:
   ```bash
   PGPASSWORD="$SOURCE_PG_ADMIN_PW" pg_dump \
     -h nl-prod-shared-pg.postgres.database.azure.com \
     -U nlsharedadmin \
     -d convolens \
     --format=custom \
     --compress=9 \
     --verbose \
     --file=convolens_migration_$(date +%Y%m%d_%H%M%S).dump
   ```
2. Generate and verify SHA256 checksum:
   ```bash
   sha256sum convolens_migration_*.dump > convolens_migration.sha256
   cat convolens_migration.sha256
   ```
3. Retain backup archive in secure storage / blob container as a rollback baseline.

### Phase 3: Target Role and Database Setup
1. Connect as `nlsharedadmin` to target server `nl-prod-data-pg` in `neuralliquid-sub`:
   ```sql
   -- Connect: psql -h nl-prod-data-pg.postgres.database.azure.com -U nlsharedadmin -d postgres
   -- Create product tenant login role
   CREATE ROLE convolens WITH LOGIN PASSWORD '<CONVOLENS_ROLE_PW>';

   -- Assign ownership of database
   ALTER DATABASE convolens OWNER TO convolens;
   GRANT ALL PRIVILEGES ON DATABASE convolens TO convolens;

   -- Switch to convolens database
   \c convolens

   -- Assign schema ownership and secure tenant boundary
   GRANT ALL ON SCHEMA public TO convolens;
   ALTER SCHEMA public OWNER TO convolens;

   -- CRITICAL: Prevent cross-tenant database access
   REVOKE CONNECT ON DATABASE convolens FROM PUBLIC;
   GRANT CONNECT ON DATABASE convolens TO convolens;
   ```

### Phase 4: Database Restore (`pg_restore`)
1. Restore schema and data into target `convolens` database on destination server `nl-prod-data-pg`:
   ```bash
   PGPASSWORD="$TARGET_PG_ADMIN_PW" pg_restore \
     -h nl-prod-data-pg.postgres.database.azure.com \
     -U nlsharedadmin \
     -d convolens \
     --no-owner \
     --role=convolens \
     --clean \
     --if-exists \
     --verbose \
     convolens_migration_*.dump
   ```

### Phase 5: Data Integrity Verification
1. Compare table and row counts between source and target:
   ```sql
   SELECT schemaname, relname, n_live_tup
   FROM pg_stat_user_tables
   ORDER BY schemaname, relname;
   ```
2. Verify table count, view count, and sequence numbers:
   ```sql
   SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';
   SELECT count(*) FROM information_schema.sequences WHERE sequence_schema = 'public';
   ```
3. Test read/write functionality with the tenant role `convolens` via transactional DML:
   ```bash
   PGPASSWORD="$CONVOLENS_ROLE_PW" psql \
     -h nl-prod-data-pg.postgres.database.azure.com \
     -U convolens \
     -d convolens \
     -v ON_ERROR_STOP=1 \
     -c "
       SELECT current_user, current_database();
       BEGIN;
       CREATE TEMP TABLE _migration_test_rw (id serial PRIMARY KEY, note text);
       INSERT INTO _migration_test_rw (note) VALUES ('validation_probe');
       SELECT * FROM _migration_test_rw;
       ROLLBACK;
     "
   ```
4. Verify tenant isolation:
   - Ensure role `convolens` cannot access any other database or public schema.

### Phase 6: Application Secret & Service Cutover
1. Update Convolens database connection string in `nl-prod-convolens-kv`:
   ```bash
   az keyvault secret set \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --vault-name nl-prod-convolens-kv \
     --name "database-url" \
     --value "postgresql://convolens:<PASSWORD>@nl-prod-data-pg.postgres.database.azure.com:5432/convolens?sslmode=require"
   ```
2. Start Convolens runtime in `neuralliquid-sub` (Subtask 5).
3. Validate application health endpoint:
   ```bash
   curl -I https://convolens.neuralliquid.ai/health
   ```

### Phase 7: Cleanup

1. Remove the session's temporary firewall rule from source and target servers (reconstitutes exact rule name from session file without guessing):
   ```bash
   # Disable error trap since normal cleanup is executing
   trap - ERR INT TERM

   # Reconstitute session state if in a fresh shell session
   MIGRATION_STATE_DIR="${MIGRATION_STATE_DIR:-$HOME/.neuralliquid/migration_sessions}"

   if [ -z "$RULE_NAME" ]; then
     if [ -n "$MIGRATION_STATE_FILE" ]; then
       if [ -f "$MIGRATION_STATE_FILE" ]; then
         export RULE_NAME=$(grep '^RULE_NAME=' "$MIGRATION_STATE_FILE" | cut -d'=' -f2)
       else
         echo "ERROR: Explicitly specified MIGRATION_STATE_FILE='$MIGRATION_STATE_FILE' not found." >&2
         exit 1
       fi
     elif [ -n "$MIGRATION_SESSION_ID" ]; then
       EXPECTED_FILE="$MIGRATION_STATE_DIR/convolens_${MIGRATION_SESSION_ID}.state"
       if [ -f "$EXPECTED_FILE" ]; then
         export MIGRATION_STATE_FILE="$EXPECTED_FILE"
         export RULE_NAME=$(grep '^RULE_NAME=' "$MIGRATION_STATE_FILE" | cut -d'=' -f2)
       else
         echo "ERROR: State file for explicit MIGRATION_SESSION_ID='$MIGRATION_SESSION_ID' not found at '$EXPECTED_FILE'." >&2
         exit 1
       fi
     else
       # Automatic single-file resolution ONLY when no explicit selector was given
       shopt -s nullglob
       MATCHING_FILES=("$MIGRATION_STATE_DIR"/convolens_*.state)
       shopt -u nullglob

       if [ ${#MATCHING_FILES[@]} -eq 1 ]; then
         export MIGRATION_STATE_FILE="${MATCHING_FILES[0]}"
         export RULE_NAME=$(grep '^RULE_NAME=' "$MIGRATION_STATE_FILE" | cut -d'=' -f2)
       elif [ ${#MATCHING_FILES[@]} -gt 1 ]; then
         echo "ERROR: Multiple active migration sessions found in $MIGRATION_STATE_DIR:" >&2
         for f in "${MATCHING_FILES[@]}"; do
           echo "  - $f (Rule: $(grep '^RULE_NAME=' "$f" 2>/dev/null | cut -d'=' -f2))" >&2
         done
         echo "Please explicitly specify the target session before cleanup:" >&2
         echo "  export MIGRATION_STATE_FILE=<path> OR export MIGRATION_SESSION_ID=<id>" >&2
         exit 1
       fi
     fi
   fi

   if [ -z "$RULE_NAME" ]; then
     echo "ERROR: RULE_NAME is not set and no active migration state file was found in $MIGRATION_STATE_DIR." >&2
     echo "Specify: export RULE_NAME=<name> or export MIGRATION_STATE_FILE=<path>" >&2
     exit 1
   fi

   echo "Deleting target temporary firewall rule: $RULE_NAME"
   az postgres flexible-server firewall-rule delete \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-data-pg \
     --name "$RULE_NAME" \
     --yes

   echo "Deleting source temporary firewall rule: $RULE_NAME"
   az postgres flexible-server firewall-rule delete \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-shared-pg \
     --name "$RULE_NAME" \
     --yes
   ```

2. Confirm zero temporary rules remain for this session on both target and source servers (both queries must succeed and return empty):
   ```bash
   echo "=== Verifying target server cleanup (must be empty) ==="
   TARGET_REMAINDER=$(az postgres flexible-server firewall-rule list \
     --subscription 5a95ddee-dd63-441a-8306-c8b0803dcdd4 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-data-pg \
     --query "[?name=='$RULE_NAME'].name" -o tsv)
   TARGET_STATUS=$?

   echo "=== Verifying source server cleanup (must be empty) ==="
   SOURCE_REMAINDER=$(az postgres flexible-server firewall-rule list \
     --subscription bb4e3882-2079-4bab-8974-611bc0b8bb58 \
     --resource-group nl-prod-shared-rg \
     --server-name nl-prod-shared-pg \
     --query "[?name=='$RULE_NAME'].name" -o tsv)
   SOURCE_STATUS=$?

   if [ $TARGET_STATUS -ne 0 ] || [ -n "$TARGET_REMAINDER" ]; then
     echo "ERROR: Target firewall rule $RULE_NAME still present or query failed on target server!" >&2
     exit 1
   fi

   if [ $SOURCE_STATUS -ne 0 ] || [ -n "$SOURCE_REMAINDER" ]; then
     echo "ERROR: Source firewall rule $RULE_NAME still present or query failed on source server!" >&2
     exit 1
   fi

   echo "SUCCESS: Temporary firewall rule $RULE_NAME verified removed from both servers."

   # Safely remove session state file only after verified teardown
   if [ -n "$MIGRATION_STATE_FILE" ] && [ -f "$MIGRATION_STATE_FILE" ]; then
     rm -f "$MIGRATION_STATE_FILE"
   fi
   ```

---

## 4. Rollback Plan

If restore verification fails or application anomalies occur prior to final signoff:
1. Stop the target Convolens workload.
2. Revert `nl-prod-convolens-web` configuration to point back to the source database `nl-prod-shared-pg` on `mystira-sub`.
3. Restart source `nl-prod-convolens-web` on `mystira-sub`.
4. The source `convolens` and `houseofveritas` databases on `mystira-sub` remain completely intact with zero data loss.
5. **Immediate Firewall Cleanup:** Execute Phase 7 cleanup commands immediately to ensure no temporary operator access remains open on either server.
